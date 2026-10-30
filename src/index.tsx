'use strict';
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
 * react-native-svga 鸿蒙适配版 JS 层。
 *
 * 保持原库公开 API 完全一致（SVGAView / SVGAModule），差异仅在于：
 * 1. 原生组件由旧架构 requireNativeComponent('RNSVGA') 转为新架构
 *    codegenNativeComponent('RNSVGA')（见 specs/v1/SVGAViewNativeComponent.ts；
 *    注意：不能是 .tsx —— @react-native/babel-plugin-codegen 的 parseFile
 *    只认 endsWith('js')/endsWith('ts')，.tsx 会报 Unsupported filename
 *    extension，且 bob 编译后的 dist 会丢类型导致找不到组件配置）
 * 2. 工具模块在 Platform.OS === 'harmony' 分支显式取用 TurboModule
 *    'RNSVGAManager'（specs/v1/NativeSvga.ts），不沿用
 *    NativeModules.SvgaMoudle || NativeModules.RNSVGAManager 含糊 fallback 链
 *    （Android 端实际模块名 RCTSvgaMoudle，原库该链取空；此处链尾追加
 *    RCTSvgaMoudle，Android 上 isCached/advanceDownload 才真实可达）；
 * 3. 事件通道对齐 iOS 形态：onFinished/onFrame/onPercentage 三个独立事件
 *    （Android 为单一 topChange + action 分发，鸿蒙不采用）。
 */

import React, { Component } from 'react';
import {
  NativeModules,
  Platform,
} from 'react-native';
import resolveAssetSource from 'react-native/Libraries/Image/resolveAssetSource';

import NativeSvgaModule from './specs/v1/NativeSvga';
import SVGAViewNativeComponent from './specs/v1/SVGAViewNativeComponent';

const NativeSVGAView = SVGAViewNativeComponent as unknown as React.ComponentType<
  Record<string, unknown>
>;

// Android 端原生模块注册名是 RCTSvgaMoudle（见 RCTSVGAModule.kt getName()），
// 原库 fallback 链两名皆不匹配会取空；链尾追加真实注册名兜底。
const _Module =
  NativeModules.SvgaMoudle ||
  NativeModules.RNSVGAManager ||
  NativeModules.RCTSvgaMoudle;

/**
 * SVGAView 组件属性。
 */
export interface ISvgaProps {
  /** 动画播放完成后，回调 */
  onFinished?: () => void;
  /** 动画播放至某帧时，回调（value 为当前帧号，仅帧号变化时发出） */
  onFrame?: (value: number) => void;
  /** 动画播放至某进度时，回调（value 为 0.0 ~ 1.0 的进度值） */
  onPercentage?: (value: number) => void;
  /** SVGA 动画文件的路径，可以是 URL、本地打包资源 URI（见 {@link SVGAModule.getAssets}）或 file:// 沙箱路径 */
  source?: string;
  /** 循环次数，默认值为 0，0 = 无限循环 */
  loops?: number;
  /** 动画播放完成后，是否清空画布，默认值为 true */
  clearsAfterStop?: boolean;
  /**
   * 用于控制 SVGA 播放状态，可设定以下值：
   * - 'start' = 从头开始播放
   * - 'pause' = 从当前位置暂停播放
   * - 'stop'  = 停止播放
   * - 'clear' = 停止播放并清空画布
   * - 'play'  = 与 toFrame / toPercentage 配合，跳到目标帧（进度）后继续播放
   */
  currentState?: 'start' | 'pause' | 'stop' | 'clear' | 'play';
  /** 控制当前动画停靠在某帧，如果 currentState 值为 'play'，则跳到该帧后继续播放动画 */
  toFrame?: number;
  /** 控制当前动画停靠在某进度（0.0 ~ 1.0），如果 currentState 值为 'play'，则跳到该进度后继续播放动画 */
  toPercentage?: number;
  /** 组件样式 */
  style?: object;
  [key: string]: unknown;
}

export interface SVGAViewState {
  source?: string;
  currentState?: string;
  toFrame?: number;
  toPercentage?: number;
}

interface NativeEventPayload {
  nativeEvent: { action?: string; value?: number };
}

interface NativeEventListenerProps {
  onChange?: (event: NativeEventPayload) => void;
  onFrame?: (event: NativeEventPayload) => void;
  onPercentage?: (event: NativeEventPayload) => void;
  onFinished?: () => void;
}

export class SVGAModule {
  /**
   * 动态获取本地资源：将 `require('./x.svga')` 的资源编号经
   * resolveAssetSource 解析为原生可读 URI，用于 source 属性。
   *
   * @param nodeRequire 本地打包资源的 require 引用（资源编号）
   * @returns 解析后的资源 URI；解析失败返回空字符串
   * @example
   * ```tsx
   * const uri = SVGAModule.getAssets(require('./assets/angel.svga'));
   * <SVGAView source={uri} style={{width: 300, height: 300}} />
   * ```
   */
  static getAssets(nodeRequire: number | string): string {
    const resolved = resolveAssetSource(nodeRequire as number);
    return resolved ? resolved.uri : '';
  }

  /**
   * 判断网络动画是否已有本地缓存。
   * 鸿蒙端与 Android 语义一致：按 URL 派生缓存 key 查询本地文件缓存；
   * iOS 端恒返回 true（原库行为）。
   *
   * @param url SVGA 文件的网络地址
   * @returns 已缓存 resolve 为 true，否则 resolve 为 false（iOS 恒为 true）
   * @example
   * ```tsx
   * SVGAModule.isCached('https://example.com/gift.svga')
   *   .then(cached => console.log(cached));
   * ```
   */
  static isCached(url: string): Promise<boolean> {
    if ((Platform.OS as string) === 'harmony') {
      return NativeSvgaModule.isCached(url);
    }
    if (Platform.OS === 'android') {
      return _Module.isCached(url);
    }
    return Promise.resolve(true);
  }

