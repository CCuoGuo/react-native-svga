> 文档模板：v0.4.2

<p align="center">
  <h1 align="center"> <code>react-native-svga</code> </h1>
</p>

本项目基于 [react-native-svga](https://github.com/Smallworld-P/react-native-svga) 开发。

该第三方库的仓库已迁移至 GitCode，且支持直接从 npm 下载，新的包名为：`@react-native-ohos/react-native-svga` 版本所属关系如下：

| 三方库名称 | 三方库版本（npm地址） | 发布信息 | 支持RN版本 | Autolink | 编译API版本 | 社区基线版本 | 源码地址 |
| ---------- | --------------------- | -------- | ---------- | -------- | ----------- | ------------ | -------- |
| @react-native-ohos/react-native-svga | [~1.0.0（开发中）](https://www.npmjs.com/package/@react-native-ohos/react-native-svga) | [GitHub Releases](https://github.com/react-native-oh-library/react-native-svga/releases) | 0.72.*/0.77.\*/0.82.\*/0.84.\* | 是 | API12+ | 1.0.9 | [master](https://github.com/react-native-oh-library/react-native-svga/tree/master) |

## 简介

@react-native-ohos/react-native-svga 三方库是一个在 React Native 应用中播放 SVGA 动画的库。
它的核心作用可以概括为：

- 播放 SVGA 动画：支持播放网络（http/https URL）、本地打包资源（`getAssets(require(...))` 解析）与 `file://` 沙箱路径的 SVGA 位图动画，常用于直播礼物等动效场景。
- 提供 React 组件与实例方法：把 SVGA 播放器封装为 `SVGAView` 组件，配合 ref 实例方法实现播放/暂停/停止/清空、跳帧、跳进度等控制。
- 支持缓存管理：提供 `isCached` 缓存查询与 `advanceDownload` 批量预下载，预下载后断网仍可播放。

## 下载安装

进入到工程目录并输入以下命令：

**npm**

```bash
npm install react-native-svga@1.0.9
npm install @react-native-ohos/react-native-svga
```

**yarn**

```bash
yarn add react-native-svga@1.0.9
yarn add @react-native-ohos/react-native-svga
```

## Link

|                                      | 是否支持autolink | RN框架版本 |
| ------------------------------------ | ---------------- | ---------- |
| ~1.0.0-beta.1                               | 是               | 0.72.*/0.77.\*/0.82.\*/0.84.\*       |

使用AutoLink的工程需要根据该文档配置，Autolink框架指导文档：https://gitcode.com/openharmony-sig/ohos_react_native/blob/master/docs/zh-cn/Autolinking.md

如您使用的版本支持 Autolink，并且工程已接入 Autolink，可跳过ManualLink配置。
<details>
  <summary>ManualLink: 此步骤为手动配置原生依赖项的指导</summary>

首先需要使用 DevEco Studio 打开项目里的 OpenHarmony 工程 `harmony`。

### 1. Overrides RN SDK

为了让工程依赖同一个版本的 RN SDK，需要在工程根目录的 `oh-package.json5` 添加 overrides 字段，指向工程需要使用的 RN SDK 版本。替换的版本既可以是一个具体的版本号，也可以是一个模糊版本，还可以是本地存在的 HAR 包或源码目录。

关于该字段的作用请阅读[官方说明](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/ide-oh-package-json5-V5#en-us_topic_0000001792256137_overrides)

```json
{
  "overrides": {
    "@rnoh/react-native-openharmony": "~0.72.139" // ohpm 在线版本
    // "@rnoh/react-native-openharmony" : "./react_native_openharmony.har" // 指向本地 har 包的路径
    // "@rnoh/react-native-openharmony" : "./react_native_openharmony" // 指向源码路径
  }
}
```

### 2. 引入原生端代码

目前有两种方法：

- 通过 har 包引入；
- 直接链接源码。

方法一：通过 har 包引入（推荐）

> [!TIP] har 包位于三方库安装路径的 `harmony` 文件夹下。

打开 `entry/oh-package.json5`，添加以下依赖

```json
"dependencies": {
    "@react-native-ohos/react-native-svga": "file:../../node_modules/@react-native-ohos/react-native-svga/harmony/svga.har"
  }
```

点击右上角的 `sync` 按钮

或者在命令行终端执行：

```bash
cd entry
ohpm install
```

方法二：直接链接源码

> [!TIP] 如需使用直接链接源码，请参考[直接链接源码说明](https://gitcode.com/openharmony-sig/ohos_react_native/blob/master/docs/zh-cn/link-source-code.md)

### 3. 配置 CMakeLists 和引入 SvgaPackage

打开 `entry/src/main/cpp/CMakeLists.txt`，添加：

```diff
set(OH_MODULES "${CMAKE_CURRENT_SOURCE_DIR}/../../../oh_modules")

# RNOH_BEGIN: manual_package_linking_1
+ add_subdirectory("${OH_MODULES}/@react-native-ohos/react-native-svga/src/main/cpp" ./svga)
# RNOH_END: manual_package_linking_1

# RNOH_BEGIN: manual_package_linking_2
+ target_link_libraries(rnoh_app PUBLIC svga)
# RNOH_END: manual_package_linking_2
```

打开 `entry/src/main/cpp/PackageProvider.cpp`，添加：

```diff
#include "RNOH/PackageProvider.h"
+ #include "SvgaPackage.h"

using namespace rnoh;

std::vector<std::shared_ptr<Package>> PackageProvider::getPackages(Package::Context ctx) {
    return {
+     std::make_shared<SvgaPackage>(ctx),
    };
}
```

### 4. 在 ArkTs 侧引入 SvgaPackage

打开 `entry/src/main/ets/RNPackagesFactory.ets`，添加：

```diff
  ...
+ import { SvgaPackage } from '@react-native-ohos/react-native-svga/ts';

export function createRNPackages(ctx: RNPackageContext): RNPackage[] {
  return [
+   new SvgaPackage(ctx),
  ];
}
```
</details>

### 运行

点击右上角的 `sync` 按钮

或者在命令行终端执行：

```bash
cd entry
ohpm install
```

然后编译、运行即可。

## 约束与限制

### 兼容性

本文档内容基于以下版本验证通过：

1. RNOH: 0.84.2; SDK: HarmonyOS 6.0.1 Release SDK; IDE: DevEco Studio 26.0.0 Beta1; ROM: 6.0.0.120 SP7;
2. RNOH: 0.82.1; SDK: HarmonyOS 6.0.1 Release SDK; IDE: DevEco Studio 6.0.1 Release; ROM: 6.0.0.120 SP7;
3. RNOH: 0.77.18; SDK: HarmonyOS 6.0.0 Release SDK; IDE: DevEco Studio 6.0.0.858; ROM: 6.0.0.112;
4. RNOH: 0.72.96; SDK: HarmonyOS 6.0.0 Release SDK; IDE: DevEco Studio 6.0.0.858; ROM: 6.0.0.112;

### 编译运行API要求

> [!TIP] 当前三方库支持在 `API12+` 工程编译，及 `API12+` ROM 运行。

### 权限要求

- 播放/预下载网络 svga 需要网络权限（`@ohos.net.http` 要求，normal 级自动授予，无需动态申请）；

  在 `entry/src/main/module.json5` 中添加：

```json
requestPermissions: [
  {
    name: "ohos.permission.INTERNET",
  },
],
```

## 使用示例

下面的代码展示了这个库的基本使用场景：

> [!WARNING] 使用时 import 的库名不变（`react-native-svga`，由 RNOH alias 映射到鸿蒙包）。

```tsx
import React, {useRef} from 'react';
import {Button, View} from 'react-native';
import {SVGAView} from 'react-native-svga';

const App = () => {
  const svgaRef = useRef(null);
  return (
    <View style={{flex: 1, justifyContent: 'center', alignItems: 'center'}}>
      <SVGAView
        ref={svgaRef}
        source={'https://cdn.jsdelivr.net/gh/yyued/SVGA-Samples@master/heartbeat.svga'}
        loops={1}
        clearsAfterStop
        style={{width: 300, height: 300}}
        onFinished={() => console.log('播放完成')}
      />
      <Button title="重播" onPress={() => svgaRef.current?.startAnimation()} />
    </View>
  );
};

export default App;
```

## 使用说明

**播放设置**
```tsx
<SVGAView
  source={'https://example.com/gift.svga'} // 网络地址；本地打包资源用 SVGAModule.getAssets(require('./assets/angel.svga'))，也支持 file:// 沙箱路径
  loops={0}               // 循环次数，0 = 无限循环
  clearsAfterStop={true}  // 播放完成后是否清空画布
  style={{width: 300, height: 300}}
/>
```

**事件监听**
```tsx
<SVGAView
  source={uri}
  style={{width: 300, height: 300}}
  onFinished={() => {
    // 动画播放完成时调用
  }}
  onFrame={frame => {
    // 播放至某帧时调用（帧号整数，仅帧号变化时发出）
  }}
  onPercentage={p => {
    // 播放进度 0~1 实时回调
  }}
/>
```

**播放控制**
```tsx
const svgaRef = useRef<SVGAView>(null);

<SVGAView
  ref={svgaRef}
  source={uri}
  style={{width: 300, height: 300}}
/>

// 从头播放动画
svgaRef.current?.startAnimation();
// 暂停在当前帧
svgaRef.current?.pauseAnimation();
// 停止播放（clearsAfterStop 决定是否清屏）
svgaRef.current?.stopAnimation();
// 停止播放并清空画布
svgaRef.current?.clearAnimation();
// 跳到第 30 帧并继续播放
svgaRef.current?.stepToFrame(30, true);
// 跳到 50% 进度并停靠
svgaRef.current?.stepToPercentage(0.5, false);
// 切换数据源
svgaRef.current?.load(newSource);
```

**工具方法**
```tsx
import {SVGAModule} from 'react-native-svga';

// 解析本地打包资源为原生可读 URI
const uri = SVGAModule.getAssets(require('./assets/angel.svga'));
// 查询网络地址是否已缓存到本地
SVGAModule.isCached('https://example.com/gift.svga').then(cached => console.log(cached));
// 批量预下载网络 svga（预下载后断网仍可播放）
SVGAModule.advanceDownload(['https://example.com/gift1.svga', 'https://example.com/gift2.svga']);
```

## 接口说明

详细请查看 [react-native-svga 的文档介绍](https://github.com/Smallworld-P/react-native-svga)

以下为当前 OpenHarmony 支持的组件属性说明：

### 组件

> [!TIP] "Platform"列表示该属性在原三方库上支持的平台。

> [!TIP] "OpenHarmony Support"列为 yes 表示 OpenHarmony平台支持该属性；no 则表示不支持；partially 表示部分支持。使用方法跨平台一致，效果对标 iOS 或 Android 的效果。

| 名称 | 参数类型 | 必填 | 平台 | OpenHarmony平台支持 | 描述 |
| ---- | -------- | ---- | ---- | ----------------- | ---- |
| SVGAView | ISvgaProps | Yes | All | Yes | SVGA 动画渲染组件（视图名 RNSVGA），加载并逐帧渲染 SVGA 位图动画 |

### 属性

#### SVGAView：SVGA 动画渲染组件

**ISvgaProps**

| 名称 | 参数类型 | 默认值 | 必填 | 平台 | OpenHarmony平台支持 | 描述 |
| ---- | -------- | ------ | ---- | ---- | ----------------- | ---- |
| source | string | / | Yes | All | Yes | 数据源：http(s) URL / file:// 沙箱路径 / `getAssets` 解析的打包资源 URI |
| loops | number | 0 | No | All | Yes | 循环次数，0 = 无限循环 |
| clearsAfterStop | boolean | true | No | All | Yes | 播放完成后是否清空画布 |
| currentState | 'start' \| 'pause' \| 'stop' \| 'clear' \| 'play' | / | No | All | Yes | 播放状态控制（属性形式，与同名实例方法语义一致） |
| toFrame | number | / | No | All | Yes | 停靠到指定帧（< 0 忽略） |
| toPercentage | number | / | No | All | Yes | 停靠到指定进度 0.0~1.0（< 0 忽略） |
| onFinished | () => void | / | No | All | Yes | 动画播放完成回调 |
| onFrame | (value: number) => void | / | No | All | Yes | 播放至某帧回调（帧号整数，仅帧号变化时发出，天然节流） |
| onPercentage | (value: number) => void | / | No | All | Yes | 播放进度回调（0~1 时间进度） |
| style | object | / | No | All | Yes | 播放区域样式（宽高、背景色等），动画按 AspectFill 居中裁剪显示 |

### 实例方法

**SVGAView 实例方法**，通过组件的 ref 引用调用，例如：`svgaRef.current?.startAnimation()`。

| 名称 | 类型 | 参数类型 | 返回值 | 必填 | 平台 | OpenHarmony平台支持 | 描述 |
| ---- | ---- | -------- | ------ | ---- | ---- | ----------------- | ---- |
| load | function | source: string | void | No | All | Yes | 加载（切换）动画数据源 |
| startAnimation | function | 无 | void | No | All | Yes | 从头开始播放动画 |
| pauseAnimation | function | 无 | void | No | All | Yes | 暂停在当前帧 |
| stopAnimation | function | 无 | void | No | All | Yes | 停止播放（clearsAfterStop 决定是否清屏） |
| clearAnimation | function | 无 | void | No | All | Yes | 停止播放并清空画布 |
| stepToFrame | function | toFrame: number, andPlay: boolean | void | No | All | Yes | 跳到指定帧，andPlay 决定续播或停靠 |
| stepToPercentage | function | toPercentage: number, andPlay: boolean | void | No | All | Yes | 跳到指定进度，andPlay 决定续播或停靠 |

### API

**SVGAModule 静态方法**，工具类，提供本地资源解析与缓存管理能力。

| 名称 | 类型 | 参数类型 | 返回值 | 必填 | 平台 | OpenHarmony平台支持 | 描述 |
| ---- | ---- | -------- | ------ | ---- | ---- | ----------------- | ---- |
| getAssets | function | nodeRequire: number | string | No | All | Yes | 解析 `require('./x.svga')` 打包资源为原生可读 URI |
| isCached | function | url: string | Promise\<boolean\> | No | All | Yes | 查询 URL 是否已缓存到本地（鸿蒙与 Android 语义一致：真实查询本地缓存；iOS 恒返回 true，为原库行为） |
| advanceDownload | function | urls: Array\<string\> | void | No | All | Yes | 批量预下载网络 svga 到缓存目录（非 http(s) 源静默跳过，失败静默） |

## 遗留问题

**渲染能力**

- [ ] SVGA 矢量 sprite（v1 FrameEntity 矢量形状 / v2 shapes、dynamicShapes 的 SVG path 填充/描边/渐变）未实现——原库 Android/iOS 依赖 SVGAPlayer 引擎自带矢量渲染；鸿蒙引擎为本库自研，首版按 PRD 界定实现位图管线（对本 fork 直播礼物位图动效使用集完整覆盖，Example 全部样例可正常播放）。矢量资源中位图部分仍可正常渲染，矢量 sprite 优雅跳过不崩溃
- [ ] matte 遮罩（sprite 间遮罩混合效果）未实现——同上，位图管线非目标；实测本库 Example 全部样例均未使用 matte
- [ ] SVGA 音频轨（内嵌音频播放）未实现——原库 Android/iOS 两端均未暴露播放 API（上游未实现，非鸿蒙平台缺失），鸿蒙与两端行为一致

## 其他

### 播放触发时机（何时直接播放、何时需先切换状态）

**以下场景自动播放，无需调用播放方法：**

- `source` 首次设置或切换到新地址（含 `load(newSource)`）：加载完成后自动从头播放；
- `stepToFrame(x, true)` / `stepToPercentage(x, true)`（andPlay = true）：跳转后直接续播。

**调用 `startAnimation()`（点"播放"）的生效规则：**

`currentState` 为边沿触发（值变化才执行，对齐上游 iOS 语义）：

| 当前状态 | 调用 startAnimation() | 结果 |
| -------- | --------------------- | ---- |
| 从未设置过（首次） | ✅ 生效 | 从头播放 |
| 暂停（pause）后 | ✅ 生效 | 从头播放（非续播） |
| 停止（stop）/ 清空（clear）后 | ✅ 生效 | 从头播放 |
| 上一轮由 `stepToXxx(x, true)` 启动（状态为 play） | ✅ 生效 | 从头播放 |
| **自然播完后（loops ≥ 1 触发 onFinished，状态仍为 start）** | ❌ 无响应 | 同值命令被去重；需先调用 `pauseAnimation()` / `stopAnimation()` / `clearAnimation()` 任意一个切换状态，再 `startAnimation()` 即可重播 |

> [!TIP] `loops = 0` 无限循环不会自然停止，不存在上述"播完点播放无响应"的情况；`load()` 传入相同地址也不会重播（source 同值去重，切换数据源需传入不同地址）。

## 目录结构
```text
/react-native-svga  # 项目根目录
├── src/                # JS 侧源码（index.tsx 入口：SVGAView/SVGAModule；specs/v1 Codegen 规范）
├── dist/               # JS 构建产物（commonjs / module / typescript）
├── harmony/            # 鸿蒙平台适配层（HAR 源码工程与构建产物）
│   ├── svga/           # 鸿蒙 HAR 源码工程（cpp Package 注册 + ets 自研渲染引擎 svga/）
│   └── svga.har        # HAR 构建产物
├── example/            # demo 测试工程（RN 侧源码 + harmony 鸿蒙工程 + svga 示例资源）
├── package.json        # npm 包 @react-native-ohos/react-native-svga 描述
├── babel.config.js     # Babel 编译配置（JS 源码转译规则）
├── tsconfig.json       # TypeScript 编译配置（类型检查与产物声明）
├── CHANGELOG.md        # 版本变更记录
├── COMMITTERS.md       # 贡献者名单（committer 列表）
├── LICENSE             # 开源协议（MIT）
├── OAT.xml             # OAT 开源合规扫描配置（开源审查规则）
├── README.OpenSource   # 上游原库引入说明（原库地址 / 版本 / 修改点）
├── README.md           # 中文使用文档
└── README_en.md        # 英文使用文档
```

## 贡献代码

使用过程中发现任何问题都可以提交 [Issue](https://gitcode.com/openharmony-sig/rntpc_react-native-svga/issues)，当然，也非常欢迎提交 [PR](https://gitcode.com/openharmony-sig/rntpc_react-native-svga/pulls) 。

## 开源协议

本项目基于 [The MIT License (MIT)](https://github.com/Smallworld-P/react-native-svga/blob/master/LICENSE) ，请自由地享受和参与开源。
