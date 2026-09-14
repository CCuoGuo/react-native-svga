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
 * SVGAView Fabric 组件（ArkTS 实现）。
 *
 * 结构遵循 RNOH Fabric 标准形态：ctx + tag + EventEmitter +
 * descriptorRegistry.subscribeToDescriptorChanges + RNViewBase 包裹 +
 * aboutToDisappear 清理。
 *
 * 属性 → 行为映射对齐 RCTSVGAManager.kt：
 * - source 变化 → 异步解析（缓存/下载/rawfile/沙箱）→ setMovie + 自动播放
 *   （对齐 Android decode onComplete → setVideoItem + startAnimation）
 * - currentState：start/pause/stop/clear（play 仅作为标记，无动作）
 * - toFrame / toPercentage：< 0 忽略（保真保留 JS 层两轮 setState 触发时序）
 * - loops / clearsAfterStop 实时可配
 * 事件对齐 iOS 形态：onFinished / onFrame(value) / onPercentage(value)。
 */

import { RNOHContext, RNViewBase } from '@rnoh/react-native-openharmony';
import { BusinessError } from '@kit.BasicServicesKit';
import { RNSVGA } from './generated/components/RNSVGA';
import { SvgaMovie } from './svga/SvgaTypes';
import { SvgaLoader } from './svga/SvgaLoader';
import { SvgaPlayer, SvgaPlayerCallbacks } from './svga/SvgaPlayer';

/**
 * 覆盖生成 PropsSelector 的默认值：
 * - clearsAfterStop 原库默认 true（Android @ReactProp defaultBoolean = true）；
 * - toFrame / toPercentage 默认 -1（忽略），否则未设置时会被误判为跳转到第 0 帧。
 */
class SvgaPropsSelector extends RNSVGA.PropsSelector {
  get clearsAfterStop(): boolean {
    return this.rawProps.clearsAfterStop ?? true;
  }

  get toFrame(): number {
    return this.rawProps.toFrame ?? -1;
  }

  get toPercentage(): number {
    return this.rawProps.toPercentage ?? -1;
  }
}

/** 使用上述修正默认值的 DescriptorWrapper。 */
export class SvgaDescriptorWrapper extends RNSVGA.DescriptorWrapper {
  protected createPropsSelector(): RNSVGA.PropsSelector {
    return new SvgaPropsSelector(this.descriptor.props, this.descriptor.rawProps);
  }
}

/** onFrame / onPercentage 事件负载（与生成的事件 payload 结构一致）。 */
interface SvgaEventValuePayload {
  value: number;
}

/** onFinished 空负载（对齐 iOS 发送空 dict 的行为）。 */
class SvgaEventFinishedPayload {}

