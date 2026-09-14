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
 * src/index.tsx 白盒单元测试（不依赖设备）。
 *
 * Mock 策略：
 * - react-native：Platform.OS 用可变对象控制分支；NativeModules 提供
 *   SvgaMoudle / RNSVGAManager 两条 fallback 链；
 * - resolveAssetSource：控制 getAssets 的返回形态；
 * - specs/v1/NativeSvga 与 SVGAViewNativeComponent：codegen spec 直接替换
 *   为桩（spec 自身的接线在 jest/__tests__/ 下单独验证）。
 *
 * SVGAView 不做真实挂载：用 jest.spyOn 拦截 setState 观察状态迁移，
 * 直接调用 render() 检查产出的 React 元素。
 */

const mockPlatform = { OS: 'harmony' };
const mockLegacyModule = {
  isCached: jest.fn(),
  advanceDownload: jest.fn(),
};
const mockSvgaMoudleModule = {
  isCached: jest.fn(),
  advanceDownload: jest.fn(),
};
const mockNativeModules: {
  SvgaMoudle?: unknown;
  RNSVGAManager?: unknown;
} = {
  SvgaMoudle: undefined,
  RNSVGAManager: mockLegacyModule,
};
const mockResolveAssetSource = jest.fn();
const mockNativeSvga = {
  isCached: jest.fn(),
  advanceDownload: jest.fn(),
};
const mockNativeView = () => null;

jest.mock('react-native', () => ({
  NativeModules: mockNativeModules,
  Platform: mockPlatform,
}));

jest.mock('react-native/Libraries/Image/resolveAssetSource', () => ({
  __esModule: true,
  default: mockResolveAssetSource,
}));

jest.mock('../../src/specs/v1/NativeSvga', () => ({
  __esModule: true,
  default: mockNativeSvga,
}));

jest.mock('../../src/specs/v1/SVGAViewNativeComponent', () => ({
  __esModule: true,
  default: mockNativeView,
}));

import type { ReactElement } from 'react';
import type { ISvgaProps, SVGAViewState } from '../../src';

type Library = typeof import('../../src');

/** 按当前 mockPlatform / mockNativeModules 状态重新加载 src/index.tsx（重绑 _Module）。 */
function loadLibrary(): Library {
  let loaded: Library | undefined;
  jest.isolateModules(() => {
    loaded = require('../../src');
  });
  return loaded as Library;
}

let lib: Library;

beforeEach(() => {
  jest.clearAllMocks();
  mockPlatform.OS = 'harmony';
  mockNativeModules.SvgaMoudle = undefined;
  mockNativeModules.RNSVGAManager = mockLegacyModule;
  lib = loadLibrary();
});

describe('SVGAModule.getAssets', () => {
  it('returns the resolved asset uri', () => {
    mockResolveAssetSource.mockReturnValue({ uri: 'file://cache/a.svga' });

    expect(lib.SVGAModule.getAssets(42)).toBe('file://cache/a.svga');
    expect(mockResolveAssetSource).toHaveBeenCalledWith(42);
  });

  it('returns empty string when resolveAssetSource yields nothing', () => {
    mockResolveAssetSource.mockReturnValue(null);
    expect(lib.SVGAModule.getAssets(1)).toBe('');

    mockResolveAssetSource.mockReturnValue(undefined);
    expect(lib.SVGAModule.getAssets(1)).toBe('');
  });
});

describe('SVGAModule.isCached', () => {
  it('delegates to the RNSVGAManager TurboModule on harmony', async () => {
    mockNativeSvga.isCached.mockResolvedValue(false);

    await expect(lib.SVGAModule.isCached('http://x/a.svga')).resolves.toBe(
      false,
    );
    expect(mockNativeSvga.isCached).toHaveBeenCalledWith('http://x/a.svga');
    expect(mockLegacyModule.isCached).not.toHaveBeenCalled();
  });

  it('delegates to the legacy NativeModules fallback on android', async () => {
    mockPlatform.OS = 'android';
    mockLegacyModule.isCached.mockResolvedValue(true);

    await expect(lib.SVGAModule.isCached('http://x/a.svga')).resolves.toBe(
      true,
    );
    expect(mockLegacyModule.isCached).toHaveBeenCalledWith('http://x/a.svga');
    expect(mockNativeSvga.isCached).not.toHaveBeenCalled();
  });

  it('prefers NativeModules.SvgaMoudle over RNSVGAManager when present', async () => {
    mockPlatform.OS = 'android';
    mockNativeModules.SvgaMoudle = mockSvgaMoudleModule;
    mockSvgaMoudleModule.isCached.mockResolvedValue(true);
    const fresh = loadLibrary();

    await expect(fresh.SVGAModule.isCached('http://x/a.svga')).resolves.toBe(
      true,
    );
    expect(mockSvgaMoudleModule.isCached).toHaveBeenCalledWith(
      'http://x/a.svga',
    );
    expect(mockLegacyModule.isCached).not.toHaveBeenCalled();
  });

  it('resolves true without touching native modules on other platforms', async () => {
    mockPlatform.OS = 'ios';

    await expect(lib.SVGAModule.isCached('http://x/a.svga')).resolves.toBe(
      true,
    );
    expect(mockNativeSvga.isCached).not.toHaveBeenCalled();
    expect(mockLegacyModule.isCached).not.toHaveBeenCalled();
  });
});

