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
 * SVGAViewNativeComponent spec 接线验证（白盒）：codegen 组件 spec 无业务
 * 逻辑，只需验证其以原生视图名 'RNSVGA' 注册。
 */

const sentinelComponent = {};
const mockCodegenNativeComponent = jest.fn(() => sentinelComponent);

jest.mock('react-native/Libraries/Utilities/codegenNativeComponent', () => ({
  __esModule: true,
  default: mockCodegenNativeComponent,
}));

it("codegen-registers the native component under view name 'RNSVGA'", () => {
  const component: unknown = require('../../src/specs/v1/SVGAViewNativeComponent')
    .default;

  expect(mockCodegenNativeComponent).toHaveBeenCalledWith('RNSVGA');
  expect(component).toBe(sentinelComponent);
});
