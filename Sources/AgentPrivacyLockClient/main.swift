import AgentPrivacyLockCore
import AppKit
import Foundation
import Sparkle

@MainActor
private final class RoundedSurfaceView: NSView {
    enum SurfaceStyle {
        case background
        case panel
        case warning
    }

    private let style: SurfaceStyle
    private let cornerRadius: CGFloat

    init(style: SurfaceStyle, cornerRadius: CGFloat = 14) {
        self.style = style
        self.cornerRadius = cornerRadius
        super.init(frame: .zero)
        wantsLayer = true
    }

    override var wantsUpdateLayer: Bool {
        true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateLayer() {
        layer?.cornerRadius = cornerRadius
        layer?.masksToBounds = true
        layer?.borderWidth = style == .panel ? 1 : 0
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.42).cgColor

        switch style {
        case .background:
            layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        case .panel:
            layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        case .warning:
            layer?.backgroundColor = NSColor.systemOrange.withAlphaComponent(0.12).cgColor
        }
    }
}

@MainActor
final class ClientAppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let store = PasswordStore()
    private var statusItem: NSStatusItem?
    private var controller: PrivacyLockController?
    private var window: NSWindow?
    private var statusLabel = NSTextField(labelWithString: ClientCopy.readyStatus)
    private var defaultPasswordWarningLabel = NSTextField(labelWithString: "")
    private var taskField = NSTextField(string: "后台 AI 任务")
    private var lockButton = NSButton()
    private var passwordButton = NSButton()
    private var permissionButton = NSButton()
    private var updateButton = NSButton()
    private var versionLabel = NSTextField(labelWithString: "")
    private var taskLabel = "后台 AI 任务"
    private var policy: CaffeinatePolicy = .full

    // MARK: - Sparkle Auto-Updater
    private var updaterController: SPUStandardUpdaterController?

    // MARK: - Hotkey
    private let hotKeyRegistrar = GlobalHotKeyRegistrar()
    private var hotKeyConfig: HotKeyConfig = .default
    private var hotKeyDisplayLabel = NSTextField(labelWithString: "")

    private static let hotKeyDefaultsKey = "com.agentprivacylock.hotkey"

    private var versionDisplayText: String {
        ClientVersionInfo.displayName(
            shortVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            buildNumber: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        )
    }

    private func loadHotKeyConfig() -> HotKeyConfig {
        guard let data = UserDefaults.standard.data(forKey: Self.hotKeyDefaultsKey),
              let config = try? JSONDecoder().decode(HotKeyConfig.self, from: data) else {
            return .default
        }
        return config
    }

    private func saveHotKeyConfig(_ config: HotKeyConfig) {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: Self.hotKeyDefaultsKey)
        }
    }

    private func registerHotKey() {
        hotKeyRegistrar.register(hotKeyConfig) { [weak self] in
            self?.enablePrivacyLock()
        }
    }

    @objc private func editHotKey() {
        let alert = NSAlert()
        alert.messageText = "设置快捷键"
        alert.informativeText = "按下新的快捷键组合（需包含修饰键），然后点击【保存】。"
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")

        let saveButton = alert.buttons[0]
        saveButton.isEnabled = false

        let recorderLabel = NSTextField(labelWithString: "等待按键...")
        recorderLabel.alignment = .center
        recorderLabel.font = .monospacedSystemFont(ofSize: 20, weight: .medium)
        recorderLabel.frame = NSRect(x: 0, y: 0, width: 240, height: 36)
        alert.accessoryView = recorderLabel

        var captured: HotKeyConfig?
        let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { return event } // allow Escape to dismiss
            let flags = event.modifierFlags.intersection([.command, .control, .option, .shift])
            guard !flags.isEmpty else { return event }
            let config = HotKeyConfig(keyCode: event.keyCode, modifierFlags: flags.rawValue)
            captured = config
            recorderLabel.stringValue = config.displayString
            saveButton.isEnabled = true
            return nil
        }

        let response = alert.runModal()
        if let monitor { NSEvent.removeMonitor(monitor) }

        guard response == .alertFirstButtonReturn, let config = captured else { return }
        hotKeyConfig = config
        saveHotKeyConfig(config)
        registerHotKey()
        hotKeyDisplayLabel.stringValue = config.displayString
    }

    // MARK: - App lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        hotKeyConfig = loadHotKeyConfig()
        createDefaultPasswordIfNeeded()
        createStatusItem()
        createMainWindow()
        rebuildMenu()
        showMainWindow()
        remindIfUsingDefaultPassword()
        registerHotKey()
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    private var isLocked: Bool {
        controller != nil
    }

    private func createStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "永动机"
        statusItem = item
    }

    private func createMainWindow() {
        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: ClientAppearancePolicy.windowWidth,
                height: ClientAppearancePolicy.windowHeight
            ),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = ClientCopy.appName
        window.titlebarAppearsTransparent = true
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.contentView = makeMainView()
        window.center()
        self.window = window
    }

    private func makeMainView() -> NSView {
        let root = RoundedSurfaceView(style: .background, cornerRadius: 0)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 18
        stack.edgeInsets = NSEdgeInsets(top: 30, left: 32, bottom: 28, right: 32)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.setContentHuggingPriority(.defaultLow, for: .horizontal)

        stack.addArrangedSubview(makeHeader())

        let warningBanner = makeDefaultPasswordWarningBanner()
        stack.addArrangedSubview(warningBanner)

        stack.addArrangedSubview(makeSettingsPanel())

        lockButton = makePrimaryButton(title: ClientCopy.enableLock, action: #selector(enablePrivacyLock))
        stack.addArrangedSubview(lockButton)

        let footnote = label(
            "跟随系统明暗主题。锁定后可在主屏输入密码并按 Return 解锁。",
            size: 12,
            color: .secondaryLabelColor
        )
        footnote.alignment = .center
        footnote.maximumNumberOfLines = 2
        stack.addArrangedSubview(footnote)

        versionLabel = label(versionDisplayText, size: 12, color: .tertiaryLabelColor)
        versionLabel.alignment = .center
        stack.addArrangedSubview(versionLabel)

        root.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            stack.topAnchor.constraint(equalTo: root.topAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor),
            warningBanner.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -64),
            lockButton.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -64),
            lockButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        return root
    }

    private func makeHeader() -> NSView {
        let container = NSStackView()
        container.orientation = .horizontal
        container.alignment = .top
        container.spacing = 16
        container.translatesAutoresizingMaskIntoConstraints = false

        let copyStack = NSStackView()
        copyStack.orientation = .vertical
        copyStack.alignment = .leading
        copyStack.spacing = 7

        let eyebrow = label("macOS AI Agent privacy lock", size: 11, weight: .medium, color: .tertiaryLabelColor)
        eyebrow.maximumNumberOfLines = 1
        let title = label(ClientCopy.appName, size: 27, weight: .semibold, color: .labelColor)
        let subtitle = label("离开工位时遮住屏幕、拦截误操作，同时让后台任务继续运行。", size: 13, color: .secondaryLabelColor)
        subtitle.maximumNumberOfLines = 2

        copyStack.addArrangedSubview(eyebrow)
        copyStack.addArrangedSubview(title)
        copyStack.addArrangedSubview(subtitle)

        statusLabel = makeStatusPill(text: ClientCopy.readyStatus)

        container.addArrangedSubview(copyStack)
        container.addArrangedSubview(statusLabel)
        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: 496),
            statusLabel.widthAnchor.constraint(equalToConstant: 104),
            statusLabel.heightAnchor.constraint(equalToConstant: 28)
        ])
        return container
    }

    private func makeDefaultPasswordWarningBanner() -> NSView {
        let banner = RoundedSurfaceView(style: .warning, cornerRadius: 12)
        banner.translatesAutoresizingMaskIntoConstraints = false

        defaultPasswordWarningLabel.font = .systemFont(ofSize: 13, weight: .medium)
        defaultPasswordWarningLabel.textColor = NSColor.systemOrange
        defaultPasswordWarningLabel.maximumNumberOfLines = 2
        defaultPasswordWarningLabel.stringValue = defaultPasswordWarningText
        defaultPasswordWarningLabel.translatesAutoresizingMaskIntoConstraints = false

        banner.addSubview(defaultPasswordWarningLabel)
        NSLayoutConstraint.activate([
            banner.heightAnchor.constraint(greaterThanOrEqualToConstant: 48),
            defaultPasswordWarningLabel.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 16),
            defaultPasswordWarningLabel.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -16),
            defaultPasswordWarningLabel.centerYAnchor.constraint(equalTo: banner.centerYAnchor)
        ])
        return banner
    }

    private func makeSettingsPanel() -> NSView {
        let panel = RoundedSurfaceView(style: .panel, cornerRadius: 16)
        panel.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        stack.translatesAutoresizingMaskIntoConstraints = false

        stack.addArrangedSubview(formRow(label: "任务名称", control: taskField))

        let policyLabel = label("完全防休眠（CPU、磁盘、显示器、系统）", size: 13, color: .secondaryLabelColor)
        stack.addArrangedSubview(formRow(label: "防休眠策略", control: policyLabel))
        stack.addArrangedSubview(makeHotKeyRow())
        stack.addArrangedSubview(makeSecondaryActionsRow())

        panel.addSubview(stack)
        NSLayoutConstraint.activate([
            panel.widthAnchor.constraint(equalToConstant: 496),
            stack.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            stack.topAnchor.constraint(equalTo: panel.topAnchor),
            stack.bottomAnchor.constraint(equalTo: panel.bottomAnchor)
        ])
        return panel
    }

    private func makeHotKeyRow() -> NSView {
        let sectionLabel = label("快捷键", size: 13, weight: .medium, color: .secondaryLabelColor)

        hotKeyDisplayLabel.stringValue = hotKeyConfig.displayString
        hotKeyDisplayLabel.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        hotKeyDisplayLabel.textColor = .labelColor

        let editButton = NSButton(title: "修改", target: self, action: #selector(editHotKey))
        editButton.bezelStyle = .rounded
        editButton.controlSize = .small

        let controlRow = NSStackView()
        controlRow.orientation = .horizontal
        controlRow.spacing = 8
        controlRow.alignment = .centerY
        controlRow.addArrangedSubview(hotKeyDisplayLabel)
        controlRow.addArrangedSubview(editButton)
        controlRow.translatesAutoresizingMaskIntoConstraints = false
        controlRow.widthAnchor.constraint(equalToConstant: 460).isActive = true

        let container = NSStackView()
        container.orientation = .vertical
        container.spacing = 6
        container.alignment = .leading
        container.addArrangedSubview(sectionLabel)
        container.addArrangedSubview(controlRow)
        return container
    }

    private func makeSecondaryActionsRow() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .centerY

        passwordButton = makeSecondaryButton(title: passwordButtonTitle, action: #selector(changePassword))
        permissionButton = makeSecondaryButton(title: "权限帮助", action: #selector(showPermissionHelp))
        updateButton = makeSecondaryButton(title: "检查更新", action: #selector(checkForUpdates(_:)))

        row.addArrangedSubview(passwordButton)
        row.addArrangedSubview(permissionButton)
        row.addArrangedSubview(updateButton)
        return row
    }

    private func formRow(label: String, control: NSView) -> NSStackView {
        let row = NSStackView()
        row.orientation = .vertical
        row.spacing = 6
        row.alignment = .leading

        let text = self.label(label, size: 13, weight: .medium, color: .secondaryLabelColor)
        row.addArrangedSubview(text)

        control.translatesAutoresizingMaskIntoConstraints = false
        control.widthAnchor.constraint(equalToConstant: 460).isActive = true
        row.addArrangedSubview(control)
        return row
    }

    private func label(
        _ text: String,
        size: CGFloat,
        weight: NSFont.Weight = .regular,
        color: NSColor
    ) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .systemFont(ofSize: size, weight: weight)
        field.textColor = color
        field.lineBreakMode = .byWordWrapping
        return field
    }

    private func makeStatusPill(text: String) -> NSTextField {
        let field = label(text.replacingOccurrences(of: "状态：", with: ""), size: 12, weight: .medium, color: .secondaryLabelColor)
        field.alignment = .center
        field.wantsLayer = true
        field.layer?.cornerRadius = 14
        field.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        field.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.5).cgColor
        field.layer?.borderWidth = 1
        return field
    }

    private func makePrimaryButton(title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.controlSize = .large
        button.font = .systemFont(ofSize: 16, weight: .semibold)
        return button
    }

    private func makeSecondaryButton(title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.controlSize = .regular
        return button
    }

    private var passwordButtonTitle: String {
        if usesDefaultPassword {
            return "修改默认密码（当前 123456）"
        }
        return store.hasPassword ? "修改解锁密码" : "设置解锁密码"
    }

    private var defaultPasswordWarningText: String {
        usesDefaultPassword
            ? "\(ClientCopy.defaultPasswordWarningTitle)。\(ClientCopy.defaultPasswordWarningBody)"
            : ""
    }

    private var usesDefaultPassword: Bool {
        (try? store.isUsingDefaultPassword()) == true
    }

    private func createDefaultPasswordIfNeeded() {
        do {
            try store.ensurePasswordExists()
        } catch {
            showError("无法初始化默认密码", detail: String(describing: error))
        }
    }

    private func remindIfUsingDefaultPassword() {
        guard (try? store.isUsingDefaultPassword()) == true else {
            return
        }

        let alert = NSAlert()
        alert.messageText = ClientCopy.defaultPasswordWarningTitle
        alert.informativeText = ClientCopy.defaultPasswordWarningBody
        alert.alertStyle = .warning
        alert.addButton(withTitle: "立即修改密码")
        alert.addButton(withTitle: "稍后")

        if alert.runModal() == .alertFirstButtonReturn {
            _ = setPassword(title: "修改解锁密码")
        }
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: isLocked ? ClientCopy.lockedStatus : ClientCopy.readyStatus, action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        let showItem = NSMenuItem(title: "显示客户端窗口", action: #selector(showMainWindow), keyEquivalent: "o")
        showItem.target = self
        menu.addItem(showItem)

        let aboutItem = NSMenuItem(title: "关于 \(ClientCopy.appName)", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        let enableItem = NSMenuItem(title: ClientCopy.enableLock, action: #selector(enablePrivacyLock), keyEquivalent: "l")
        enableItem.target = self
        enableItem.isEnabled = !isLocked
        menu.addItem(enableItem)

        let passwordItem = NSMenuItem(title: passwordButtonTitle, action: #selector(changePassword), keyEquivalent: "p")
        passwordItem.target = self
        passwordItem.isEnabled = !isLocked
        menu.addItem(passwordItem)

        let taskItem = NSMenuItem(title: "\(ClientCopy.taskLabelPrefix)\(taskLabel)", action: #selector(editTaskLabel), keyEquivalent: "t")
        taskItem.target = self
        taskItem.isEnabled = !isLocked
        menu.addItem(taskItem)

        menu.addItem(NSMenuItem(title: "防休眠：完全防休眠", action: nil, keyEquivalent: ""))

        menu.addItem(NSMenuItem.separator())

        let updateItem = NSMenuItem(title: "检查更新...", action: #selector(checkForUpdates(_:)), keyEquivalent: "u")
        updateItem.target = self
        menu.addItem(updateItem)

        let permissionItem = NSMenuItem(title: ClientCopy.permissionHelp, action: #selector(showPermissionHelp), keyEquivalent: "")
        permissionItem.target = self
        menu.addItem(permissionItem)

        let quitItem = NSMenuItem(title: ClientCopy.quit, action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        quitItem.isEnabled = !isLocked
        menu.addItem(quitItem)

        statusItem?.button?.title = isLocked ? "永动机：运行中" : "永动机"
        statusItem?.menu = menu
        refreshWindowState()
    }

    private func refreshWindowState() {
        statusLabel.stringValue = (isLocked ? ClientCopy.lockedStatus : ClientCopy.readyStatus)
            .replacingOccurrences(of: "状态：", with: "")
        statusLabel.textColor = isLocked ? .systemGreen : .secondaryLabelColor
        versionLabel.stringValue = versionDisplayText
        defaultPasswordWarningLabel.stringValue = defaultPasswordWarningText
        defaultPasswordWarningLabel.superview?.isHidden = defaultPasswordWarningLabel.stringValue.isEmpty
        passwordButton.title = passwordButtonTitle
        lockButton.title = isLocked ? "永动机运行中" : ClientCopy.enableLock
        lockButton.isEnabled = !isLocked
        passwordButton.isEnabled = !isLocked
        permissionButton.isEnabled = !isLocked
        updateButton.isEnabled = !isLocked
        taskField.isEnabled = !isLocked
    }

    @objc private func showMainWindow() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func enablePrivacyLock() {
        guard !isLocked else {
            return
        }

        do {
            taskLabel = normalizedTaskLabel()
            try store.ensurePasswordExists()

            let configuration = LockConfiguration(
                passwordRecord: try store.load(),
                taskLabel: taskLabel,
                caffeinatePolicy: policy
            )

            let controller = PrivacyLockController(configuration: configuration, showsStatusMenu: false) { [weak self] in
                self?.controller = nil
                self?.rebuildMenu()
                self?.showMainWindow()
            }
            self.controller = controller
            rebuildMenu()
            controller.start()
        } catch {
            showError("无法启动永动机", detail: String(describing: error))
        }
    }

    @objc private func changePassword() {
        _ = setPassword(title: store.hasPassword ? "修改解锁密码" : "设置解锁密码")
    }

    @objc private func editTaskLabel() {
        showMainWindow()
        taskField.becomeFirstResponder()
    }

    @objc private func showPermissionHelp() {
        let alert = NSAlert()
        alert.messageText = "macOS 权限"
        alert.informativeText = """
        为了更可靠地拦截键盘和鼠标，请给客户端添加以下权限：

        系统设置 -> 隐私与安全性 -> 辅助功能
        系统设置 -> 隐私与安全性 -> 输入监控
        """
        alert.addButton(withTitle: "知道了")
        alert.runModal()
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = ClientCopy.appName
        alert.informativeText = """
        \(versionDisplayText)

        让 AI 继续干活，让屏幕保持沉默。

        可通过菜单栏“检查更新...”获取新版本。
        """
        alert.addButton(withTitle: "检查更新")
        alert.addButton(withTitle: "知道了")

        if alert.runModal() == .alertFirstButtonReturn {
            updaterController?.checkForUpdates(self)
        }
    }

    @objc private func checkForUpdates(_ sender: Any) {
        updaterController?.checkForUpdates(sender)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func normalizedTaskLabel() -> String {
        let value = taskField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "后台 AI 任务" : value
    }

    private func setPassword(title: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = "输入两次新密码，用于解锁遮罩层。"
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")

        let stack = NSStackView(frame: NSRect(x: 0, y: 0, width: 320, height: 64))
        stack.orientation = .vertical
        stack.spacing = 8

        let passwordField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        passwordField.placeholderString = "新密码"
        let confirmationField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        confirmationField.placeholderString = "确认密码"

        stack.addArrangedSubview(passwordField)
        stack.addArrangedSubview(confirmationField)
        alert.accessoryView = stack

        guard alert.runModal() == .alertFirstButtonReturn else {
            return false
        }

        let password = passwordField.stringValue
        let confirmation = confirmationField.stringValue
        switch PasswordChangeValidator.validate(password: password, confirmation: confirmation) {
        case .valid:
            break
        case .empty:
            showError("密码不能为空", detail: "请设置一个解锁密码后再启动永动机。")
            return false
        case .defaultPassword:
            showError("请修改默认密码", detail: "默认密码 123456 容易被猜到，请设置一个不同的新密码。")
            return false
        case .mismatch:
            showError("两次密码不一致", detail: "请重新输入新密码和确认密码。")
            return false
        }

        do {
            try store.saveNewPassword(password)
            rebuildMenu()
            return true
        } catch {
            showError("无法保存密码", detail: String(describing: error))
            return false
        }
    }

    private func showError(_ message: String, detail: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = detail
        alert.alertStyle = .warning
        alert.addButton(withTitle: "知道了")
        alert.runModal()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
}

let app = NSApplication.shared
let delegate = ClientAppDelegate()
app.delegate = delegate
app.run()
