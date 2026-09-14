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
 * RN 深层路径的模块声明补充：
 * - resolveAssetSource 在 RN 0.72 包内无 .d.ts，本地补声明；
 * - Platform.OS 在鸿蒙运行时实际取值 'harmony'（由
 *   @react-native-oh/react-native-harmony 提供），vanilla RN 类型未包含该值。
 */
declare module 'react-native/Libraries/Image/resolveAssetSource' {
  interface ResolvedAssetSource {
    scale: number;
    width: number | undefined;
    height: number | undefined;
    uri: string;
  }
  function resolveAssetSource(source: number | ResolvedAssetSource): ResolvedAssetSource | undefined;
  export default resolveAssetSource;
}
