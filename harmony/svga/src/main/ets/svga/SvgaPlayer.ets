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
 * SVGA 播放状态机 + Canvas 渲染器 + 帧驱动。
 *
 * 行为对齐 SVGAPlayer-Android 2.5.15（RCTSVGAManager 依赖面）：
 * - startAnimation 从头播放；pauseAnimation 停在当前帧；
 * - stopAnimation(clear) 停止，clear || clearsAfterStop 时清空画布；
 * - stepToFrame / stepToPercentage 跳转，andPlay 决定续播或停靠；
 * - loops=0 无限循环；loops>0 播完 loops 遍触发 onFinished，
 *   clearsAfterStop（默认 true）决定播完后是否清空；
 * - viewBox → 画布按 AspectFill（对齐 fork HEAD「修改显示模式」提交）居中裁剪；
 * - 帧事件：帧号变化时发 onFrame(帧号) + onPercentage(时间进度 0~1)。
 *
 * 帧驱动：@ohos.graphics.displaySync 的 on('frame') 帧回调（aboutToAppear
 * 中注册以绑定 UI 上下文），按 movie 帧率由时间戳推算帧号；若回调未就绪
 * 则以 16ms 定时器兜底。
 */

import { displaySync } from '@kit.ArkGraphics2D';
import { SvgaMovie } from './SvgaTypes';

export interface SvgaPlayerCallbacks {
  onFinished: () => void;
  onFrame: (frame: number) => void;
  onPercentage: (percentage: number) => void;
}

export class SvgaPlayer {
  private renderCtx: CanvasRenderingContext2D;
  private callbacks: SvgaPlayerCallbacks;
  private movie: SvgaMovie | null = null;
  private loops: number = 0;
  private clearsAfterStop: boolean = true;
  private isPlaying: boolean = false;
  private currentFrame: number = 0;
  private hasDrawnFrame: boolean = false;
  /** 当前播放段前的累计进度（ms）。 */
  private elapsedBaseMs: number = 0;
  /** 当前播放段起始时间戳（ms，由帧回调提供；-1 = 尚未收到首帧回调）。 */
  private segmentStartMs: number = -1;
  /** 最近一次帧回调时间戳（ms），用于暂停时冻结进度。 */
  private lastTickMs: number = -1;
  private frameSync: displaySync.DisplaySync | null = null;
  private fallbackTimer: number = -1;
  private hasTicked: boolean = false;

  constructor(renderCtx: CanvasRenderingContext2D, callbacks: SvgaPlayerCallbacks) {
    this.renderCtx = renderCtx;
    this.callbacks = callbacks;
  }

  /** 启动帧驱动（须在组件 aboutToAppear 等 UI 上下文内调用）。 */
  public startFrameDriver(): void {
    try {
      this.frameSync = displaySync.create();
      this.frameSync.setExpectedFrameRateRange({ expected: 60, min: 0, max: 120 } as ExpectedFrameRateRange);
      this.frameSync.on('frame', (info: displaySync.IntervalInfo) => {
        this.onTick(info.timestamp / 1000000);
      });
      this.frameSync.start();
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      console.error(`[RNSVGA] displaySync init failed ${err.code}: ${err.message}`);
    }
  }

  /** 帧回调未就绪时的定时器兜底。 */
  private ensureFallbackTimer(): void {
    if (this.fallbackTimer >= 0) {
      return;
    }
    this.fallbackTimer = setInterval((): void => {
      this.onTick(Date.now());
    }, 16);
  }

  /** 播放请求后 1s 无任何帧回调 → 切换定时器兜底。 */
  private armFallbackWatchdog(): void {
    setTimeout((): void => {
      if (!this.hasTicked) {
        this.ensureFallbackTimer();
      }
    }, 1000);
  }

  /** 释放全部驱动资源（组件 aboutToDisappear 调用）。 */
  public destroy(): void {
    this.isPlaying = false;
    if (this.frameSync !== null) {
      try {
        this.frameSync.stop();
        this.frameSync.off('frame');
      } catch (e) {
        // 已销毁则忽略
      }
      this.frameSync = null;
    }
    if (this.fallbackTimer >= 0) {
      clearInterval(this.fallbackTimer);
      this.fallbackTimer = -1;
    }
    this.releaseMovie();
  }

  // ───────── 对外状态接口 ─────────

  public setLoops(loops: number): void {
    if (loops >= 0) {
      this.loops = loops;
    }
  }

  public setClearsAfterStop(clearsAfterStop: boolean): void {
    this.clearsAfterStop = clearsAfterStop;
  }

  public setMovie(movie: SvgaMovie): void {
    this.releaseMovie();
    this.movie = movie;
    this.isPlaying = false;
    this.currentFrame = 0;
    this.hasDrawnFrame = false;
    this.elapsedBaseMs = 0;
    this.segmentStartMs = -1;
  }

  public startAnimation(): void {
    if (this.movie === null) {
      return;
    }
    this.elapsedBaseMs = 0;
    this.segmentStartMs = -1;
    this.currentFrame = 0;
    this.hasDrawnFrame = false;
    this.isPlaying = true;
    this.armFallbackWatchdog();
    this.applyFrame(0, 0);
  }

  public pauseAnimation(): void {
    if (!this.isPlaying) {
      return;
    }
    this.isPlaying = false;
    if (this.segmentStartMs >= 0 && this.lastTickMs >= this.segmentStartMs) {
      this.elapsedBaseMs += this.lastTickMs - this.segmentStartMs;
    }
    this.segmentStartMs = -1;
  }

