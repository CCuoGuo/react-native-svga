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
 * RNSVGAManager TurboModule（ArkTS 实现）。
 *
 * - isCached(url)：真实查询文件缓存（Android 语义），iOS 端恒 true 的行为
 *   由 JS 层分支保持，鸿蒙不沿用；
 * - advanceDownload(urls)：批量预下载到缓存目录（播放与预下载共用缓存，
 *   与 SVGACache.Type.FILE 语义一致）。
 */

import { EtsUITurboModule } from '@rnoh/react-native-openharmony/ets';
import { BusinessError } from '@kit.BasicServicesKit';
import { RNSVGAManager } from './generated/turboModules/RNSVGAManager';
import { SvgaCache } from './svga/SvgaCache';

export class RNSVGATurboModule extends EtsUITurboModule implements RNSVGAManager.Spec {
  public static readonly NAME = RNSVGAManager.NAME;

  isCached(url: string): Promise<boolean> {
    // 每次调用即时读取上下文（不在构造时缓存，避免上下文未就绪拿到旧值）
    return SvgaCache.isCached(url, this.ctx.uiAbilityContext);
  }

  advanceDownload(urls: string[]): void {
    SvgaCache.advanceDownload(urls, this.ctx.uiAbilityContext).catch((e: Object) => {
      const err: BusinessError = e as BusinessError;
      console.error(`[RNSVGA] advanceDownload failed: ${err.message}`);
    });
  }
}
