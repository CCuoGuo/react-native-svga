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
 * SVGA 数据源加载与解析管线：
 *
 * source 解析（对齐 Android/iOS 三形态 + 鸿蒙 rawfile 形态）：
 *   http(s):// → SvgaCache（缓存/下载）
 *   resource://RAWFILE/xx → resourceManager rawfile
 *   file:// → 剥前缀 + decodeURIComponent 后读沙箱文件
 *   /data/... 绝对路径 → 读沙箱文件
 *   其它（资源名/相对路径）→ 依次尝试 rawfile → 沙箱 → rawfile(文件名)
 *
 * 容器格式两种：
 *   v1：zlib 流 + MovieEntity protobuf（yyued 官方样例全部为该格式）
 *   v2：ZIP 容器（movie.spec JSON + 位图文件），经 zlib.decompressFile 解压
 *
 * 位图：image.createImageSource(buffer) → createPixelMap 批量解码。
 */

import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { zlib } from '@kit.BasicServicesKit';
import { image } from '@kit.ImageKit';
import { SvgaMovie, SvgaParsedMovie, SvgaFrame, SvgaSprite } from './SvgaTypes';
import { SvgaProtobufParser } from './SvgaProtobuf';
import { SvgaCache } from './SvgaCache';

/** v2 movie.spec JSON 结构（可选字段均做判空兜底）。 */
interface SvgaV2Layout {
  x?: number;
  y?: number;
  width?: number;
  height?: number;
}

interface SvgaV2Frame {
  alpha?: number;
  layout?: SvgaV2Layout;
  transform?: number[];
}

interface SvgaV2Sprite {
  imageKey?: string;
  frames?: SvgaV2Frame[];
}

interface SvgaV2Spec {
  version?: string;
  viewBoxWidth?: number;
  viewBoxHeight?: number;
  fps?: number;
  frames?: number;
  images?: Record<string, string>;
  sprites?: SvgaV2Sprite[];
}

export class SvgaLoader {
  private static tmpSeq: number = 0;

  /** 完整加载：取字节 → 解析容器 → 解码位图。 */
  public static async load(source: string, context: common.UIAbilityContext): Promise<SvgaMovie> {
    const bytes: Uint8Array = await SvgaLoader.loadBytes(source, context);
    const parsed: SvgaParsedMovie = await SvgaLoader.parseBytes(bytes, context);
    return await SvgaLoader.decodeImages(parsed);
  }

  /** source 三形态（+ rawfile）解析为字节。 */
  public static async loadBytes(source: string, context: common.UIAbilityContext): Promise<Uint8Array> {
    if (source.startsWith('http://') || source.startsWith('https://')) {
      const bytes: Uint8Array | null = await SvgaCache.fetch(source, context);
      if (bytes === null) {
        throw new Error(`svga download failed: ${source}`);
      }
      return bytes as Uint8Array;
    }
    if (source.startsWith('resource://RAWFILE/')) {
      return await SvgaLoader.readRawfile(source.substring('resource://RAWFILE/'.length), context);
    }
    if (source.startsWith('asset://')) {
      // RNOH bundle 模式 resolveAssetSource 产物：asset://<rawfile 相对路径>。
      // 仅剥 scheme 后落入下方相对路径兜底链：超过 2 层的 rawfile 子路径在
      // 部分设备 getRawFileContent 读不到（实测与目录名无关），兜底链最终
      // 还能按文件名读 rawfile 根目录（前提：资源在根目录有同名副本）。
      source = source.substring('asset://'.length);
    }
    if (source.startsWith('file://')) {
      // 鸿蒙文件 API 不识别 file:// scheme，须归一化为裸沙箱路径
      const path: string = decodeURIComponent(source.substring('file://'.length));
      return SvgaCache.readFile(path);
    }
    if (source.startsWith('/')) {
      return SvgaCache.readFile(source);
    }
    // 资源名/相对路径：rawfile（原样）→ 沙箱 → rawfile(文件名)
    try {
      return await SvgaLoader.readRawfile(source, context);
    } catch (e) {
      // continue
    }
    try {
      return SvgaCache.readFile(source);
    } catch (e) {
      // continue
    }
    return await SvgaLoader.readRawfile(source.substring(source.lastIndexOf('/') + 1), context);
  }

