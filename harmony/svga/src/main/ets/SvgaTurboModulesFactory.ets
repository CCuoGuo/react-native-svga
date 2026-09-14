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
 * SvgaPackage：Fabric 组件 + TurboModule 合并注册入口
 * （HAR autolink 只消费 index.ets 的 default Package，两类能力必须合并在
 * 同一个 Package 内注册，拆开会导致另一类能力永不注册）。
 *
 * - createDescriptorWrapperFactoryByDescriptorType：RNSVGA 组件 Descriptor 工厂
 * - getUITurboModuleFactoryByNameMap：RNSVGAManager TurboModule
 * - createWrappedCustomRNComponentBuilderByComponentNameMap：ArkTS Builder 路由
 */

import {
  RNOHPackage,
  UITurboModule,
  UITurboModuleContext,
  ComponentBuilderContext,
} from '@rnoh/react-native-openharmony';
import type {
  DescriptorWrapperFactoryByDescriptorType,
  DescriptorWrapperFactoryByDescriptorTypeCtx,
} from '@rnoh/react-native-openharmony/ts';
import { RNC } from './generated/ts';
import { SvgaView, SvgaDescriptorWrapper } from './SvgaView';
import { RNSVGATurboModule } from './RNSVGATurboModule';

@Builder
function buildSvgaView(ctx: ComponentBuilderContext) {
  SvgaView({ ctx: ctx.rnComponentContext, tag: ctx.tag })
}

export class SvgaPackage extends RNOHPackage {
  createDescriptorWrapperFactoryByDescriptorType(
    ctx: DescriptorWrapperFactoryByDescriptorTypeCtx
  ): DescriptorWrapperFactoryByDescriptorType {
    const result: DescriptorWrapperFactoryByDescriptorType = {};
    result[RNC.RNSVGA.NAME] = (wrapperCtx) => new SvgaDescriptorWrapper(wrapperCtx.descriptor);
    return result;
  }

  override getUITurboModuleFactoryByNameMap(): Map<string, (ctx: UITurboModuleContext) => UITurboModule | null> {
    return new Map<string, ((ctx: UITurboModuleContext) => UITurboModule)>()
      .set(RNSVGATurboModule.NAME, (ctx: UITurboModuleContext) => new RNSVGATurboModule(ctx));
  }

  createWrappedCustomRNComponentBuilderByComponentNameMap(): Map<string, WrappedBuilder<[ComponentBuilderContext]>> {
    return new Map<string, WrappedBuilder<[ComponentBuilderContext]>>()
      .set(RNC.RNSVGA.NAME, wrapBuilder(buildSvgaView));
  }
}
