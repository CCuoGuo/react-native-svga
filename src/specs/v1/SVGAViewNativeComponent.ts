/**
 * Copyright (c) 2025.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE-MIT file in the root directory of this source tree.
 */

import type { ViewProps } from 'react-native/Libraries/Components/View/ViewPropTypes';
import type { HostComponent } from 'react-native';
import codegenNativeComponent from 'react-native/Libraries/Utilities/codegenNativeComponent';
import type {
  Int32,
  Float,
  DirectEventHandler,
} from 'react-native/Libraries/Types/CodegenTypes';

/**
 * onFrame 事件负载：当前帧号（0 起，整数）。
 */
export interface OnFrameEvent {
  value: Int32;
}

/**
 * onPercentage 事件负载：播放进度（0.0 ~ 1.0）。
 */
export interface OnPercentageEvent {
  value: Float;
}

/**
 * SVGAView 原生组件 Spec（原 Android 视图名 RNSVGA / iOS 组件名一致）。
 *
 * 属性与 index.d.ts 的 ISvgaProps 一一对应；事件对齐 iOS 形态
 * （onFinished/onFrame/onPercentage 三个独立事件，Android 侧为单一
 * topChange + action 字段分发，鸿蒙不采用）。
 *
 * toFrame / toPercentage 取 -1 时原生侧忽略——JS 层 stepToFrame /
 * stepToPercentage 依赖「先置 -1 再置目标值」的两轮属性更新时序触发跳转。
 */
export interface NativeProps extends ViewProps {
  /** SVGA 动画数据源：http(s) URL / file:// 沙箱路径 / 打包资源 URI */
  source?: string;
  /** 循环次数，0 = 无限循环（默认 0） */
  loops?: Int32;
  /** 播放完成后是否清空画布（默认 true） */
  clearsAfterStop?: boolean;
  /** 播放状态：start / pause / stop / clear（内部扩展 play） */
  currentState?: string;
  /** 停靠到指定帧，< 0 时忽略 */
  toFrame?: Int32;
  /** 停靠到指定进度 0.0~1.0，< 0 时忽略 */
  toPercentage?: Float;
  /** 动画播放完成后回调 */
  onFinished?: DirectEventHandler<Readonly<{}>>;
  /** 动画播放至某帧时回调 */
  onFrame?: DirectEventHandler<OnFrameEvent>;
  /** 动画播放至某进度时回调 */
  onPercentage?: DirectEventHandler<OnPercentageEvent>;
}

export default codegenNativeComponent<NativeProps>(
  'RNSVGA'
) as HostComponent<NativeProps>;
