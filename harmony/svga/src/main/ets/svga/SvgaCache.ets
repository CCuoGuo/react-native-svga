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
 * SVGA 网络缓存（对应 Android SVGACache.Type.FILE 语义）。
 *
 * - 缓存 key：URL 的 SHA-256 摘要（advanceDownload 与播放走同一份缓存，
 *   预下载后播放秒开、断网可播）；
 * - 缓存目录：应用沙箱 cacheDir/svga_cache；
 * - 下载：@ohos.net.http（需宿主声明 ohos.permission.INTERNET），
 *   失败静默（与上游 advanceDownload 行为一致，不抛错）。
 */

import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { http } from '@kit.NetworkKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';

export class SvgaCache {
  private static readonly DIR_NAME: string = 'svga_cache';
  private static cacheDir: string = '';

  /** 初始化（幂等）并返回缓存目录。 */
  public static init(context: common.UIAbilityContext): string {
    if (SvgaCache.cacheDir === '') {
      SvgaCache.cacheDir = `${context.cacheDir}/${SvgaCache.DIR_NAME}`;
      if (!fs.accessSync(SvgaCache.cacheDir)) {
        fs.mkdirSync(SvgaCache.cacheDir, true);
      }
    }
    return SvgaCache.cacheDir;
  }

  /** 由 URL 派生缓存文件名（SHA-256 摘要 + .svga 后缀）。 */
  public static async cacheKeyOf(url: string): Promise<string> {
    const encoder: util.TextEncoder = new util.TextEncoder();
    const bytes: Uint8Array = encoder.encodeInto(url);
    const md: cryptoFramework.Md = cryptoFramework.createMd('SHA256');
    await md.update({ data: bytes } as cryptoFramework.DataBlob);
    const digest: cryptoFramework.DataBlob = await md.digest();
    let hex: string = '';
    for (let i: number = 0; i < digest.data.length; i += 1) {
      const h: string = (digest.data[i] & 0xff).toString(16);
      hex += h.length === 1 ? `0${h}` : h;
    }
    return `${hex}.svga`;
  }

  /** 查询 URL 是否已缓存（isCached 语义：本地文件是否存在）。 */
  public static async isCached(url: string, context: common.UIAbilityContext): Promise<boolean> {
    SvgaCache.init(context);
    const key: string = await SvgaCache.cacheKeyOf(url);
    return fs.accessSync(`${SvgaCache.cacheDir}/${key}`);
  }

  /**
   * 批量预下载（advanceDownload 语义）：仅处理 http/https 源，
   * 非网络源跳过，单个失败静默并记录日志。
   */
  public static async advanceDownload(urls: string[], context: common.UIAbilityContext): Promise<void> {
    SvgaCache.init(context);
    const tasks: Promise<void>[] = [];
    for (const url of urls) {
      if (url.startsWith('http://') || url.startsWith('https://')) {
        tasks.push(
          SvgaCache.fetch(url, context).then((bytes: Uint8Array | null): void => {
            if (bytes !== null) {
              console.info(`[RNSVGA] advanceDownload 缓存成功: ${url}`);
            } else {
              console.info(`[RNSVGA] advanceDownload 缓存失败,请检查地址是否正确: ${url}`);
            }
          }).catch((): void => {
            console.info(`[RNSVGA] advanceDownload 缓存失败,请检查地址是否正确: ${url}`);
          })
        );
      } else {
        console.info(`[RNSVGA] advanceDownload 跳过非网络地址: ${url}`);
      }
    }
    await Promise.all(tasks);
  }

  /**
   * 取网络 svga 字节：命中缓存直接读文件，否则经 @ohos.net.http 下载并落盘。
   * 失败返回 null（调用方决定是否抛错）。
   */
  public static async fetch(url: string, context: common.UIAbilityContext): Promise<Uint8Array | null> {
    SvgaCache.init(context);
    const key: string = await SvgaCache.cacheKeyOf(url);
    const path: string = `${SvgaCache.cacheDir}/${key}`;
    if (fs.accessSync(path)) {
      return SvgaCache.readFile(path);
    }
    const httpRequest: http.HttpRequest = http.createHttp();
    try {
      const resp: http.HttpResponse = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 15000,
        readTimeout: 30000,
      } as http.HttpRequestOptions);
      const code: number = resp.responseCode;
      if (code >= 200 && code < 300 && resp.result instanceof ArrayBuffer) {
        const body: ArrayBuffer = resp.result as ArrayBuffer;
        SvgaCache.writeFile(path, body);
        return new Uint8Array(body);
      }
      console.error(`[RNSVGA] 下载失败 HTTP ${code}: ${url}`);
      return null;
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      console.error(`[RNSVGA] 下载异常 ${err.code} ${err.message}: ${url}`);
      return null;
    } finally {
      httpRequest.destroy();
    }
  }

  /** 读整个文件为字节。文件不存在抛异常。 */
  public static readFile(path: string): Uint8Array {
    const stat: fs.Stat = fs.statSync(path);
    const buf: ArrayBuffer = new ArrayBuffer(stat.size);
    const file: fs.File = fs.openSync(path, fs.OpenMode.READ_ONLY);
    try {
      fs.readSync(file.fd, buf);
    } finally {
      fs.closeSync(file);
    }
    return new Uint8Array(buf);
  }

  /** 将字节写入文件（覆盖）。 */
  public static writeFile(path: string, data: ArrayBuffer): void {
    const file: fs.File = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    try {
      fs.writeSync(file.fd, data);
    } finally {
      fs.closeSync(file);
    }
  }
}
