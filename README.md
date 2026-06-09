# Agent永动机 MVP

Fast macOS MVP for shielding the desktop while CLI agents keep running in the background.

## MVP Plan

1. Build a Swift/AppKit menu bar app that can show full-screen black overlays on every display.
2. Keep agent work alive by launching `/usr/bin/caffeinate`.
3. Block local mouse input and most shortcut-style keyboard input with `CGEventTap`.
4. Allow password entry on the primary overlay and unlock after local password verification.
5. Keep the command-line app available as a fallback.
6. Keep security-sensitive logic in a tested core module.

## What Works

- Multi-display black privacy overlay.
- Every connected display gets its own overlay window; only the primary display shows the unlock field.
- Primary-screen password box for unlock.
- Primary-screen Claude 小宠物 loading 动画，提示后台任务正在工作。
- Local password record stored at `~/.agent-privacy-lock/password.record`.
- Salted, iterated SHA-256 password digest for the MVP.
- Failed unlock attempt delay after repeated bad passwords.
- Full anti-sleep support via `caffeinate -d -i -m -s`.
- Menu bar client with password setup, task label editing, full anti-sleep, and one-click lock.

## Run

启动中文客户端窗口：

```sh
swift run agent-privacy-lock-client
```

启动后会显示一个控制窗口，同时菜单栏会出现 `永动机`。窗口里可以直接操作：

- 默认解锁密码是 `123456`。
- 如果当前仍使用默认密码，客户端启动时会弹窗提醒，并在窗口中显示醒目提示。
- 点击 `修改默认密码（当前 123456）` 设置新密码；需要输入 `新密码` 和 `确认密码`，客户端不允许继续保存 `123456` 作为新密码。
- `设置解锁密码`
- `任务名称`
- `防休眠策略`：固定为完全防休眠（CPU、磁盘、显示器、系统）
- `启动永动机`
- `权限帮助`

菜单栏里也保留同样的中文操作项；如果关闭窗口，客户端不会退出，可从菜单栏点击 `显示客户端窗口` 重新打开。

启动永动机后，主屏遮罩层会显示 Claude 小宠物 loading 动画；解锁时输入密码并按 Return。

## CLI Fallback

Set or replace the unlock password from Terminal:

```sh
swift run agent-privacy-lock --set-password "change-me-now"
```

Start the privacy lock:

```sh
swift run agent-privacy-lock --task "Claude Code long task" --policy full
```

## macOS Permissions

For stronger input blocking, grant the built app Accessibility and Input Monitoring permissions:

```sh
.build/debug/agent-privacy-lock-client
.build/debug/agent-privacy-lock
```

Then open:

```text
System Settings -> Privacy & Security -> Accessibility
System Settings -> Privacy & Security -> Input Monitoring
```

## Verify

```sh
swift test
swift build
```

## Internal Test Package

生成内部测试用 `.dmg`：

```sh
scripts/package-internal.sh
```

默认版本号当前为 `0.2.0`，构建号为 `2`。发布新版本时可覆盖：

```sh
VERSION=0.2.1 BUILD_NUMBER=3 scripts/package-internal.sh
```

产物位置：

```text
dist/Agent永动机.dmg
```

这是 ad-hoc signed 的内部测试版，没有 Developer ID 签名和 notarization。测试用户第一次打开时可能需要右键选择 `打开`，并且仍需要给 `/Applications/Agent永动机.app` 添加「辅助功能」和「输入监控」权限。

## MVP Limits

- This is not a replacement for FileVault, the macOS lock screen, or physical security.
- It cannot prevent force quit, reboot, shutdown, power loss, or another admin user.
- Touch ID, remote unlock, camera detection, and remote status publishing are future features.
- Bcrypt/Argon2 should replace the MVP digest before treating this as production-grade password storage.
