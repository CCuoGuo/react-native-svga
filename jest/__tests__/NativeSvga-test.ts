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
 * NativeSvga spec 接线验证（白盒）：codegen spec 无业务逻辑，
 * 只需验证其通过 TurboModuleRegistry.get 以正确模块名取用。
 */

const sentinelModule = {
  isCached: jest.fn(),
  advanceDownload: jest.fn(),
};
const mockTurboModuleRegistryGet = jest.fn(() => sentinelModule);

jest.mock('react-native', () => ({
  TurboModuleRegistry: { get: mockTurboModuleRegistryGet },
}));

it("registers the spec under TurboModule name 'RNSVGAManager'", () => {
  const spec: unknown = require('../../src/specs/v1/NativeSvga').default;

  expect(mockTurboModuleRegistryGet).toHaveBeenCalledWith('RNSVGAManager');
  expect(spec).toBe(sentinelModule);
});
