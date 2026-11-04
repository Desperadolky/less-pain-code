# 栖屏 · Qiping

用鼠标切换 Mac 的桌面和 App。栖屏是一条跟着鼠标走的浮动导航栏，能从当前屏操作其他显示器上的桌面，也能触发语音输入、回车和删除。用完点一下白猫，面板就会收起来。

Qiping is a native macOS toolbar for switching desktops across displays and triggering common shortcuts with the mouse.

[看界面](#界面预览) · [从源码构建](#从源码构建) · [提问题](https://github.com/Desperadolky/qiping/issues)

## 界面预览

| 展开的导航栏 | 收起后 |
| :---: | :---: |
| <a href="docs/screenshots/qiping-expanded.png"><img src="docs/screenshots/qiping-expanded.png" width="162" alt="栖屏展开后的导航栏，显示 B 屏第 2 个桌面，下面是桌面切换、语音输入、回车、删除和 App 按钮"></a> | <a href="docs/screenshots/qiping-compact.png"><img src="docs/screenshots/qiping-compact.png" width="96" alt="栖屏收起后只保留可拖动的小白猫入口"></a> |

界面由开源版的 AppKit 组件渲染。「B 屏 · 2/3」为示例。左右箭头切换桌面，上箭头打开调度中心。点白猫展开或收起，两个状态都可拖动。

## 功能

- **切桌面**。开启跨屏循环后，鼠标可留在当前屏，继续切换其他显示器的桌面。
- **找窗口和 App**。用调度中心查看桌面与窗口，或从 App 菜单选中已打开的应用。
- **输入和编辑**。语音按钮目前适配豆包输入法的右 Command 快捷键。回车和删除作用于当前应用。
- **放在顺手的位置**。面板跟随鼠标所在屏，每块屏幕分别记住拖放位置。

## 从源码构建

需要 macOS 13 或更新版本，以及较新的 Xcode 或 Command Line Tools（包含 macOS SDK 和 Swift）。构建无需第三方依赖，已在 Apple 芯片 Mac 上验证。

```sh
git clone https://github.com/Desperadolky/qiping.git
cd qiping
./setup.sh
open build/Qiping.app
```

`./setup.sh` 会运行桌面路由测试，并为本机架构构建带本地临时签名的 `build/Qiping.app`。只跑测试可执行 `./setup.sh --test`。

[原「鼠标导航栏」公证安装包](https://mouse-nav-for-mac.desperado0814.chatgpt.site/)使用自己的应用标识，可与源码构建的栖屏区分。

## 权限与跨屏

1. 打开栖屏后，将鼠标移到要操作的屏幕。导航栏会出现在这块屏幕。
2. 在「系统设置 → 隐私与安全性 → 辅助功能」授权栖屏发送快捷键。单屏切换使用系统的 Control + 左右方向键，可在「键盘快捷键 → 调度中心」检查设置。
3. 点击左右箭头，确认当前屏切到了相邻桌面。
4. 若要跨屏循环，在「系统设置 → 桌面与程序坞 → 调度中心」开启「显示器具有单独的空间」，并确认栖屏菜单中的「跨屏循环」已开启。继续点左右箭头越过当前屏的桌面边界，栏顶会显示目标屏幕和桌面序号。若该桌面尚未显示，目标屏会切到该桌面。

macOS 26 优先直接切换其他显示器上的桌面。较早系统通过调度中心切换，可能短暂显示总览。跨屏切换依赖 macOS 未公开的接口，系统更新可能影响兼容性。遇到问题可从菜单关闭跨屏循环。

## 许可

源码采用 [MIT 许可证](LICENSE)。上游实现和版权声明见[第三方署名](THIRD_PARTY_NOTICES.md)。反馈和贡献方式见[贡献指南](CONTRIBUTING.md)。
