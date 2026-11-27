# 秒遮 · QuickCover

**一秒遮住，放心发。**

打开应用，最近一张截图已经遮好；看一眼，点导出。图片全程不离开手机。

秒遮是一款面向 iOS 26+ 的本地隐私打码工具，采用原生 Liquid Glass 设计。发图之前，它自动识别人脸、手机号、身份证号、银行卡号、二维码等隐私内容，并支持用端侧 Apple Intelligence 语义补充识别姓名、住址、单号等上下文隐私；漏掉的地方点一下或拉个框即可补遮，最后导出一张全新图片，原图不动。

## 核心特性

- **开屏即遮**：授权相册后自动打开最近一张截图并完成打码；也支持相册选图、剪贴板粘贴与文档扫描仪导入。
- **双引擎端侧识别**：
  - **Vision 视觉 + 规则引擎**：默认识别人脸、手机号、身份证号、银行卡号、邮箱、网址、IP 地址、长串数字（如订单号）、疑似车牌、二维码与条形码。
  - **Apple Intelligence 语义隐私扫描**（iOS 26+ `FoundationModels`）：在编辑页底部轻点星芒按钮，或在「逐项检查」中一键扫描，补充识别常规规则易漏的姓名、收货地址、公司/学校、单号、车牌与余额等文本行；未开启 Apple Intelligence 的设备会自动回退到本地上下文规则引擎。
- **6 种遮挡样式 + 自由配色 + 48+ 表情库**：
  - **马赛克**（默认）：支持原图取色，也支持 12 款苹果精选配色 + 原生全色谱 `ColorPicker` 彩色马赛克，以及细腻 / 标准 / 粗粒三档粒度。
  - **斜条**：45° 斜向马赛克条纹，支持自定义条纹底色与粒度调节。
  - **魔术消除**：采用四向边界逆距离插值 + 滑动中值去渗色算法，不读取遮挡区内部任何像素（零字迹残留），可平滑重建渐变卡片、聊天气泡与柔和阴影。
  - **纯色**：12 款精选色板 + 原生全色谱取色器，彻底覆盖无像素痕迹。
  - **模糊**：三档粒度可调（模糊存在被还原的可能，敏感信息建议改用纯色或魔术消除）。
  - **表情贴纸**：底部快捷栏 + 深色液态玻璃表情选择器，内置「表情与情绪 / 可爱动物 / 花草与星光 / 隐私徽章」4 类共 48 款精选表情、最近使用记录与系统表情键盘任意输入。
- **交互式动画与魔术粒子效果**：添加、切换遮挡、手绘拉框、更换配色/表情及 AI 扫描时呈现虹彩扫光、扩散光环与星光粒子消散动画，识别期间画布边缘展示 Apple Intelligence 风格流光边框（完整适配系统「减弱动态效果」）。
- **便捷编辑与防盗水印**：支持点击未遮文字行快速加遮、手绘拉框（实时显示像素尺寸）、长按对比原图、多步撤销/重做，以及自定义斜向防盗水印（文字、透明度、密度实时预览）。
- **无痕隐私导出**：支持 PNG（无损）与 JPEG 格式，默认开启「去掉位置信息」，剥离 EXIF 拍摄地点与设备信息后存到照片、分享或拷贝。

## 怎么用

三屏完成，一次一张图。

1. **选图**：首次打开允许访问照片后，以后打开默认加载最新截图并自动打码；也可从相册挑选、直接粘贴剪贴板图片或使用相机文档扫描。
2. **编辑**：
   - 顶部状态胶囊显示已遮数量，右侧按钮可打开**水印设置**与**逐项检查**（按类别筛选并单独开关每一项，或开启「遮住所有文字」）。
   - 底部工具栏集成**撤销 / 重做 / 手绘拉框 / 样式托盘 / Apple Intelligence 智能扫描**与**导出**按钮；长按星芒按钮可一键「智能识别并魔术消除」或开启自动扫描。
   - 长按画布即可预览原图。
3. **导出**：确认预览、样式与隐私摘要后，一键存到照片、系统分享或拷贝到剪贴板。

## 能力边界与说明

