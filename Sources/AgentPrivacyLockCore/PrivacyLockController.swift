import AppKit
import ApplicationServices
import Foundation

@MainActor
public final class PrivacyLockController: NSObject {
    private let configuration: LockConfiguration
    private let showsStatusMenu: Bool
    private let onUnlock: @MainActor () -> Void
    private let status: LockStatus
    private var windows: [NSWindow] = []
    private var statusLabels: [NSTextField] = []
    private weak var passwordField: NSSecureTextField?
    private var unlockFeedback: InlineUnlockFeedback?
    private var limiter = AttemptLimiter()
    private var caffeinateProcess: Process?
    private var inputInterceptor: InputInterceptor?
    private var statusTimer: Timer?
    private var statusItem: NSStatusItem?
    private var activeSpaceObserver: NSObjectProtocol?
    private var previousPresentationOptions: NSApplication.PresentationOptions?

    public init(
        configuration: LockConfiguration,
        showsStatusMenu: Bool = true,
        onUnlock: @escaping @MainActor () -> Void
    ) {
        self.configuration = configuration
        self.showsStatusMenu = showsStatusMenu
        self.onUnlock = onUnlock
        self.status = LockStatus(taskLabel: configuration.taskLabel)
    }

    public func start() {
        if showsStatusMenu {
            createStatusMenu()
        }
        startCaffeinate()
        startInputInterceptor()
        createOverlayWindows()
        NSApp.activate(ignoringOtherApps: true)
        enablePresentationShield()
        observeActiveSpaceChanges()
        statusTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshStatus()
            }
        }
    }

    private func createStatusMenu() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.title = "永动机"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Agent永动机已启动", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Unlock on overlay with password", action: nil, keyEquivalent: ""))
        item.menu = menu
        statusItem = item
    }

    private func createOverlayWindows() {
        let screens = NSScreen.screens
        let plans = OverlayWindowPlanner.plans(
            screenIDs: screens.map(ObjectIdentifier.init),
            mainScreenID: NSScreen.main.map(ObjectIdentifier.init)
        )

        for (screen, plan) in zip(screens, plans) {
            let window = PrivacyOverlayWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.level = NSWindow.Level(rawValue: max(NSWindow.Level.screenSaver.rawValue, NSWindow.Level.mainMenu.rawValue + 1))
            window.collectionBehavior = LockShieldingPolicy.overlayCollectionBehavior
            window.isReleasedWhenClosed = false
            window.ignoresMouseEvents = false
            window.setFrame(screen.frame, display: true)
            window.contentView = makeOverlayView(isPrimary: plan.showsUnlockControls)
            if plan.showsUnlockControls {
                window.makeKeyAndOrderFront(nil)
                window.makeFirstResponder(passwordField)
            } else {
                window.orderFrontRegardless()
            }
            windows.append(window)
        }
    }

    private func makeOverlayView(isPrimary: Bool) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: status.displayLines().joined(separator: "\n"))
        label.alignment = .center
        label.font = .monospacedSystemFont(ofSize: 18, weight: .regular)
        label.textColor = .white
        label.maximumNumberOfLines = 4

        if isPrimary {
            let petView = ClaudePetLoadingView(frame: NSRect(x: 0, y: 0, width: 300, height: 190))
            petView.translatesAutoresizingMaskIntoConstraints = false
            petView.widthAnchor.constraint(equalToConstant: 300).isActive = true
            petView.heightAnchor.constraint(equalToConstant: 190).isActive = true
            stack.addArrangedSubview(petView)
        }

        statusLabels.append(label)
        stack.addArrangedSubview(label)

        if isPrimary {
            let passwordField = NSSecureTextField()
            passwordField.placeholderString = "解锁密码"
            passwordField.font = .systemFont(ofSize: 18)
            passwordField.controlSize = .large
            passwordField.alignment = .center
            passwordField.target = self
            passwordField.action = #selector(submitPassword(_:))
            passwordField.translatesAutoresizingMaskIntoConstraints = false
            passwordField.widthAnchor.constraint(equalToConstant: 320).isActive = true
            self.passwordField = passwordField
            stack.addArrangedSubview(passwordField)

            let messageLabel = NSTextField(labelWithString: "")
            messageLabel.alignment = .center
            messageLabel.font = .systemFont(ofSize: 13, weight: .medium)
            messageLabel.textColor = .systemYellow
            messageLabel.maximumNumberOfLines = 2
            messageLabel.isHidden = true
            messageLabel.translatesAutoresizingMaskIntoConstraints = false
            messageLabel.widthAnchor.constraint(equalToConstant: 360).isActive = true
            unlockFeedback = InlineUnlockFeedback(passwordField: passwordField, messageLabel: messageLabel)
            stack.addArrangedSubview(messageLabel)

            let hint = NSTextField(labelWithString: "按 Return 解锁")
            hint.textColor = .secondaryLabelColor
            hint.font = .systemFont(ofSize: 13)
            stack.addArrangedSubview(hint)
        }

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        return view
    }

    @objc private func submitPassword(_ sender: NSSecureTextField) {
        let now = Date()
        let allowedAt = limiter.nextAllowedAttempt(at: now)
        guard allowedAt <= now else {
            unlockFeedback?.show("错误次数过多，请 \(Int(allowedAt.timeIntervalSince(now))) 秒后再试。")
            return
        }

        if configuration.passwordRecord.verify(sender.stringValue) {
            limiter.recordSuccess()
            unlockFeedback?.clear()
            unlock()
        } else {
            limiter.recordFailure(at: now)
            unlockFeedback?.show("密码错误，请重新输入。")
        }
    }

    private func refreshStatus() {
        let text = status.displayLines().joined(separator: "\n")
        statusLabels.forEach { $0.stringValue = text }
    }

    private func enablePresentationShield() {
        previousPresentationOptions = NSApp.presentationOptions
        NSApp.presentationOptions = previousPresentationOptions?.union(LockShieldingPolicy.presentationOptions)
            ?? LockShieldingPolicy.presentationOptions
    }

    private func restorePresentationOptions() {
        guard let previousPresentationOptions else {
            NSApp.presentationOptions = []
            return
        }

        NSApp.presentationOptions = previousPresentationOptions
        self.previousPresentationOptions = nil
    }

    private func observeActiveSpaceChanges() {
        activeSpaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.reassertOverlayWindows()
            }
        }
    }

    private func stopObservingActiveSpaceChanges() {
        if let activeSpaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activeSpaceObserver)
        }
        activeSpaceObserver = nil
    }

    private func reassertOverlayWindows() {
        NSApp.activate(ignoringOtherApps: true)
        for window in windows {
            window.level = NSWindow.Level(rawValue: max(NSWindow.Level.screenSaver.rawValue, NSWindow.Level.mainMenu.rawValue + 1))
            window.collectionBehavior = LockShieldingPolicy.overlayCollectionBehavior
            window.orderFrontRegardless()
        }
        if let passwordField, let window = passwordField.window {
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(passwordField)
        }
    }

    private func startCaffeinate() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        process.arguments = configuration.caffeinatePolicy.arguments
        do {
            try process.run()
            caffeinateProcess = process
        } catch {
            fputs("Warning: caffeinate failed to start: \(error)\n", stderr)
        }
    }

    private func startInputInterceptor() {
        let interceptor = InputInterceptor()
        if interceptor.start() {
            inputInterceptor = interceptor
        } else {
            fputs("Warning: input interception unavailable. Grant Accessibility/Input Monitoring permission for stronger locking.\n", stderr)
        }
    }

    private func unlock() {
        statusTimer?.invalidate()
        stopObservingActiveSpaceChanges()
        restorePresentationOptions()
        inputInterceptor?.stop()
        caffeinateProcess?.terminate()
        windows.forEach { $0.close() }
        statusItem = nil
        windows.removeAll()
        statusLabels.removeAll()
        unlockFeedback = nil
        onUnlock()
    }
}
