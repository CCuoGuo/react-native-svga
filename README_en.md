> Document Template: v0.4.2

<p align="center">
  <h1 align="center"> <code>react-native-svga</code> </h1>
</p>

This project is based on [react-native-svga](https://github.com/Smallworld-P/react-native-svga) .

This third-party library has been migrated to Gitcode and is now available for direct download from npm, the new package name is: `@react-native-ohos/react-native-svga`, The version correspondence details are as follows:

| Name | Version(Npm Address) | Release Information | Supported RN Version | Supported Autolink | Compile API Version | Community Baseline Version | Source code address |
| ---- | -------------------- | ------------------- | -------------------- | ------------------ | ------------------- | -------------------------- | ------------------- |
| @react-native-ohos/react-native-svga | [~1.0.9](https://www.npmjs.com/package/@react-native-ohos/react-native-svga) | [Gitcode Releases](https://gitcode.com/openharmony-sig/rntpc_react-native-svga/releases) | 0.77.* | Yes | API12+ | 1.0.9 | [br_rnoh0.77](https://gitcode.com/openharmony-sig/rntpc_react-native-svga/tree/br_rnoh0.77) |

## Introduction

@react-native-ohos/react-native-svga is a library for playing SVGA animations in React Native apps.

Its core functions are:

- Play SVGA animations – Play bitmap SVGA animations from network sources (http/https URLs), local packaged assets (resolved via `getAssets(require(...))`), and `file://` sandbox paths; commonly used for live-streaming gift effects.
- Provide React components and instance methods – Encapsulate the SVGA player as the `SVGAView` component, with ref instance methods for play/pause/stop/clear, frame seeking, and progress seeking.
- Support cache management – Provide `isCached` for cache queries and `advanceDownload` for batch pre-downloading; after pre-downloading, animations can still be played offline.

> [!NOTE] The SVGA parsing and rendering engine on the HarmonyOS side is self-developed in this library (ArkTS: zlib decompression → protobuf/JSON parsing → PixelMap decoding → Canvas per-frame matrix drawing); there is no need to import the SVGAPlayer native library.

## Installation

Go to the project directory and execute the following instruction:

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

|                        | Is supported autolink | Supported RN Version |
| ---------------------- | --------------------- | -------------------- |
| ~1.0.9                 | Yes                   | 0.77                 |

Projects using AutoLink need to be configured according to this document, AutoLink framework guide: https://gitcode.com/openharmony-sig/ohos_react_native/blob/master/docs/zh-cn/Autolinking.md

If the version you are using supports Autolink and the project has integrated Autolink, you can skip the ManualLink configuration.

<details>
  <summary>ManualLink: This step provides guidance for manually configuring native dependencies.</summary>

Open the `harmony` directory of the OpenHarmony project in DevEco Studio.

### 1. Overrides RN SDK

To ensure the project relies on the same version of the RN SDK, you need to add an `overrides` field in the project's root `oh-package.json5` file, specifying the RN SDK version to be used. The replacement version can be a specific version number, a semver range, or a locally available HAR package or source directory.

For more information about the purpose of this field, please refer to the [official documentation](https://developer.huawei.com/consumer/en/doc/harmonyos-guides-V5/ide-oh-package-json5-V5#en-us_topic_0000001792256137_overrides).

```json
{
  "overrides": {
    "@rnoh/react-native-openharmony": "~0.77.0" // ohpm version
    // "@rnoh/react-native-openharmony" : "./react_native_openharmony.har" // a locally available HAR package
    // "@rnoh/react-native-openharmony" : "./react_native_openharmony" // source code directory
  }
}
```

### 2. Introducing Native Code

Currently, two methods are available:

- Use the HAR file.
- Directly link to the source code.

Method 1 (recommended): Use the HAR file.

> [!TIP] The HAR file is stored in the `harmony` directory in the installation path of the third-party library.

Open `entry/oh-package.json5` file and add the following dependencies:

```json
"dependencies": {
    "@react-native-ohos/react-native-svga": "file:../../node_modules/@react-native-ohos/react-native-svga/harmony/svga.har"
  }
```

Click the `sync` button in the upper right corner.

Alternatively, run the following instruction on the terminal:

```bash
cd entry
ohpm install
```

Method 2: Directly link to the source code.

> [!TIP] For details, see [Directly Linking Source Code](https://gitcode.com/openharmony-sig/ohos_react_native/blob/master/docs/zh-cn/link-source-code.md).

### 3. Configuring CMakeLists and Introducing SvgaPackage

Open `entry/src/main/cpp/CMakeLists.txt` and add the following code:

```diff
set(OH_MODULES "${CMAKE_CURRENT_SOURCE_DIR}/../../../oh_modules")

# RNOH_BEGIN: manual_package_linking_1
+ add_subdirectory("${OH_MODULES}/@react-native-ohos/react-native-svga/src/main/cpp" ./svga)
# RNOH_END: manual_package_linking_1

# RNOH_BEGIN: manual_package_linking_2
+ target_link_libraries(rnoh_app PUBLIC svga)
# RNOH_END: manual_package_linking_2
```

Open `entry/src/main/cpp/PackageProvider.cpp` and add the following code:

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

### 4. Introducing SvgaPackage to ArkTS

Open `entry/src/main/ets/RNPackagesFactory.ets` file and add the following code:

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

### Running

Click the `sync` button in the upper right corner.

Alternatively, run the following instruction on the terminal:

```bash
cd entry
ohpm install
```

Then build and run the code.

## Constraints

### Compatibility

This document is verified based on the following versions:

1. RNOH: 0.77.*; SDK: HarmonyOS 6.0.2 Release SDK; IDE: DevEco Studio 6.0.2 Release; ROM: Mate70Pro;

### API requirements

> [!TIP] The current third-party library supports compilation in `API12+` projects and execution on `API12+` ROMs.

### Permission requirements

- Playing or pre-downloading network svga files requires the network permission (required by `@ohos.net.http`, normal level, automatically granted, no dynamic application needed); playing local packaged assets and `file://` sandbox paths requires no permission.

  Add the following to `entry/src/main/module.json5`:

```json
requestPermissions: [
  {
    name: "ohos.permission.INTERNET",
  },
],
```

## Example

The following code shows the basic use scenario of the repository:

> [!WARNING] The name of the imported repository remains unchanged (`react-native-svga`, mapped to the HarmonyOS package via the RNOH alias).

```tsx
import React, {useRef} from 'react';
import {Modal, View} from 'react-native';
import {SVGAView, SVGAModule} from 'react-native-svga';

// 1. Play a network / local SVGA animation
const maskStyle = {flex: 1, backgroundColor: 'rgba(0,0,0,0.5)'};
const playerStyle = {width: 300, height: 300};
const Player = () => {
  const svgaRef = useRef<SVGAView>(null);
  return (
    <Modal transparent visible>
      <View style={maskStyle}>
        <SVGAView
          ref={svgaRef}
          source={'https://cdn.jsdelivr.net/gh/yyued/SVGA-Samples@master/heartbeat.svga'}
          loops={1}
          clearsAfterStop
          style={playerStyle}
          onFinished={() => console.log('finished')}
          onFrame={frame => console.log('current frame', frame)}
          onPercentage={p => console.log('progress', p)}
        />
      </View>
    </Modal>
  );
};

// 2. Utilities: local asset resolution / cache query / batch pre-download
const uri = SVGAModule.getAssets(require('./assets/angel.svga'));
SVGAModule.isCached('https://example.com/gift.svga').then(cached => console.log(cached));
SVGAModule.advanceDownload(['https://example.com/gift1.svga', 'https://example.com/gift2.svga']);

// 3. ref instance methods: playback control and seeking
// svgaRef.current?.startAnimation();  play from the beginning
// svgaRef.current?.pauseAnimation();  pause at the current frame
// svgaRef.current?.stopAnimation();   stop (clearsAfterStop decides whether to clear the canvas)
// svgaRef.current?.clearAnimation();  stop and clear the canvas
// svgaRef.current?.stepToFrame(30, true);        seek to frame 30 and continue playing
// svgaRef.current?.stepToPercentage(0.5, false); seek to 50% progress and pause
// svgaRef.current?.load(newSource);   switch the data source
```

## Available APIs

For details, see [react-native-svga](https://github.com/Smallworld-P/react-native-svga).

The following are the currently supported component properties on HarmonyOS:

### Components

> [!TIP] The **Platform** column indicates the platform where the properties are supported in the original third-party library.

> [!TIP] If the value of **HarmonyOS Support** is **yes**, it means that the HarmonyOS platform supports this property; **no** means the opposite; **partially** means some capabilities of this property are supported. The usage method is the same on different platforms and the effect is the same as that of iOS or Android.

| Name | Type | Required | Platform | HarmonyOS Support | Description |
| ---- | ---- | -------- | -------- | ----------------- | ----------- |
| SVGAView | ISvgaProps | Yes | All | Yes | SVGA animation rendering component (view name RNSVGA), loads and renders bitmap SVGA animations frame by frame |

### Properties

#### SVGAView: SVGA animation rendering component

**ISvgaProps**

| Name | Type | Default | Required | Platform | HarmonyOS Support | Description |
| ---- | ---- | ------- | -------- | -------- | ----------------- | ----------- |
| source | string | / | Yes | All | Yes | Data source: http(s) URL / `file://` sandbox path / packaged asset URI resolved by `getAssets` |
| loops | number | 0 | No | All | Yes | Loop count, 0 = infinite looping |
| clearsAfterStop | boolean | true | No | All | Yes | Whether to clear the canvas after playback completes |
| currentState | 'start' \| 'pause' \| 'stop' \| 'clear' \| 'play' | / | No | All | Yes | Playback state control (property form, same semantics as the instance methods) |
| toFrame | number | / | No | All | Yes | Dock to the specified frame (< 0 is ignored) |
| toPercentage | number | / | No | All | Yes | Dock to the specified progress 0.0~1.0 (< 0 is ignored) |
| onFinished | () => void | / | No | All | Yes | Callback when the animation playback completes |
| onFrame | (value: number) => void | / | No | All | Yes | Callback when a frame is reached (frame number as an integer; emitted only when the frame number changes, a natural throttle) |
| onPercentage | (value: number) => void | / | No | All | Yes | Playback progress callback (0~1 time progress) |
| style | object | / | No | All | Yes | Player area style (width, height, background color, etc.); the animation is displayed centered with AspectFill cropping |

### Instance methods

**SVGAView instance methods**, invoked through the component's ref, for example: `svgaRef.current?.startAnimation()`.

| Name | Type | Parameter Type | Return Value | Required | Platform | HarmonyOS Support | Description |
| ---- | ---- | -------------- | ------------ | -------- | -------- | ----------------- | ----------- |
| load | function | source: string | void | No | All | Yes | Load (switch) the animation data source |
| startAnimation | function | / | void | No | All | Yes | Play the animation from the beginning |
| pauseAnimation | function | / | void | No | All | Yes | Pause at the current frame |
| stopAnimation | function | / | void | No | All | Yes | Stop playback (clearsAfterStop decides whether to clear the canvas) |
| clearAnimation | function | / | void | No | All | Yes | Stop playback and clear the canvas |
| stepToFrame | function | toFrame: number, andPlay: boolean | void | No | All | Yes | Seek to the specified frame; andPlay decides whether to continue playing or dock |
| stepToPercentage | function | toPercentage: number, andPlay: boolean | void | No | All | Yes | Seek to the specified progress; andPlay decides whether to continue playing or dock |

### API

**SVGAModule static methods**, a utility class providing local asset resolution and cache management.

| Name | Type | Parameter Type | Return Value | Required | Platform | HarmonyOS Support | Description |
| ---- | ---- | -------------- | ------------ | -------- | -------- | ----------------- | ----------- |
| getAssets | function | nodeRequire: number | string | No | All | Yes | Resolve the `require('./x.svga')` packaged asset into a natively readable URI |
| isCached | function | url: string | Promise\<boolean\> | No | All | Yes | Query whether the URL has been cached locally (HarmonyOS has the same semantics as Android: a real local cache query; iOS always returns true, which is the original library's behavior) |
| advanceDownload | function | urls: Array\<string\> | void | No | All | Yes | Batch pre-download network svga files to the cache directory (non-http(s) sources are silently skipped; failures are silent) |

### Platform differences

- Event channel form: HarmonyOS is consistent with iOS (three independent callback events: onFinished/onFrame/onPercentage); Android uses a single `topChange` event + `action` field dispatch (the JS layer has already handled the platform branch, so business code is unaware)
- Scaling mode: HarmonyOS is consistent with the forked iOS, using AspectFill centered cropping; the upstream Android SVGAPlayer defaults to FIT_CENTER (this difference is an inherent difference among the three platforms of the original library, not introduced by the HarmonyOS adaptation)
- The TurboModule is uniformly registered as `RNSVGAManager` (the JS layer explicitly obtains it in the `Platform.OS === 'harmony'` branch, unaffected by the module name inconsistency issue on the original library's Android side)

## Known Issues

**Rendering capabilities**

- [ ] SVGA vector sprites (v1 FrameEntity vector shapes / v2 shapes and dynamicShapes SVG path fill/stroke/gradient) are not implemented — the original library's Android/iOS relies on the vector rendering built into the SVGAPlayer engine; the HarmonyOS engine is self-developed in this library, and the first version implements the bitmap pipeline as defined by the PRD (complete coverage of the bitmap animation use cases of this fork's live-streaming gift scenarios; all Example samples can be played normally). The bitmap parts of vector resources can still be rendered normally; vector sprites are gracefully skipped without crashing
- [ ] matte masks (mask blending effects between sprites) are not implemented — same as above, not the goal of the bitmap pipeline; measured samples in this library's Example do not use matte
- [ ] SVGA audio tracks (embedded audio playback) are not implemented — the original library's Android/iOS sides do not expose playback APIs either (not implemented upstream, not a HarmonyOS platform deficiency); HarmonyOS behaves consistently with both ends

**Others**

- [ ] The original github raw addresses of the network samples are unreachable in some network environments; the Example has switched to the jsDelivr CDN mirror (the resource content is the same)

## Others

None.

## Directory Structure
```text
/react-native-svga  # project root
├── src/                # JS-side source (index.tsx entry: SVGAView/SVGAModule; specs/v1 Codegen specs)
├── dist/               # JS build artifacts (commonjs / module / typescript)
├── harmony/
│   ├── svga/           # HarmonyOS HAR source project (cpp Package registration + ets self-developed rendering engine svga/)
│   └── svga.har        # HAR build artifact
├── example/            # demo test project (RN-side source + harmony OpenHarmony project + svga sample assets)
├── package.json        # npm package @react-native-ohos/react-native-svga descriptor
├── babel.config.js
├── tsconfig.json
├── CHANGELOG.md
├── COMMITTERS.md
├── LICENSE
├── OAT.xml
├── README.OpenSource
├── README.md
└── README_en.md
```

## How to Contribute

If you find any issues while using this package, please submit an [Issue](https://gitcode.com/openharmony-sig/rntpc_react-native-svga/issues). Contributions are also welcome via [PR](https://gitcode.com/openharmony-sig/rntpc_react-native-svga/pulls).

## License

This project is licensed under [The MIT License (MIT)](https://github.com/Smallworld-P/react-native-svga/blob/master/LICENSE). Please feel free to enjoy and participate in open source.