  /** 按容器头选择解析路径：PK 开头为 v2 zip，否则 v1 zlib+protobuf。 */
  public static async parseBytes(bytes: Uint8Array, context: common.UIAbilityContext): Promise<SvgaParsedMovie> {
    if (bytes.length > 3 && bytes[0] === 0x50 && bytes[1] === 0x4b && (bytes[2] === 0x03 || bytes[2] === 0x05 || bytes[2] === 0x07)) {
      return await SvgaLoader.parseV2(bytes, context);
    }
    const inflated: Uint8Array = await SvgaLoader.inflate(bytes);
    return SvgaProtobufParser.parse(inflated);
  }

  /** zlib 流解压（v1 文件本体）。目标缓冲区不足（17800007）时按 4 倍扩容重试。 */
  public static async inflate(source: Uint8Array): Promise<Uint8Array> {
    const zip: zlib.Zip = zlib.createZipSync();
    const srcBuf: ArrayBuffer = source.buffer.slice(source.byteOffset, source.byteOffset + source.byteLength);
    let cap: number = Math.max(source.byteLength * 8, 1024 * 1024);
    while (cap <= 384 * 1024 * 1024) {
      const dest: ArrayBuffer = new ArrayBuffer(cap);
      try {
        const info: zlib.DecompressionOutputInfo = await zip.uncompress2(dest, srcBuf);
        if (info.destLength > 0) {
          return new Uint8Array(dest, 0, info.destLength);
        }
      } catch (e) {
        const err: BusinessError = e as BusinessError;
        if (err.code === 17800007) {
          cap *= 4;
          continue;
        }
        throw new Error(`svga inflate failed: ${err.code} ${err.message}`);
      }
      cap *= 4;
    }
    throw new Error('svga inflate failed: output too large');
  }

  /** v2：写入临时 zip → decompressFile 解压 → 读 movie.spec JSON + 位图文件。 */
  private static async parseV2(bytes: Uint8Array, context: common.UIAbilityContext): Promise<SvgaParsedMovie> {
    SvgaLoader.tmpSeq += 1;
    const tmpDir: string = `${SvgaCache.init(context)}/tmp_${Date.now()}_${SvgaLoader.tmpSeq}`;
    fs.mkdirSync(tmpDir, true);
    const zipPath: string = `${tmpDir}/input.zip`;
    SvgaCache.writeFile(zipPath, sourceBuffer(bytes));
    const movie: SvgaParsedMovie = new SvgaParsedMovie();
    try {
      await zlib.decompressFile(zipPath, tmpDir);
      const specPath: string = `${tmpDir}/movie.spec`;
      if (!fs.accessSync(specPath)) {
        throw new Error('svga v2 has no movie.spec');
      }
      const text: string = fs.readTextSync(specPath);
      // 外部输入 JSON 解析必须防护
      let spec: SvgaV2Spec;
      try {
        spec = JSON.parse(text) as SvgaV2Spec;
      } catch (e) {
        throw new Error('svga movie.spec JSON parse failed');
      }
      movie.version = spec.version ?? '';
      movie.viewWidth = spec.viewBoxWidth ?? 0;
      movie.viewHeight = spec.viewBoxHeight ?? 0;
      movie.frameRate = spec.fps && spec.fps > 0 ? spec.fps : 20;
      movie.frameCount = spec.frames ?? 0;
      const images: Record<string, string> = spec.images ?? {};
      const keys: string[] = Object.keys(images);
      for (const key of keys) {
        const fileName: string = images[key];
        const data: Uint8Array | null = SvgaLoader.readZipImage(tmpDir, fileName);
        if (data !== null) {
          movie.images.set(key, data);
        }
      }
      const sprites: SvgaV2Sprite[] = spec.sprites ?? [];
      for (const sp of sprites) {
        const sprite: SvgaSprite = new SvgaSprite();
        sprite.imageKey = sp.imageKey ?? '';
        const frames: SvgaV2Frame[] = sp.frames ?? [];
        for (const fr of frames) {
          const frame: SvgaFrame = new SvgaFrame();
          frame.alpha = fr.alpha ?? 1;
          if (fr.layout) {
            frame.layoutWidth = fr.layout.width ?? 0;
            frame.layoutHeight = fr.layout.height ?? 0;
          }
          const t: number[] = fr.transform ?? [];
          if (t.length >= 6) {
            frame.transform.a = t[0];
            frame.transform.b = t[1];
            frame.transform.c = t[2];
            frame.transform.d = t[3];
            frame.transform.tx = t[4];
            frame.transform.ty = t[5];
          }
          sprite.frames.push(frame);
        }
        movie.sprites.push(sprite);
      }
      if (movie.frameCount <= 0) {
        throw new Error('svga movie has no frames');
      }
    } finally {
      try {
        // rmdirSync 在鸿蒙上递归删除目录及全部子文件（无 options 参数），非空临时目录可整目录清理
        fs.rmdirSync(tmpDir);
      } catch (e) {
        // 临时目录清理失败不影响解析结果
      }
    }
    return movie;
  }