  public stopAnimation(clear: boolean): void {
    this.isPlaying = false;
    this.segmentStartMs = -1;
    if (clear || this.clearsAfterStop) {
      this.clearCanvas();
      this.currentFrame = 0;
      this.hasDrawnFrame = false;
    }
  }

  public stepToFrame(frame: number, andPlay: boolean): void {
    const m: SvgaMovie | null = this.movie;
    if (m === null || m.frameCount <= 0) {
      return;
    }
    const clamped: number = Math.max(0, Math.min(Math.floor(frame), m.frameCount - 1));
    this.elapsedBaseMs = (clamped / m.frameRate) * 1000;
    this.segmentStartMs = -1;
    this.isPlaying = andPlay;
    this.applyFrame(clamped, clamped / m.frameCount);
    if (andPlay) {
      this.armFallbackWatchdog();
    }
  }

  public stepToPercentage(percentage: number, andPlay: boolean): void {
    const m: SvgaMovie | null = this.movie;
    if (m === null || m.frameCount <= 0) {
      return;
    }
    const clamped: number = Math.max(0, Math.min(percentage, 1));
    this.stepToFrame(Math.floor(clamped * m.frameCount), andPlay);
  }

  public clearCanvas(): void {
    this.renderCtx.setTransform(1, 0, 0, 1, 0, 0);
    this.renderCtx.globalAlpha = 1;
    this.renderCtx.clearRect(0, 0, this.renderCtx.width, this.renderCtx.height);
  }

  /** Canvas 就绪/尺寸变化时重绘当前帧（暂停/停靠场景保持画面）。 */
  public invalidate(): void {
    if (this.movie !== null && this.hasDrawnFrame) {
      this.drawFrame(this.currentFrame);
    }
  }

  // ───────── 帧推进 ─────────

  private onTick(nowMs: number): void {
    this.hasTicked = true;
    this.lastTickMs = nowMs;
    const m: SvgaMovie | null = this.movie;
    if (m === null || !this.isPlaying) {
      return;
    }
    if (this.segmentStartMs < 0) {
      this.segmentStartMs = nowMs;
    }
    const totalTimeMs: number = (m.frameCount / m.frameRate) * 1000;
    if (totalTimeMs <= 0) {
      return;
    }
    const elapsedMs: number = this.elapsedBaseMs + (nowMs - this.segmentStartMs);
    if (this.loops > 0 && elapsedMs >= totalTimeMs * this.loops) {
      // 自然播完：定格末帧 → onFinished → 按 clearsAfterStop 清屏
      this.isPlaying = false;
      this.elapsedBaseMs = totalTimeMs * this.loops;
      this.segmentStartMs = -1;
      this.applyFrame(m.frameCount - 1, 1);
      this.callbacks.onFinished();
      if (this.clearsAfterStop) {
        this.clearCanvas();
        this.hasDrawnFrame = false;
      }
      return;
    }
    const loopMs: number = elapsedMs % totalTimeMs;
    const fraction: number = Math.min(loopMs / totalTimeMs, 1);
    const frame: number = Math.min(Math.floor(fraction * m.frameCount), m.frameCount - 1);
    if (frame !== this.currentFrame || !this.hasDrawnFrame) {
      this.applyFrame(frame, fraction);
    }
  }

  private applyFrame(frame: number, fraction: number): void {
    this.currentFrame = frame;
    this.hasDrawnFrame = true;
    this.drawFrame(frame);
    this.callbacks.onFrame(frame);
    this.callbacks.onPercentage(fraction);
  }

  // ───────── 渲染 ─────────

  private drawFrame(frame: number): void {
    const m: SvgaMovie | null = this.movie;
    if (m === null) {
      return;
    }
    const ctx: CanvasRenderingContext2D = this.renderCtx;
    const cw: number = ctx.width;
    const ch: number = ctx.height;
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.globalAlpha = 1;
    ctx.clearRect(0, 0, cw, ch);
    if (m.viewWidth <= 0 || m.viewHeight <= 0 || cw <= 0 || ch <= 0) {
      return;
    }
    // AspectFill：等比放大至铺满视图，居中裁剪（对齐 iOS contentMode 修改提交）
    const scale: number = Math.max(cw / m.viewWidth, ch / m.viewHeight);
    const offsetX: number = (cw - m.viewWidth * scale) / 2;
    const offsetY: number = (ch - m.viewHeight * scale) / 2;
    for (const sprite of m.sprites) {
      if (frame >= sprite.frames.length) {
        continue;
      }
      const f = sprite.frames[frame];
      if (f.alpha <= 0.001) {
        continue;
      }
      const pm = m.images.get(sprite.imageKey);
      if (pm === undefined) {
        continue;
      }
      const t = f.transform;
      ctx.save();
      ctx.setTransform(
        scale * t.a,
        scale * t.b,
        scale * t.c,
        scale * t.d,
        offsetX + scale * t.tx,
        offsetY + scale * t.ty
      );
      ctx.globalAlpha = Math.max(0, Math.min(1, f.alpha));
      ctx.drawImage(pm, 0, 0);
      ctx.restore();
    }
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.globalAlpha = 1;
  }

  private releaseMovie(): void {
    if (this.movie !== null) {
      this.movie.release();
      this.movie = null;
    }
  }
}