describe('SVGAModule.advanceDownload', () => {
  it('delegates to the RNSVGAManager TurboModule on harmony', () => {
    lib.SVGAModule.advanceDownload(['http://x/a.svga', 'http://x/b.svga']);

    expect(mockNativeSvga.advanceDownload).toHaveBeenCalledWith([
      'http://x/a.svga',
      'http://x/b.svga',
    ]);
    expect(mockLegacyModule.advanceDownload).not.toHaveBeenCalled();
  });

  it('delegates to the legacy NativeModules fallback on other platforms', () => {
    mockPlatform.OS = 'ios';

    lib.SVGAModule.advanceDownload(['http://x/a.svga']);

    expect(mockLegacyModule.advanceDownload).toHaveBeenCalledWith([
      'http://x/a.svga',
    ]);
    expect(mockNativeSvga.advanceDownload).not.toHaveBeenCalled();
  });

  it('does not throw when no legacy module is bound', () => {
    mockPlatform.OS = 'android';
    mockNativeModules.SvgaMoudle = undefined;
    mockNativeModules.RNSVGAManager = undefined;
    const fresh = loadLibrary();

    expect(() => fresh.SVGAModule.advanceDownload(['http://x/a.svga'])).not
      .toThrow();
    expect(mockLegacyModule.advanceDownload).not.toHaveBeenCalled();
  });
});

describe('SVGAView state transitions', () => {
  function createView(props: ISvgaProps = {}) {
    const view = new lib.SVGAView(props);
    // 拦截 setState：仅记录状态迁移，避免未挂载组件触发 React no-op 警告
    const setState = jest.spyOn(view, 'setState').mockImplementation(() => {});
    return { view, setState };
  }

  it('starts with empty state', () => {
    const { view } = createView();
    expect(view.state).toEqual({});
  });

  it.each([
    ['load', ['http://x/a.svga'], { source: 'http://x/a.svga' }],
    ['startAnimation', [], { currentState: 'start' }],
    ['pauseAnimation', [], { currentState: 'pause' }],
    ['stopAnimation', [], { currentState: 'stop' }],
    ['clearAnimation', [], { currentState: 'clear' }],
  ] as const)('%s sets %s', (method, args, expected) => {
    const { view, setState } = createView();
    (view[method] as (...a: unknown[]) => void)(...args);
    expect(setState).toHaveBeenCalledTimes(1);
    expect(setState.mock.calls[0][0]).toEqual(expected);
  });

  it('stepToFrame resets to -1 first, then lands on the target frame (play)', () => {
    const { view, setState } = createView();

    view.stepToFrame(12, true);

    expect(setState).toHaveBeenCalledTimes(1);
    expect(setState.mock.calls[0][0]).toEqual({
      currentState: 'play',
      toFrame: -1,
    });

    // 第二轮 setState 在回调中触发（两轮属性更新时序）
    (setState.mock.calls[0][1] as () => void)();
    expect(setState).toHaveBeenCalledTimes(2);
    expect(setState.mock.calls[1][0]).toEqual({ toFrame: 12 });
  });

  it('stepToFrame pauses when andPlay is not strictly true', () => {
    const { view, setState } = createView();

    view.stepToFrame(5, false);
    expect(setState.mock.calls[0][0]).toEqual({
      currentState: 'pause',
      toFrame: -1,
    });

    setState.mockClear();
    view.stepToFrame(5, undefined as unknown as boolean);
    expect(setState.mock.calls[0][0]).toMatchObject({ currentState: 'pause' });
  });

  it('stepToPercentage resets to -1 first, then lands on the target percentage', () => {
    const { view, setState } = createView();

    view.stepToPercentage(0.75, true);

    expect(setState.mock.calls[0][0]).toEqual({
      currentState: 'play',
      toPercentage: -1,
    });

    (setState.mock.calls[0][1] as () => void)();
    expect(setState.mock.calls[1][0]).toEqual({ toPercentage: 0.75 });
  });

  it('stepToPercentage pauses when andPlay is false', () => {
    const { view, setState } = createView();

    view.stepToPercentage(0.5, false);
    expect(setState.mock.calls[0][0]).toEqual({
      currentState: 'pause',
      toPercentage: -1,
    });
  });

  it('componentWillUnmount stops the animation', () => {
    const { view, setState } = createView();

    view.componentWillUnmount();

    expect(setState).toHaveBeenCalledWith({ currentState: 'stop' });
  });
});

