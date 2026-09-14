/**
 * MIT License
 * 
 * Copyright (C) 2026 Huawei Device Co., Ltd.
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */
/**
 * protobuf wire format 读取器 + SVGA v1（zlib + protobuf）解析器。
 *
 * SVGA v1 文件本体是 zlib 流（0x78 0x9c 头），解压后为 MovieEntity
 * protobuf 消息。此处实现最小 wire 读取（varint / fixed32 / bytes），
 * 不依赖 protobuf 运行时。
 */

import { SvgaFrame, SvgaParsedMovie, SvgaSprite, SvgaTransform } from './SvgaTypes';

/** protobuf wire format 读取器（基于 Uint8Array 的只读游标）。 */
export class SvgaPBReader {
  private buf: Uint8Array;
  private view: DataView;
  private pos: number = 0;

  constructor(buf: Uint8Array) {
    this.buf = buf;
    this.view = new DataView(buf.buffer, buf.byteOffset, buf.byteLength);
  }

  public isEnd(): boolean {
    return this.pos >= this.buf.length;
  }

  /** 读取 varint（protobuf int32/uint32/int64，超出 2^53 部分按精度截断，SVGA 字段均为小值）。 */
  public readVarint(): number {
    let result: number = 0;
    let shift: number = 0;
    while (this.pos < this.buf.length) {
      const b: number = this.buf[this.pos];
      this.pos += 1;
      result += (b & 0x7f) * Math.pow(2, shift);
      if ((b & 0x80) === 0) {
        break;
      }
      shift += 7;
      if (shift > 63) {
        break;
      }
    }
    return result;
  }

  /** 读取 little-endian float（protobuf fixed32 float）。 */
  public readFloat(): number {
    const v: number = this.view.getFloat32(this.pos, true);
    this.pos += 4;
    return v;
  }

  /** 读取 length-delimited 字段内容。 */
  public readBytes(): Uint8Array {
    const len: number = this.readVarint();
    const out: Uint8Array = this.buf.subarray(this.pos, this.pos + len);
    this.pos += len;
    return out;
  }

  /** 按 wireType 跳过未知字段。 */
  public skip(wireType: number): void {
    if (wireType === 0) {
      this.readVarint();
    } else if (wireType === 1) {
      this.pos += 8;
    } else if (wireType === 2) {
      const len: number = this.readVarint();
      this.pos += len;
    } else if (wireType === 5) {
      this.pos += 4;
    }
  }

  /** UTF-8 解码（手工实现，避免运行时 API 差异）。 */
  public static utf8Decode(bytes: Uint8Array): string {
    let out: string = '';
    let i: number = 0;
    while (i < bytes.length) {
      const b: number = bytes[i];
      if (b < 0x80) {
        out += String.fromCharCode(b);
        i += 1;
      } else if (b < 0xe0) {
        out += String.fromCharCode(((b & 0x1f) << 6) | (bytes[i + 1] & 0x3f));
        i += 2;
      } else if (b < 0xf0) {
        out += String.fromCharCode(((b & 0x0f) << 12) | ((bytes[i + 1] & 0x3f) << 6) | (bytes[i + 2] & 0x3f));
        i += 3;
      } else {
        const cp: number =
          ((b & 0x07) << 18) |
          ((bytes[i + 1] & 0x3f) << 12) |
          ((bytes[i + 2] & 0x3f) << 6) |
          (bytes[i + 3] & 0x3f);
        out += String.fromCharCode(0xd800 + ((cp - 0x10000) >> 10), 0xdc00 + ((cp - 0x10000) & 0x3ff));
        i += 4;
      }
    }
    return out;
  }
}

/** SVGA v1 MovieEntity 解析。 */
export class SvgaProtobufParser {
  /** 解析解压后的 MovieEntity 字节。解析失败抛出 Error。 */
  public static parse(bytes: Uint8Array): SvgaParsedMovie {
    const movie: SvgaParsedMovie = new SvgaParsedMovie();
    const reader: SvgaPBReader = new SvgaPBReader(bytes);
    while (!reader.isEnd()) {
      const tag: number = reader.readVarint();
      const field: number = tag >>> 3;
      const wireType: number = tag & 7;
      if (field === 1 && wireType === 2) {
        movie.version = SvgaPBReader.utf8Decode(reader.readBytes());
      } else if (field === 2 && wireType === 2) {
        SvgaProtobufParser.parseParams(reader.readBytes(), movie);
      } else if (field === 3 && wireType === 2) {
        SvgaProtobufParser.parseImageEntry(reader.readBytes(), movie);
      } else if (field === 4 && wireType === 2) {
        movie.sprites.push(SvgaProtobufParser.parseSprite(reader.readBytes()));
      } else {
        reader.skip(wireType);
      }
    }
    if (movie.frameCount <= 0) {
      throw new Error('svga movie has no frames');
    }
    return movie;
  }