- **魔术消除的实现边界**：iOS 26/27 尚未向第三方开放系统「照片」Clean Up 生成式补图模型。秒遮的「魔术消除」基于纯端侧边界插值重建，在纯色、渐变卡片、聊天气泡和文档背景上效果自然且零字迹残留；在复杂实景照片上如需绝对遮挡，建议使用纯色、彩色马赛克或表情贴纸。
- **自动识别仍建议导出前扫一眼**：复杂排版下折行号码或聊天头像可能未被自动框选，车牌号按字符形态推断，导出前看一眼并用手动框选或点击文字行补齐最稳妥。
- **关于马赛克与模糊的安全提示**：大号字体下的马赛克或模糊仍可能保留明暗轮廓，导出页会在检测到这类样式时给出提示，重要隐私推荐切到纯色或魔术消除。

## 图片不离开手机

秒遮没有账号，没有服务器，也没有第三方网络 SDK。视觉识别、Apple Intelligence 端侧模型推理与图像渲染全部在手机本地完成，飞行模式也能正常使用；仅在导出时生成新图，原图始终不受修改。

## 系统要求

- **系统**：iOS 26.0 或更新（适配 iOS 26 / 27 Liquid Glass；Apple Intelligence 语义模型需支持并开启 Apple Intelligence 的设备，其余设备自动使用本机上下文规则回退）。
- **语言**：简体中文、繁体中文、英文。

## 安装与版本更新

前往 [Releases](https://github.com/zxfccmm4/QuickCover/releases) 下载最新自检包 IPA，每次发布都会在 Release 页面写明具体更新内容与提交对比，也可查阅 [CHANGELOG.md](CHANGELOG.md)。

- IPA 未签名，需使用自签工具签名后安装。
- 自检包内置自检页（首页标题按住两秒进入）和 30 张本地基线测试图，其余体验与正式版一致。
- 每次推送至 `main`，GitHub Actions 会自动编译 `QuickCover-<版本>-<构建号>-selfcheck.ipa` 并发布至 `v<版本>-<构建号>` 标签；版本号不变时覆盖同标签附件。

## 自己编译

需要 Xcode 26 或更新版本（CI 当前使用 Xcode 26.5）。

```sh
# 仅编译应用（无签名）
xcodebuild build -project QuickCover.xcodeproj -scheme QuickCover \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO

# 构建自检包 IPA（输出位于 .airbuild/artifacts/selfcheck/QuickCoverSelfCheck.ipa）
XCODEBUILD=xcodebuild tools/selfcheck/build.sh

# 运行单元测试（将模拟器名称替换为本机已安装的 iOS 26+ 模拟器）
xcodebuild test -project QuickCover.xcodeproj -scheme QuickCover \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'
```

## 技术栈与目录结构

- 纯原生 **Swift 6 + SwiftUI**，零第三方依赖。
- 端侧框架：**Vision**（人脸 / 中英繁文字 / 二维码与条形码）、**FoundationModels**（Apple Intelligence 语义隐私识别）、**VisionKit**（文档扫描）、**CoreGraphics**（马赛克 / 斜条 / 魔术消除 / 水印渲染）。
- 测试图均为合成假数据，不包含任何真实个人信息，详见 [tools/baseline/FIXTURES.md](tools/baseline/FIXTURES.md)。

```text
QuickCover/
  App/            应用入口与导航状态（RootView / ShellModel）
  Screens/        引导页、选图与扫描页、编辑器、样式托盘、表情选择器、水印、导出页
  Editor/         编辑状态管理、清单、撤销重做、液态玻璃组件与多语言工具
  Recognition/    Vision 识别、Apple Intelligence 语义识别、6 种遮挡与魔术消除渲染器
  SelfCheck/      内置自检页与基线测试入口
QuickCoverTests/  250+ 项单元测试与 30 张合成基线测试图
tools/selfcheck/  自检包构建脚本与 GitHub Release 更新说明生成器
tools/baseline/   基线测试图生成与评分脚本
docs/ios/         产品简报、设计规格与界面文案
CHANGELOG.md      各版本发布更新日志
```

## 相关文档

- [更新日志](CHANGELOG.md)
- [产品简报](docs/ios/brief.md)
- [设计规格](docs/ios/design.md)
- [界面文案](docs/ios/copy.md)
- [基线图约定](tools/baseline/FIXTURES.md)

---

Made with AirBuild