describe('SVGAView render', () => {
  it('renders nothing without a source', () => {
    const view = new lib.SVGAView({});
    expect(view.render()).toBeNull();
  });

  it('spreads props and state onto the native component', () => {
    const view = new lib.SVGAView({
      source: 'http://x/a.svga',
      loops: 3,
      clearsAfterStop: false,
    });
    (view as { state: SVGAViewState }).state = {
      currentState: 'start',
      toFrame: -1,
    };

    const element = view.render() as ReactElement<Record<string, unknown>>;

    expect(element.type).toBe(mockNativeView);
    expect(element.props.source).toBe('http://x/a.svga');
    expect(element.props.loops).toBe(3);
    expect(element.props.clearsAfterStop).toBe(false);
    expect(element.props.currentState).toBe('start');
    expect(element.props.toFrame).toBe(-1);
    // 无事件回调时不挂任何 listener
    expect(element.props.onFrame).toBeUndefined();
    expect(element.props.onPercentage).toBeUndefined();
    expect(element.props.onFinished).toBeUndefined();
    expect(element.props.onChange).toBeUndefined();
  });

  describe('on harmony/iOS: three independent event listeners', () => {
    it('wraps onFrame / onPercentage / onFinished callbacks', () => {
      const onFinished = jest.fn();
      const onFrame = jest.fn();
      const onPercentage = jest.fn();
      const view = new lib.SVGAView({
        source: 'http://x/a.svga',
        onFinished,
        onFrame,
        onPercentage,
      });

      const element = view.render() as ReactElement<
        Record<string, (event?: unknown) => void>
      >;

      element.props.onFrame!({ nativeEvent: { value: 7 } });
      expect(onFrame).toHaveBeenCalledWith(7);

      element.props.onPercentage!({ nativeEvent: { value: 0.5 } });
      expect(onPercentage).toHaveBeenCalledWith(0.5);

      element.props.onFinished!();
      expect(onFinished).toHaveBeenCalledTimes(1);
    });

    it('does not attach the android onChange dispatcher', () => {
      const view = new lib.SVGAView({ source: 'http://x/a.svga' });
      const element = view.render() as ReactElement<
        Record<string, unknown>
      >;
      expect(element.props.onChange).toBeUndefined();
    });
  });

  describe('on android: single onChange dispatcher', () => {
    function renderAndroid(props: ISvgaProps) {
      mockPlatform.OS = 'android';
      const view = new lib.SVGAView(props);
      const element = view.render() as ReactElement<
        Record<string, (event: { nativeEvent: { action?: string; value?: number } }) => void>
      >;
      return element.props.onChange!;
    }

    it('routes actions to the matching callback with the event value', () => {
      const onFinished = jest.fn();
      const onFrame = jest.fn();
      const onPercentage = jest.fn();
      const onChange = renderAndroid({
        source: 'http://x/a.svga',
        onFinished,
        onFrame,
        onPercentage,
      });

      onChange({ nativeEvent: { action: 'onFinished' } });
      expect(onFinished).toHaveBeenCalledTimes(1);

      onChange({ nativeEvent: { action: 'onFrame', value: 9 } });
      expect(onFrame).toHaveBeenCalledWith(9);

      onChange({ nativeEvent: { action: 'onPercentage', value: 0.25 } });
      expect(onPercentage).toHaveBeenCalledWith(0.25);
    });

    it('ignores unknown actions and missing callbacks without throwing', () => {
      const onChange = renderAndroid({ source: 'http://x/a.svga' });

      expect(() =>
        onChange({ nativeEvent: { action: 'onFinished' } }),
      ).not.toThrow();
      expect(() =>
        onChange({ nativeEvent: { action: 'unknown', value: 1 } }),
      ).not.toThrow();
    });
  });
});

describe('default export', () => {
  it('exposes SVGAView and SVGAModule', () => {
    const fresh = loadLibrary();
    expect(fresh.default.SVGAView).toBe(fresh.SVGAView);
    expect(fresh.default.SVGAModule).toBe(fresh.SVGAModule);
  });
});

describe('SVGAViewState shape', () => {
  it('carries only source/currentState/toFrame/toPercentage', () => {
    const state: SVGAViewState = {
      source: 'a',
      currentState: 'start',
      toFrame: 1,
      toPercentage: 0.5,
    };
    expect(Object.keys(state).sort()).toEqual([
      'currentState',
      'source',
      'toFrame',
      'toPercentage',
    ]);
  });
});
