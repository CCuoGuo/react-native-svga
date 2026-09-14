/**
 * Copyright (c) 2025.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE-MIT file in the root directory of this source tree.
 */

import { TurboModuleRegistry } from 'react-native';
import type { TurboModule } from 'react-native/Libraries/TurboModule/RCTExport';

/**
 * SVGAModule 工具能力的 TurboModule Spec。
 *
 * 鸿蒙侧 TurboModule 名与 Android/iOS 取用链保持兼容：
 * - iOS ViewManager 模块名为 RNSVGAManager（advanceDownload 挂在其上）；
 * - Android 实际名 RCTSvgaMoudle（与 JS 取用链不一致，Android 上本就有取空隐患）。
 * 鸿蒙端统一注册为 RNSVGAManager，JS 适配层（src/index.ts）在
 * Platform.OS === 'harmony' 分支显式取用本 Spec，不沿用含糊 fallback 链。
 */
export interface Spec extends TurboModule {
  /**
   * 是否已缓存到本地（Android 语义：按 URL 派生缓存 key 查询文件缓存）。
   */
  isCached(url: string): Promise<boolean>;
  /**
   * 批量预下载网络 svga 到缓存目录（仅处理 http/https 源，失败静默）。
   */
  advanceDownload(urls: Array<string>): void;
}

export default TurboModuleRegistry.get<Spec>('RNSVGAManager')!;
