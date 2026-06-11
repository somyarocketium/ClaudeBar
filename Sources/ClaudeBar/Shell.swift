import Foundation

enum Shell {
    static func run(_ command: String, timeout: TimeInterval = 10) -> (stdout: String, exitCode: Int32) {
        let task = Process()
        let pipe = Pipe()
        task.launchPath = "/bin/zsh"
        task.arguments = ["-lc", command]
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
        } catch {
            return ("", -1)
        }

        let deadline = Date().addingTimeInterval(timeout)
        while task.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if task.isRunning {
            task.terminate()
            return ("", -2)
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let out = String(data: data, encoding: .utf8) ?? ""
        return (out, task.terminationStatus)
    }
}
