# 栖屏 · Qiping

栖屏是一款跟着鼠标走的 macOS 浮动导航栏。鼠标停在哪块屏幕，就能从那里切桌面、找窗口、切 App 或开始语音输入。用完点一下，导航栏就收成一只可以拖动的小白猫。

Qiping is a native macOS floating toolbar for switching desktops across displays and triggering common shortcuts with the mouse.

## 功能

- **切桌面**。左右键切换桌面。开启跨屏循环后，鼠标可以留在当前屏，继续切换其他显示器的桌面。
- **找窗口和 App**。上键打开调度中心（Mission Control），App 菜单列出正在运行的应用。
- **输入和编辑**。语音按钮目前适配豆包输入法的右 Command 语音快捷键。回车和删除按钮向当前应用发送相应按键。
- **拖动和收起**。面板跟随鼠标所在屏幕，每块屏幕记住自己的位置。点小白猫收起或展开，两个状态都能拖动。开源版使用仓库中独立绘制的白猫 SVG。

## 从源码构建

需要 macOS 13 或更新版本，以及较新的 Xcode 或 Command Line Tools（需包含 macOS SDK 和 Swift）。应用使用 AppKit，构建无需第三方依赖。

```sh
git clone https://github.com/Desperadolky/qiping.git
cd qiping
./setup.sh
open build/Qiping.app
```

脚本会运行桌面循环检查，并为本机架构生成带临时签名的应用。只运行检查时使用 `./setup.sh --test`。原「鼠标导航栏」公证安装包仍可从原产品站下载，使用独立的应用标识。[原产品站](https://mouse-nav-for-mac.desperado0814.chatgpt.site/)

## 权限与跨屏

- 在「系统设置 → 隐私与安全性 → 辅助功能」允许栖屏发送快捷键并操作跨屏切换所需的系统界面。也可以从栖屏菜单打开对应设置。
- 跨屏循环需要开启「系统设置 → 桌面与程序坞 → 调度中心 → 显示器具有单独的空间」。单屏切换使用系统的 Control + 左右方向键，可在「键盘快捷键 → 调度中心」确认对应快捷键已启用。
- macOS 26 优先直接切换其他显示器上的桌面。较早的 macOS 版本通过调度中心选择目标桌面，可能短暂显示总览。跨屏切换依赖 macOS 未公开的接口，系统更新可能影响这一功能。如遇兼容性问题，可从菜单关闭「跨屏循环」。

## 许可

源码采用 MIT 许可证。上游实现与许可见随附说明。[MIT 许可证](LICENSE) · [第三方署名](THIRD_PARTY_NOTICES.md)
