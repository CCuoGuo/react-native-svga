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
 * SVGA 数据模型（解析结果 + 渲染输入）。
 *
 * 字段语义与 SVGAPlayer-Android 的 MovieEntity protobuf 对齐（字段号经
 * 对 yyued 官方样例 angel.svga / rose.svga / TwitterHeart.svga 的线格式
 * 解码实测确认）：
 * - MovieEntity{ 1: version, 2: MovieParams{1: viewWidth, 2: viewHeight,
 *   3: frameRate, 4: frameCount}, 3: map<string,bytes> images,
 *   4: repeated SpriteEntity }
 * - SpriteEntity{ 1: imageKey, 2: repeated FrameEntity }
 * - FrameEntity{ 1: alpha(f32), 2: Transform layout, 3: Transform transform }
 * - Transform{ 1: a, 2: b, 3: c, 4: d, 5: tx, 6: ty }（f32）
 * 其中 layout 的 c/d 存放位图宽高（与 PNG 原始尺寸一致）。
 */

import { image } from '@kit.ImageKit';

/** 仿射变换矩阵，与 Canvas setTransform(a, b, c, d, e, f) 同构。 */
export class SvgaTransform {
  a: number = 1;
  b: number = 0;
  c: number = 0;
  d: number = 1;
  tx: number = 0;
  ty: number = 0;
}

/** 单个 sprite 在某一帧的状态。 */
export class SvgaFrame {
  alpha: number = 0;
  layoutWidth: number = 0;
  layoutHeight: number = 0;
  transform: SvgaTransform = new SvgaTransform();
}

/** 一个 sprite：imageKey → images 表中的位图 + 逐帧状态序列。 */
export class SvgaSprite {
  imageKey: string = '';
  frames: SvgaFrame[] = [];
}

/** 解析中间产物：images 仍为原始字节（PixelMap 解码在 Loader 中异步完成）。 */
export class SvgaParsedMovie {
  version: string = '';
  viewWidth: number = 0;
  viewHeight: number = 0;
  frameRate: number = 20;
  frameCount: number = 0;
  sprites: SvgaSprite[] = [];
  images: Map<string, Uint8Array> = new Map<string, Uint8Array>();
}

/** 可播放的完整动画实体：images 已解码为 PixelMap。 */
export class SvgaMovie {
  version: string = '';
  viewWidth: number = 0;
  viewHeight: number = 0;
  frameRate: number = 20;
  frameCount: number = 0;
  sprites: SvgaSprite[] = [];
  images: Map<string, image.PixelMap> = new Map<string, image.PixelMap>();

  /** 释放全部位图资源。 */
  public release(): void {
    this.images.forEach((pm: image.PixelMap) => {
      pm.release();
    });
    this.images.clear();
  }
}
