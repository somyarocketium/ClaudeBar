import Foundation
import Observation

struct ClaudeProcess: Identifiable, Hashable {
    let id: Int32
    let elapsed: String
    let cwd: String?
    let model: String?
}

@MainActor
@Observable
final class ProcessMonitor {
    var processes: [ClaudeProcess] = []
    var lastError: String?
    var previousPIDs: Set<Int32> = []

    private var timer: Timer?
    var onSessionFinished: (() -> Void)?

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        let result = Shell.run("ps -axo pid=,etime=,command= | grep -E '(claude-code/[0-9]|\\.local/share/claude/versions|\\.local/bin/claude)' | grep -v 'grep ' | grep -vE 'Claude Helper|/Applications/Claude\\.app'")
        var found: [ClaudeProcess] = []
        let lines = result.stdout.split(separator: "\n", omittingEmptySubsequences: true)
        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespaces)
            // Format: "PID ELAPSED COMMAND..."
            let parts = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            guard parts.count >= 3, let pid = Int32(parts[0]) else { continue }
            let elapsed = String(parts[1])
            let command = String(parts[2])
            // Skip parent/child duplicates: ps shows both; prefer child (leaf) by deduping later if needed
            let model = extractModel(from: command)
            let cwd = fetchCwd(pid: pid)
            found.append(ClaudeProcess(id: pid, elapsed: formatElapsed(elapsed), cwd: cwd, model: model))
        }

        // Dedupe by PID (should already be unique) and sort by PID desc (newest first)
        let unique = Array(Set(found)).sorted { $0.id > $1.id }

        let currentPIDs = Set(unique.map(\.id))
        let finishedPIDs = previousPIDs.subtracting(currentPIDs)
        if !finishedPIDs.isEmpty && !previousPIDs.isEmpty {
            onSessionFinished?()
        }
        previousPIDs = currentPIDs
        processes = unique
    }

    private func extractModel(from command: String) -> String? {
        guard let range = command.range(of: "--model ") else { return nil }
        let rest = command[range.upperBound...]
        let model = rest.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true).first
        return model.map(String.init)
    }

    private func fetchCwd(pid: Int32) -> String? {
        let res = Shell.run("lsof -p \(pid) -a -d cwd -Fn 2>/dev/null | awk '/^n/{print substr($0,2); exit}'", timeout: 2)
        let cwd = res.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return cwd.isEmpty ? nil : cwd
    }

    private func formatElapsed(_ etime: String) -> String {
        // ps etime formats: MM:SS, HH:MM:SS, D-HH:MM:SS
        return etime
    }
}
