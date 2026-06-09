import AgentPrivacyLockCore
import AppKit
import Foundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: PrivacyLockController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let configuration = try CommandLineConfiguration.loadOrCreate()
            guard !CommandLine.arguments.contains("--set-password") else {
                NSApp.terminate(nil)
                return
            }

            let controller = PrivacyLockController(configuration: configuration) {
                NSApp.terminate(nil)
            }
            self.controller = controller
            controller.start()
        } catch {
            fputs("Agent永动机启动失败：\(error)\n", stderr)
            NSApp.terminate(nil)
        }
    }
}

enum CommandLineConfiguration {
    static func loadOrCreate(arguments: [String] = CommandLine.arguments, store: PasswordStore = PasswordStore()) throws -> LockConfiguration {
        let taskLabel = value(after: "--task", in: arguments) ?? "Background agent task"
        let policy = value(after: "--policy", in: arguments).flatMap(CaffeinatePolicy.init(rawValue:)) ?? .full

        if let password = value(after: "--set-password", in: arguments) {
            let record = try store.saveNewPassword(password)
            print("Password stored at \(store.passwordFile.path)")
            return LockConfiguration(passwordRecord: record, taskLabel: taskLabel, caffeinatePolicy: policy)
        }

        if store.hasPassword {
            return LockConfiguration(passwordRecord: try store.load(), taskLabel: taskLabel, caffeinatePolicy: policy)
        }

        print("No password is configured. Enter a new unlock password:")
        guard let password = readLine(), !password.isEmpty else {
            throw PasswordRecord.Error.emptyPassword
        }

        return LockConfiguration(
            passwordRecord: try store.saveNewPassword(password),
            taskLabel: taskLabel,
            caffeinatePolicy: policy
        )
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag) else {
            return nil
        }
        let next = arguments.index(after: index)
        guard next < arguments.endIndex else {
            return nil
        }
        return arguments[next]
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