  /** MovieParams：viewWidth/viewHeight（float）、frameRate/frameCount（varint）。 */
  private static parseParams(bytes: Uint8Array, movie: SvgaParsedMovie): void {
    const reader: SvgaPBReader = new SvgaPBReader(bytes);
    while (!reader.isEnd()) {
      const tag: number = reader.readVarint();
      const field: number = tag >>> 3;
      const wireType: number = tag & 7;
      if (field === 1 && wireType === 5) {
        movie.viewWidth = reader.readFloat();
      } else if (field === 2 && wireType === 5) {
        movie.viewHeight = reader.readFloat();
      } else if (field === 3 && wireType === 0) {
        movie.frameRate = reader.readVarint();
      } else if (field === 4 && wireType === 0) {
        movie.frameCount = reader.readVarint();
      } else {
        reader.skip(wireType);
      }
    }
    if (movie.frameRate <= 0) {
      movie.frameRate = 20;
    }
  }

  /** images map 条目：{1: key, 2: png bytes}。 */
  private static parseImageEntry(bytes: Uint8Array, movie: SvgaParsedMovie): void {
    let key: string = '';
    let value: Uint8Array | null = null;
    const reader: SvgaPBReader = new SvgaPBReader(bytes);
    while (!reader.isEnd()) {
      const tag: number = reader.readVarint();
      const field: number = tag >>> 3;
      const wireType: number = tag & 7;
      if (field === 1 && wireType === 2) {
        key = SvgaPBReader.utf8Decode(reader.readBytes());
      } else if (field === 2 && wireType === 2) {
        value = reader.readBytes();
      } else {
        reader.skip(wireType);
      }
    }
    if (key !== '' && value !== null) {
      movie.images.set(key, value as Uint8Array);
    }
  }

  /** SpriteEntity：{1: imageKey, 2: repeated FrameEntity}。 */
  private static parseSprite(bytes: Uint8Array): SvgaSprite {
    const sprite: SvgaSprite = new SvgaSprite();
    const reader: SvgaPBReader = new SvgaPBReader(bytes);
    while (!reader.isEnd()) {
      const tag: number = reader.readVarint();
      const field: number = tag >>> 3;
      const wireType: number = tag & 7;
      if (field === 1 && wireType === 2) {
        sprite.imageKey = SvgaPBReader.utf8Decode(reader.readBytes());
      } else if (field === 2 && wireType === 2) {
        sprite.frames.push(SvgaProtobufParser.parseFrame(reader.readBytes()));
      } else {
        reader.skip(wireType);
      }
    }
    return sprite;
  }

  /** FrameEntity：{1: alpha(f32), 2: layout Transform, 3: transform Transform}；4/5 为遮罩与矢量形状，位图管线跳过。 */
  private static parseFrame(bytes: Uint8Array): SvgaFrame {
    const frame: SvgaFrame = new SvgaFrame();
    const reader: SvgaPBReader = new SvgaPBReader(bytes);
    while (!reader.isEnd()) {
      const tag: number = reader.readVarint();
      const field: number = tag >>> 3;
      const wireType: number = tag & 7;
      if (field === 1 && wireType === 5) {
        frame.alpha = reader.readFloat();
      } else if (field === 2 && wireType === 2) {
        const layout: SvgaTransform = SvgaProtobufParser.parseTransform(reader.readBytes());
        frame.layoutWidth = layout.c;
        frame.layoutHeight = layout.d;
      } else if (field === 3 && wireType === 2) {
        frame.transform = SvgaProtobufParser.parseTransform(reader.readBytes());
      } else {
        reader.skip(wireType);
      }
    }
    return frame;
  }

  /** Transform：{1: a, 2: b, 3: c, 4: d, 5: tx, 6: ty}，全部 float。 */
  private static parseTransform(bytes: Uint8Array): SvgaTransform {
    const t: SvgaTransform = new SvgaTransform();
    const reader: SvgaPBReader = new SvgaPBReader(bytes);
    while (!reader.isEnd()) {
      const tag: number = reader.readVarint();
      const field: number = tag >>> 3;
      const wireType: number = tag & 7;
      if (wireType !== 5) {
        reader.skip(wireType);
        continue;
      }
      if (field === 1) {
        t.a = reader.readFloat();
      } else if (field === 2) {
        t.b = reader.readFloat();
      } else if (field === 3) {
        t.c = reader.readFloat();
      } else if (field === 4) {
        t.d = reader.readFloat();
      } else if (field === 5) {
        t.tx = reader.readFloat();
      } else if (field === 6) {
        t.ty = reader.readFloat();
      } else {
        reader.skip(wireType);
      }
    }
    return t;
  }
}
