# Changelog
## 鸿蒙化Log
### 1.0.9-rc.1

- feat: add OpenHarmony support for react-native-svga
- feat: 自研 ArkTS SVGA 解析渲染引擎（zlib 解压 → protobuf/JSON 解析 → PixelMap 解码 → Canvas 逐帧矩阵绘制），无需引入 SVGAPlayer 原生库
- feat: 适配 RN 新架构（Codegen Fabric 组件 RNSVGA + TurboModule RNSVGAManager），支持 Autolink
- feat: 实现 SVGAView 全量公开属性（source/loops/clearsAfterStop/currentState/toFrame/toPercentage/onFinished/onFrame/onPercentage）
- feat: 实现 SVGAView 实例方法（load/startAnimation/pauseAnimation/stopAnimation/clearAnimation/stepToFrame/stepToPercentage）
- feat: 实现 SVGAModule 工具模块（getAssets/isCached/advanceDownload，isCached/advanceDownload 语义与 Android 端一致）
- feat: 事件通道对齐 iOS 形态（onFinished/onFrame/onPercentage 三个独立事件；onFrame/onPercentage 仅帧号变化时发出，天然节流）
- fix: JS 层工具模块在 `Platform.OS === 'harmony'` 分支显式取用 TurboModule `RNSVGAManager`，规避原库 Android 端模块名取空隐患
- docs: 补充 README.md / README_en.md / README.OpenSource / OAT.xml / COMMITTERS.md

## ReleaseLog
### 1.0.9

- 上游社区版本 [react-native-svga@1.0.9](https://github.com/Smallworld-P/react-native-svga)，本鸿蒙适配包以该版本为基线，详细发布记录见上游仓库
