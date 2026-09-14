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
 *    （Android 端实际模块名 RCTSvgaMoudle 与取用链不一致，本就存在取空隐患）；
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

const _Module = NativeModules.SvgaMoudle || NativeModules.RNSVGAManager;

export interface ISvgaProps {
  onFinished?: () => void;
  onFrame?: (value: number) => void;
  onPercentage?: (value: number) => void;
  source?: string;
  loops?: number;
  clearsAfterStop?: boolean;
  currentState?: 'start' | 'pause' | 'stop' | 'clear' | 'play';
  toFrame?: number;
  toPercentage?: number;
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
   * 动态获取本地资源：resolveAssetSource(require('./x.svga')) 解析为原生可读 URI。
   */
  static getAssets(nodeRequire: number | string): string {
    const resolved = resolveAssetSource(nodeRequire as number);
    return resolved ? resolved.uri : '';
  }

  /**
   * 判断是否有缓存。
   * 鸿蒙端与 Android 语义一致：按 URL 派生缓存 key 查询本地文件缓存；
   * iOS 端恒返回 true（原库行为）。
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
   * 加载动画
   * source 数据源
   */
  load(source: string) {
    this.setState({
      source,
    });
  }

  /** 开始动画 */
  startAnimation() {
    this.setState({
      currentState: 'start',
    });
  }

  /** 暂停动画 */
  pauseAnimation() {
    this.setState({
      currentState: 'pause',
    });
  }

  /** 停止动画 */
  stopAnimation() {
    this.setState({
      currentState: 'stop',
    });
  }

  /** 清空动画 */
  clearAnimation() {
    this.setState({
      currentState: 'clear',
    });
  }

  /**
   * 跳到某帧，然后继续（暂停）播放动画
   * toFrame 指定跳到某一帧
   * andPlay 播放状态
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
   * 跳到某进度，然后继续（暂停）播放动画
   * toPercentage 指定跳到某进度
   * andPlay 播放状态
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
