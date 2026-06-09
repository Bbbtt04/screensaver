import Foundation
import AppKit
import Testing
@testable import AgentPrivacyLockCore

@Test func passwordRecordVerifiesCorrectPasswordOnly() throws {
    let record = try PasswordRecord.create(password: "leave-my-agent-alone", salt: "fixed-salt")

    #expect(record.verify("leave-my-agent-alone"))
    #expect(!record.verify("wrong-password"))
    #expect(!(try record.encoded()).contains("leave-my-agent-alone"))
}

@Test func passwordStorePersistsPasswordRecordWithoutPlaintext() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("agent-privacy-lock-tests-\(UUID().uuidString)", isDirectory: true)
    let store = PasswordStore(directory: directory)

    try store.saveNewPassword("client-secret")
    let loaded = try store.load()

    #expect(loaded.verify("client-secret"))
    #expect(!loaded.verify("wrong"))
    #expect(!(try String(contentsOf: store.passwordFile, encoding: .utf8)).contains("client-secret"))
}

@Test func passwordStoreCanCreateAndDetectDefaultPassword() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("agent-privacy-lock-default-tests-\(UUID().uuidString)", isDirectory: true)
    let store = PasswordStore(directory: directory)

    let record = try store.ensurePasswordExists()

    #expect(PasswordStore.defaultUnlockPassword == "123456")
    #expect(record.verify("123456"))
    #expect(try store.isUsingDefaultPassword())

    try store.saveNewPassword("changed-password")
    #expect(try !store.isUsingDefaultPassword())
}

@Test func passwordChangeValidatorRequiresConfirmedNonDefaultPassword() {
    #expect(PasswordChangeValidator.validate(password: "", confirmation: "") == .empty)
    #expect(PasswordChangeValidator.validate(password: "123456", confirmation: "123456") == .defaultPassword)
    #expect(PasswordChangeValidator.validate(password: "new-pass", confirmation: "typo") == .mismatch)
    #expect(PasswordChangeValidator.validate(password: "new-pass", confirmation: "new-pass") == .valid)
}

@Test func attemptLimiterDelaysAfterConfiguredFailures() {
    var limiter = AttemptLimiter(maxFailuresBeforeDelay: 3, delaySeconds: 30)
    let start = Date(timeIntervalSince1970: 1_000)

    #expect(limiter.nextAllowedAttempt(at: start) == start)

    limiter.recordFailure(at: start)
    limiter.recordFailure(at: start)
    #expect(limiter.nextAllowedAttempt(at: start) == start)

    limiter.recordFailure(at: start)
    #expect(limiter.nextAllowedAttempt(at: start) == start.addingTimeInterval(30))
}

@Test func successfulUnlockResetsAttemptLimiter() {
    var limiter = AttemptLimiter(maxFailuresBeforeDelay: 1, delaySeconds: 10)
    let start = Date(timeIntervalSince1970: 2_000)

    limiter.recordFailure(at: start)
    #expect(limiter.nextAllowedAttempt(at: start) == start.addingTimeInterval(10))

    limiter.recordSuccess()
    #expect(limiter.nextAllowedAttempt(at: start) == start)
}

@Test func caffeinatePolicyBuildsExpectedArguments() {
    #expect(CaffeinatePolicy.allCases == [.full])
    #expect(CaffeinatePolicy.full.arguments == ["-d", "-i", "-m", "-s"])
}

@Test func lockStatusHidesSensitiveDetails() {
    let status = LockStatus(startedAt: Date(timeIntervalSince1970: 0), taskLabel: "Claude Code long task")

    #expect(status.displayLines(now: Date(timeIntervalSince1970: 65)) == [
        "Agent永动机",
        "任务：Claude Code long task",
        "已锁定：00:01:05"
    ])
}

@Test func clientCopyUsesChineseLabels() {
    #expect(ClientCopy.appName == "Agent永动机")
    #expect(ClientCopy.readyStatus == "状态：待启动")
    #expect(ClientCopy.lockedStatus == "状态：永动运行中")
    #expect(ClientCopy.enableLock == "启动永动机")
    #expect(ClientCopy.setPassword == "设置解锁密码...")
    #expect(ClientCopy.changePassword == "修改解锁密码...")
    #expect(ClientCopy.taskLabelPrefix == "任务名称：")
    #expect(ClientCopy.caffeinatePolicy == "防休眠策略")
    #expect(ClientCopy.permissionHelp == "权限帮助...")
    #expect(ClientCopy.quit == "退出")
    #expect(ClientCopy.defaultPasswordWarningTitle == "当前使用默认密码 123456")
    #expect(ClientCopy.defaultPasswordWarningBody == "请点击“修改默认密码（当前 123456）”设置新密码，避免他人直接解锁。")
}