@Component
export struct SvgaView {
  public static readonly NAME = RNSVGA.NAME;
  public ctx!: RNOHContext;
  public tag: number = 0;
  private eventEmitter: RNSVGA.EventEmitter | undefined = undefined;
  private cleanUpCallbacks: (() => void)[] = [];
  private player: SvgaPlayer | null = null;
  private renderSettings: RenderingContextSettings = new RenderingContextSettings(true);
  private renderCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.renderSettings);
  private lastSource: string = '';
  private lastCurrentState: string = '';
  private lastToFrame: number = -1;
  private lastToPercentage: number = -1;
  /** 加载令牌：source 变更后使旧的异步解析结果失效。 */
  private loadToken: number = 0;

  aboutToAppear(): void {
    this.eventEmitter = new RNSVGA.EventEmitter(this.ctx.rnInstance, this.tag);
    const callbacks: SvgaPlayerCallbacks = {
      onFinished: (): void => {
        const payload: SvgaEventFinishedPayload = new SvgaEventFinishedPayload();
        this.eventEmitter?.emit('finished', payload);
      },
      onFrame: (frame: number): void => {
        const payload: SvgaEventValuePayload = { value: frame };
        this.eventEmitter?.emit('frame', payload);
      },
      onPercentage: (percentage: number): void => {
        const payload: SvgaEventValuePayload = { value: percentage };
        this.eventEmitter?.emit('percentage', payload);
      },
    };
    this.player = new SvgaPlayer(this.renderCtx, callbacks);
    // displaySync 须在有 UI 上下文的时机启动
    this.player.startFrameDriver();
    const initial: SvgaDescriptorWrapper | null =
      this.ctx.descriptorRegistry.findDescriptorWrapperByTag<SvgaDescriptorWrapper>(this.tag);
    if (initial !== null) {
      this.onDescriptorChange(initial);
    }
    this.cleanUpCallbacks.push(
      this.ctx.descriptorRegistry.subscribeToDescriptorChanges(this.tag, (descriptor) => {
        this.onDescriptorChange(new SvgaDescriptorWrapper(descriptor));
      })
    );
  }

  aboutToDisappear(): void {
    this.cleanUpCallbacks.forEach((cb: () => void) => {
      cb();
    });
    this.cleanUpCallbacks = [];
    this.player?.destroy();
    this.player = null;
    this.eventEmitter = undefined;
  }

  private onDescriptorChange(dw: SvgaDescriptorWrapper): void {
    const selector: SvgaPropsSelector = dw.props as SvgaPropsSelector;
    const source: string = selector.source ?? '';
    const loops: number = selector.loops;
    const clearsAfterStop: boolean = selector.clearsAfterStop;
    const currentState: string = selector.currentState ?? '';
    const toFrame: number = selector.toFrame;
    const toPercentage: number = selector.toPercentage;

    this.player?.setLoops(loops);
    this.player?.setClearsAfterStop(clearsAfterStop);

    if (source !== this.lastSource) {
      this.lastSource = source;
      this.loadSource(source);
    }
    if (currentState !== this.lastCurrentState) {
      this.lastCurrentState = currentState;
      this.applyState(currentState);
    }
    if (toFrame !== this.lastToFrame) {
      this.lastToFrame = toFrame;
      // 与 Android 一致：toFrame < 0 直接 return（两轮属性更新时序依赖该语义）
      if (toFrame >= 0) {
        this.player?.stepToFrame(toFrame, currentState === 'play');
      }
    }
    if (toPercentage !== this.lastToPercentage) {
      this.lastToPercentage = toPercentage;
      if (toPercentage >= 0) {
        this.player?.stepToPercentage(toPercentage, currentState === 'play');
      }
    }
  }

  private applyState(state: string): void {
    const p: SvgaPlayer | null = this.player;
    if (p === null) {
      return;
    }
    if (state === 'start') {
      p.startAnimation();
    } else if (state === 'pause') {
      p.pauseAnimation();
    } else if (state === 'stop') {
      p.stopAnimation(false);
    } else if (state === 'clear') {
      p.stopAnimation(true);
    }
    // 'play'（stepToFrame/stepToPercentage 的 andPlay 标记）与未知值：无动作
  }

  private loadSource(source: string): void {
    if (source === '') {
      return;
    }
    const p: SvgaPlayer | null = this.player;
    if (p === null) {
      return;
    }
    this.loadToken += 1;
    const token: number = this.loadToken;
    SvgaLoader.load(source, this.ctx.uiAbilityContext)
      .then((movie: SvgaMovie) => {
        if (token !== this.loadToken) {
          // 已切换到新 source，丢弃过期结果并释放位图
          movie.release();
          return;
        }
        p.setMovie(movie);
        p.startAnimation();
      })
      .catch((e: Object) => {
        if (token === this.loadToken) {
          const err: BusinessError = e as BusinessError;
          console.error(`[RNSVGA] load failed: ${err.message}`);
        }
      });
  }

  build() {
    RNViewBase({ ctx: this.ctx, tag: this.tag }) {
      Canvas(this.renderCtx)
        .width('100%')
        .height('100%')
        .onReady(() => {
          this.player?.invalidate();
        })
        .onAreaChange(() => {
          this.player?.invalidate();
        })
    }
  }
}
