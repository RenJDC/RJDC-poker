# RJDC-Poker 人杰地才魔术扑克

基于 [Wombat_Magic_Poker](https://github.com/HuaweiREN/Wombat_Magic_Poker) 修改而来，针对 Android 手机优化，默认使用经典魔术滑动模式。

**原作者**：[HuaweiREN](https://github.com/HuaweiREN) — [Wombat_Magic_Poker](https://github.com/HuaweiREN/Wombat_Magic_Poker)

**修改者**：[人杰地才](https://github.com/RenJDC)

---

## ✨ 功能

### 效果

安装后打开 App，屏幕**完全黑屏**，没有任何按钮或文字——这是设计如此，为了魔术表演的真实感。观众完全看不出手机上有任何异常。

### 操作方式

1. **选点数**：从a到k，以及大小王15个条目，屏幕被分为 3 列 × 5 行共 15 个等大区域，**点击一下**即可根据区域选定点数

   ```
   ┌─────┬─────┬─────┐
   │  A  │  2  │  3  │
   ├─────┼─────┼─────┤
   │  4  │  5  │  6  │
   ├─────┼─────┼─────┤
   │  7  │  8  │  9  │
   ├─────┼─────┼─────┤
   │ 10  │  J  │  Q  │
   ├─────┼─────┼─────┤
   │  K  │ 小王 │ 大王 │
   └─────┴─────┴─────┘
   ```
2. **选花色**：选完点数后，手指在屏幕**任意位置滑动**，确定花色
   - ⬆️ **上滑** = 黑桃 &nbsp;&nbsp; ➡️ **右滑** = 红桃
   - ⬇️ **下滑** = 梅花 &nbsp;&nbsp; ⬅️ **左滑** = 方块
3. 滑动后立即显示对应的扑克牌高清大图
4. **返回待机**：点击扑克牌画面，回到全黑待机状态

### 特殊操作

- **小王/大王**：点击网格底部中间/右边区域直接出牌，无需滑动
- **误触保护**：滑动距离过短（< 8px）时不会触发，需重新滑动

## 📱 下载

APK 在 [Releases](../../releases) 中下载，或自行编译。

## 🛠️ 编译

```bash
flutter pub get
flutter build apk --release
```

> 国内网络可配置镜像：
> ```bash
> export PUB_HOSTED_URL=https://pub.flutter-io.cn
> export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
> ```

## 🔧 与原版差异

- 默认模式改为 `GridSwipeCardSelector`（经典魔术滑动模式）
- 交互改为**两步式**：先点击选点数，再全局滑动选花色
- 方向判断用 `|dx| > |dy|` 绝对值比较，斜滑不再串花色
- 精简依赖，移除语音相关包（`sherpa_onnx`、`flutter_sound`、`permission_handler` 等）
- 移除语音模型资源，APK 从 ~70MB 降至 ~29MB
- 修复切回待机后首次点击被吞的问题

## 📁 项目结构

```
lib/
├── main.dart                  # 入口：初始化 App，管理待机/显示两种状态
├── card_selector.dart         # 抽象接口 CardSelector：所有选牌方式必须实现
├── grid_swipe_selector.dart   # 经典魔术模式：点击选点数 → 全局滑动选花色
└── custom_selector.dart       # 原版其他选择器（未使用，保留参考）

android/app/src/main/
└── AndroidManifest.xml        # 安卓配置：应用名、权限声明

assets/
└── images/                    # 扑克牌图片素材（heitao_A.png, hongtao_5.png 等）

pubspec.yaml                   # 项目配置：依赖、资源声明、版本号
```

## 🙏 致谢

- **原作者** [HuaweiREN](https://github.com/HuaweiREN) 的 [Wombat_Magic_Poker](https://github.com/HuaweiREN/Wombat_Magic_Poker) 项目
- 灵感来源于 Bilibili [**barry巴里里**](https://space.bilibili.com/你的UID) 的视频创意
- 扑克牌素材来自 [GitCode](https://gitcode.com/open-source-toolkit/77d38/)

## 📄 许可证

本项目采用双重许可证：

- **原代码**（Wombat_Magic_Poker）：[MIT 许可证](LICENSE) — Copyright (c) 2026 HuaweiREN
- **修改及新增代码**（人杰地才）：[GNU General Public License v3.0](LICENSE-GPLv3)

使用本项目的修改版本时，请遵守 GPLv3 的开源要求。