@Test func clientAppearanceFollowsSystemThemeForMVP() {
    #expect(ClientAppearancePolicy.themeMode == .followSystem)
    #expect(ClientAppearancePolicy.windowWidth == 560)
    #expect(ClientAppearancePolicy.windowHeight == 520)
}

@Test func clientVersionInfoFormatsPackagedAndDevelopmentVersions() {
    #expect(ClientVersionInfo.displayName(shortVersion: "0.2.0", buildNumber: "2") == "版本 0.2.0 (2)")
    #expect(ClientVersionInfo.displayName(shortVersion: nil, buildNumber: nil) == "版本 开发版")
    #expect(ClientVersionInfo.displayName(shortVersion: "  ", buildNumber: " ") == "版本 开发版")
}

@Test func petLoadingFrameAnimatesWorkState() {
    let first = PetLoadingFrame(elapsed: 0)
    let second = PetLoadingFrame(elapsed: 0.25)
    let later = PetLoadingFrame(elapsed: 1.0)

    #expect(first.dotCount == 1)
    #expect(second.dotCount == 2)
    #expect(later.dotCount == 1)
    #expect(first.pawOffset != second.pawOffset)
    #expect(first.statusText == "Claude 小宠物正在干活.")
    #expect(second.statusText == "Claude 小宠物正在干活..")
}

@MainActor
@Test func privacyOverlayWindowCanAcceptPasswordFocus() {
    let window = PrivacyOverlayWindow(
        contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )

    #expect(window.canBecomeKey)
    #expect(window.canBecomeMain)
}

@Test func overlayPlannerCreatesWindowForEveryScreen() {
    let plans = OverlayWindowPlanner.plans(screenIDs: [10, 20, 30], mainScreenID: 20)

    #expect(plans.map(\.screenID) == [10, 20, 30])
    #expect(plans.filter(\.isPrimary).map(\.screenID) == [20])
    #expect(plans.filter(\.showsUnlockControls).map(\.screenID) == [20])
}

@Test func inputInterceptorBlocksTrackpadSystemGestures() {
    let rawTypes = Set(InputInterceptor.interceptedEventTypes.map { Int($0.rawValue) })

    #expect(rawTypes.contains(Int(NSEvent.EventType.gesture.rawValue)))
    #expect(rawTypes.contains(Int(NSEvent.EventType.magnify.rawValue)))
    #expect(rawTypes.contains(Int(NSEvent.EventType.swipe.rawValue)))
    #expect(rawTypes.contains(Int(NSEvent.EventType.rotate.rawValue)))
}

@Test func lockShieldingPolicyCoversOtherAppsFullScreenSpaces() {
    #expect(LockShieldingPolicy.overlayCollectionBehavior.contains(.canJoinAllSpaces))
    #expect(LockShieldingPolicy.overlayCollectionBehavior.contains(.canJoinAllApplications))
    #expect(LockShieldingPolicy.overlayCollectionBehavior.contains(.fullScreenAuxiliary))
    #expect(LockShieldingPolicy.overlayCollectionBehavior.contains(.ignoresCycle))
}

@Test func lockShieldingPolicyDisablesAppSwitchingWhileLocked() {
    #expect(LockShieldingPolicy.presentationOptions.contains(.disableProcessSwitching))
    #expect(LockShieldingPolicy.presentationOptions.contains(.disableHideApplication))
    #expect(LockShieldingPolicy.presentationOptions.contains(.disableSessionTermination))
}

@MainActor
@Test func unlockFeedbackKeepsPasswordEntryUsableAfterWrongPassword() {
    let passwordField = NSSecureTextField()
    passwordField.stringValue = "wrong-password"
    let messageLabel = NSTextField(labelWithString: "")
    messageLabel.isHidden = true

    let feedback = InlineUnlockFeedback(passwordField: passwordField, messageLabel: messageLabel)
    feedback.show("密码错误。")

    #expect(passwordField.stringValue.isEmpty)
    #expect(messageLabel.stringValue == "密码错误。")
    #expect(!messageLabel.isHidden)
}