  /** 在解压目录内按候选名定位并读取位图（兼容带/不带扩展名的 images 映射值）。 */
  private static readZipImage(dir: string, fileName: string): Uint8Array | null {
    const candidates: string[] = [fileName, `${fileName}.png`, `${fileName}.jpg`, `${fileName}.webp`];
    for (const name of candidates) {
      const path: string = `${dir}/${name}`;
      try {
        if (fs.accessSync(path)) {
          return SvgaCache.readFile(path);
        }
      } catch (e) {
        // continue
      }
    }
    return null;
  }

  /** 解析结果 → 可播放实体：批量解码位图为 PixelMap。 */
  public static async decodeImages(parsed: SvgaParsedMovie): Promise<SvgaMovie> {
    const movie: SvgaMovie = new SvgaMovie();
    movie.version = parsed.version;
    movie.viewWidth = parsed.viewWidth;
    movie.viewHeight = parsed.viewHeight;
    movie.frameRate = parsed.frameRate;
    movie.frameCount = parsed.frameCount;
    movie.sprites = parsed.sprites;
    const keys: string[] = Array.from(parsed.images.keys());
    const tasks: Promise<void>[] = [];
    for (const key of keys) {
      const bytes: Uint8Array = parsed.images.get(key) as Uint8Array;
      tasks.push(
        SvgaLoader.decodePixelMap(bytes).then((pm: image.PixelMap | null): void => {
          if (pm !== null) {
            movie.images.set(key, pm);
          }
        })
      );
    }
    await Promise.all(tasks);
    return movie;
  }

  /** 单张位图解码：createImageSource → createPixelMap → release ImageSource。失败返回 null。 */
  private static async decodePixelMap(bytes: Uint8Array): Promise<image.PixelMap | null> {
    const buf: ArrayBuffer = sourceBuffer(bytes);
    const source: image.ImageSource = image.createImageSource(buf);
    try {
      return await source.createPixelMap();
    } catch (e) {
      console.error('[RNSVGA] bitmap decode failed');
      return null;
    } finally {
      source.release();
    }
  }

  private static async readRawfile(path: string, context: common.UIAbilityContext): Promise<Uint8Array> {
    const normalized: string = SvgaLoader.normalizeRawfilePath(path);
    return await context.resourceManager.getRawFileContent(normalized);
  }

  /** 归一化 rawfile 相对路径：去 scheme 残留 / 前导 './' 与 '/'。 */
  private static normalizeRawfilePath(path: string): string {
    let p: string = path;
    while (p.startsWith('./')) {
      p = p.substring(2);
    }
    while (p.startsWith('/')) {
      p = p.substring(1);
    }
    return p;
  }
}

/** Uint8Array 视图 → 独立 ArrayBuffer 拷贝（供 image/zlib API 使用）。 */
function sourceBuffer(bytes: Uint8Array): ArrayBuffer {
  return bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength);
}
