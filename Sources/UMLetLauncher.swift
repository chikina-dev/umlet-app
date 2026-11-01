import AppKit

enum LauncherError: LocalizedError {
    case missingUMLet
    case missingJava

    var errorDescription: String? {
        switch self {
        case .missingUMLet:
            return "UMLet が見つかりません。ターミナルで brew install umlet を実行してください。"
        case .missingJava:
            return "Java が見つかりません。ターミナルで brew install openjdk を実行してください。"
        }
    }
}

struct Installation {
    let home: URL
    let java: URL

    static func locate() throws -> Installation {
        let environment = ProcessInfo.processInfo.environment
        let prefixes = ["/opt/homebrew", "/usr/local"]
        let homes = [environment["UMLET_HOME"]].compactMap { $0 }
            + prefixes.map { "\($0)/opt/umlet/libexec" }
        guard let home = homes.first(where: {
            FileManager.default.fileExists(atPath: "\($0)/umlet.jar")
        }) else { throw LauncherError.missingUMLet }

        let javaCandidates = [environment["JAVA_HOME"].map { "\($0)/bin/java" }].compactMap { $0 }
            + prefixes.map { "\($0)/opt/openjdk/bin/java" }
            + ["/usr/bin/java"]
        guard let java = javaCandidates.first(where: {
            FileManager.default.isExecutableFile(atPath: $0)
        }) else { throw LauncherError.missingJava }
        return Installation(home: URL(fileURLWithPath: home), java: URL(fileURLWithPath: java))
    }

    func process(file: String?) -> Process {
        let process = Process()
        process.executableURL = java
        process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
        process.arguments = [
            "-Xdock:name=UMLet",
            "-Xdock:icon=\(home.appendingPathComponent("img/umlet_logo.png").path)",
            "-Dapple.laf.useScreenMenuBar=true",
            "-Dsun.java2d.xrender=f",
            "-jar", home.appendingPathComponent("umlet.jar").path,
        ] + (file.map { ["-filename=\($0)"] } ?? [])
        return process
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var receivedOpenEvent = false
    private var pending: [String?] = []
    private var processes: [Int32: Process] = [:]
    private var launching = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Finder delivers initial document/untitled events during launch.
        if !receivedOpenEvent { enqueue([nil]) }
    }

    func applicationOpenUntitledFile(_ sender: NSApplication) -> Bool {
        receivedOpenEvent = true
        enqueue([nil])
        return true
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        receivedOpenEvent = true
        enqueue(filenames.map { Optional($0) })
        sender.reply(toOpenOrPrint: .success)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if let running = processes.values.first(where: { $0.isRunning }),
           let app = NSRunningApplication(processIdentifier: running.processIdentifier) {
            app.activate(options: [.activateAllWindows])
        } else {
            enqueue([nil])
        }
        return false
    }

    private func enqueue(_ files: [String?]) {
        pending.append(contentsOf: files)
        launchNext()
    }

    private func launchNext() {
        guard !launching, !pending.isEmpty else { return }
        launching = true
        let file = pending.removeFirst()
        do {
            let process = try Installation.locate().process(file: file)
            process.terminationHandler = { child in
                DispatchQueue.main.async {
                    self.processes.removeValue(forKey: child.processIdentifier)
                    if child.terminationStatus != 0 {
                        self.showError("UMLet が終了コード \(child.terminationStatus) で終了しました。Java のインストールを確認してください。")
                    }
                    self.terminateIfIdle()
                }
            }
            try process.run()
            processes[process.processIdentifier] = process
        } catch {
            showError(error.localizedDescription)
        }
        // UMLet forwards filenames through one shared file, polled once a second.
        // Space requests so a multi-file Finder open does not overwrite that file.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.launching = false
            self.launchNext()
            self.terminateIfIdle()
        }
    }

    private func terminateIfIdle() {
        if !launching && pending.isEmpty && processes.isEmpty {
            NSApp.terminate(nil)
        }
    }

    private func showError(_ message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "UMLet を起動できませんでした"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.runModal()
    }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.run()