  /**
   * 预加载：批量下载网络 svga 到缓存目录（非 http(s) 源跳过，失败静默）。
   * 预下载后断网仍可播放。
   *
   * @param urls SVGA 文件网络地址列表
   * @returns void
   * @example
   * ```tsx
   * SVGAModule.advanceDownload([
   *   'https://example.com/gift1.svga',
   *   'https://example.com/gift2.svga',
   * ]);
   * ```
   */
  static advanceDownload(urls: Array<string>): void {
    if ((Platform.OS as string) === 'harmony') {
      NativeSvgaModule.advanceDownload(urls);
      return;
    }
    if (_Module) {
      _Module.advanceDownload(urls);
    }
  }
}

export class SVGAView extends Component<ISvgaProps, SVGAViewState> {
  constructor(props: ISvgaProps) {
    super(props);
    this.state = {};
  }

  /**
   * 加载（切换）动画数据源。
   *
   * @param source SVGA 文件路径（URL / 本地资源 URI）
   * @returns void
   * @example
   * ```tsx
   * svgaRef.current?.load(newSource);
   * ```
   */
  load(source: string) {
    this.setState({
      source,
    });
  }

  /**
   * 开始动画：从头开始播放。
   *
   * @returns void
   * @example
   * ```tsx
   * svgaRef.current?.startAnimation();
   * ```
   */
  startAnimation() {
    this.setState({
      currentState: 'start',
    });
  }

  /**
   * 暂停动画：暂停在当前帧。
   *
   * @returns void
   * @example
   * ```tsx
   * svgaRef.current?.pauseAnimation();
   * ```
   */
  pauseAnimation() {
    this.setState({
      currentState: 'pause',
    });
  }

  /**
   * 停止动画（是否清空画布由 clearsAfterStop 决定）。
   *
   * @returns void
   * @example
   * ```tsx
   * svgaRef.current?.stopAnimation();
   * ```
   */
  stopAnimation() {
    this.setState({
      currentState: 'stop',
    });
  }

  /**
   * 清空动画：停止播放并清空画布。
   *
   * @returns void
   * @example
   * ```tsx
   * svgaRef.current?.clearAnimation();
   * ```
   */
  clearAnimation() {
    this.setState({
      currentState: 'clear',
    });
  }

  /**
   * 渲染特定的帧；如果 andPlay 设置为 true，则从该帧开始继续播放，
   * 否则停靠在该帧（暂停）。
   *
   * @param toFrame 目标帧号（从 0 开始）
   * @param andPlay true = 跳到该帧后继续播放；false = 停靠在该帧
   * @returns void
   * @example
   * ```tsx
   * // 跳到第 30 帧并继续播放
   * svgaRef.current?.stepToFrame(30, true);
   * ```
   */
  stepToFrame(toFrame: number, andPlay: boolean) {
    this.setState(
      {
        currentState: andPlay === true ? 'play' : 'pause',
        toFrame: -1,
      },
      () => {
        this.setState({
          toFrame,
        });
      },
    );
  }

  /**
   * 渲染特定百分比的帧；如果 andPlay 设置为 true，则从该进度开始继续
   * 播放，否则停靠在该进度（暂停）。
   *
   * @param toPercentage 目标进度，取值 0.0 ~ 1.0
   * @param andPlay true = 跳到该进度后继续播放；false = 停靠在该进度
   * @returns void
   * @example
   * ```tsx
   * // 跳到 50% 进度并停靠
   * svgaRef.current?.stepToPercentage(0.5, false);
   * ```
   */
  stepToPercentage(toPercentage: number, andPlay: boolean) {
    this.setState(
      {
        currentState: andPlay === true ? 'play' : 'pause',
        toPercentage: -1,
      },
      () => {
        this.setState({
          toPercentage,
        });
      },
    );
  }

  componentWillUnmount() {
    this.stopAnimation();
  }

  render() {
    if (!this.props.source) {
      return null;
    }

    const eventListeners: Partial<NativeEventListenerProps> = {};
    if (Platform.OS === 'android') {
      eventListeners.onChange = (event) => {
        const { action } = event.nativeEvent;
        if (action === 'onFinished') {
          if (typeof this.props.onFinished === 'function') {
            this.props.onFinished();
          }
        } else if (action === 'onFrame') {
          if (typeof this.props.onFrame === 'function') {
            this.props.onFrame(event.nativeEvent.value as number);
          }
        } else if (action === 'onPercentage') {
          if (typeof this.props.onPercentage === 'function') {
            this.props.onPercentage(event.nativeEvent.value as number);
          }
        }
      };
    } else {
      // 鸿蒙与 iOS 一致：三个独立事件
      if (typeof this.props.onFrame === 'function') {
        eventListeners.onFrame = (event) => {
          this.props.onFrame!(event.nativeEvent.value as number);
        };
      }
      if (typeof this.props.onPercentage === 'function') {
        eventListeners.onPercentage = (event) => {
          this.props.onPercentage!(event.nativeEvent.value as number);
        };
      }
      if (typeof this.props.onFinished === 'function') {
        eventListeners.onFinished = () => {
          this.props.onFinished!();
        };
      }
    }

    const nativeProps: Record<string, unknown> = {};
    Object.assign(nativeProps, this.props, this.state, eventListeners);

    return <NativeSVGAView {...nativeProps} />;
  }
}

export default {
  SVGAView,
  SVGAModule,
};
