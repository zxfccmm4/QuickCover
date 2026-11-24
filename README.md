# 秒遮 · QuickCover

**一秒遮住，放心发。**

打开应用，最近一张截图已经遮好；看一眼，点导出。图片不离开手机。

秒遮是给截图和照片遮东西用的 iOS 应用。发出去之前，它把人脸、手机号、身份证号、银行卡号、二维码这些找出来遮上，漏的自己拖一个框补上，再导出一张新图。原图不动。

> 第一版，先给作者自己用。能找到什么、找不到什么，下面都写了，用之前看一眼。

## 怎么用

三屏，一次一张图。

1. **选图**。第一次打开先允许访问照片。允许之后，以后一打开就是最近一张截图，已经遮好；也可以自己选一张。
2. **编辑**。清单顶上一行写找到了什么，下面逐项列出，每一项能单独开关。漏了就点「手动框选」，拖一个框盖住；按住图能看原图。有撤销和重做。
3. **导出**。存到照片、分享或者拷贝。「去掉位置信息」默认开着，新图不带拍摄地点和设备信息。

## 它找什么

默认遮上：

- 人脸
- 手机号、身份证号、银行卡号
- 邮箱、网址、IP 地址
- 长串数字，像订单号
- 可能是车牌。不像的话，在那一行关掉
- 二维码、条形码

默认不遮「文字」。想全遮，打开「遮住所有文字」。

## 三种样式

- **马赛克**，默认
- **纯色**
- **模糊**。模糊可能被还原，重要的内容请改用纯色。

## 找不到的

- 姓名和昵称分不出来。要自己框，或者打开「遮住所有文字」。
- 车牌没有专门的找法，只按字的样子猜，所以只叫「可能是车牌」，要人看一眼。
- 聊天头像不会去找，自己框。
- 一个号码折成两行时，留在上一行末尾的那一小截有时没盖到。导出前看一眼，漏了自己补一个框。
- 字很大的时候，马赛克能看出分成几段；要连分段也看不出，用纯色。

## 图片不离开手机

秒遮没有账号，没有服务器。找和遮都在手机上做，飞行模式也能用。只在导出时生成一个新文件，原图不动。

## 系统要求

iOS 26 或更新。界面有简体中文、繁体中文、英文。

## 安装

到 [Releases](https://github.com/zxfccmm4/QuickCover/releases) 下载 IPA。

包不带签名，要先用自签工具签名再装，和别的自签 IPA 装法一样。

Release 里是自检包：带一个自检页（首页标题按住两秒）和 30 张测试图，其余和日常用的应用一样。

每次 `main` 有新代码，GitHub 会自动重出一个包挂到 Releases，文件名是 `QuickCover-<版本>-<构建号>-selfcheck.ipa`，标签是 `v<版本>-<构建号>`。版本号没变时，同一个 Release 里的文件会被换成最新的。

## 自己编译

需要 Xcode 26。

```sh
# 只编应用
xcodebuild build -project QuickCover.xcodeproj -scheme QuickCover \
  -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO

# 出自检包，和 Releases 里的同一种；IPA 在 .airbuild/artifacts/selfcheck/QuickCoverSelfCheck.ipa
XCODEBUILD=xcodebuild tools/selfcheck/build.sh

# 跑测试，需要一个 iOS 26 的模拟器；名字换成你机器上有的
xcodebuild test -project QuickCover.xcodeproj -scheme QuickCover \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro'
```

## 怎么做的

- 界面用 SwiftUI，Swift 6。找东西用系统自带的 Vision 框架：人脸、文字（简体中文、繁体中文、英文）、二维码和条形码。
- 没有第三方依赖。
- 测试图全是自己画的假数据，没有真人的信息。30 张基线图各配一份答案，怎么画、怎么量见 [tools/baseline/FIXTURES.md](tools/baseline/FIXTURES.md)。

## 目录

```
QuickCover/
  App/            入口，三屏共用的状态
  Screens/        选图、编辑、导出
  Editor/         编辑页的清单、撤销、样式、框
  Recognition/    找东西的规则，三种样式的画法
  SelfCheck/      自检页
QuickCoverTests/  测试，30 张基线图和它们的答案
tools/selfcheck/  出自检包的脚本
tools/baseline/   画测试图、量基线的脚本
docs/ios/         简报、设计规格、文案、样机截图
```

## 文档

- [产品简报](docs/ios/brief.md)
- [设计规格](docs/ios/design.md)
- [界面文案](docs/ios/copy.md)
- [基线图的约定](tools/baseline/FIXTURES.md)

---

Made with AirBuild
