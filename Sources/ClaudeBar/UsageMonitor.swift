import Foundation
import Observation

struct UsageBlock: Decodable {
    let id: String
    let startTime: String
    let endTime: String
    let actualEndTime: String?
    let isActive: Bool
    let isGap: Bool
    let entries: Int
    let totalTokens: Int
    let costUSD: Double
    let models: [String]
    let tokenCounts: TokenCounts
}

struct TokenCounts: Decodable {
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationInputTokens: Int
    let cacheReadInputTokens: Int
}

struct UsageResponse: Decodable {
    let blocks: [UsageBlock]
}

struct RateLimitWindow {
    let usedPercentage: Double
    let resetsAt: Date
}

@MainActor
@Observable
final class UsageMonitor {
    var activeBlock: UsageBlock?
    var todayCost: Double = 0
    var todayTokens: Int = 0
    var lastUpdated: Date?
    var error: String?

    // From Claude Code's statusline JSON payload (rate_limits field on
    // /v1/messages responses). Updated by ~/.claude/statusline-bar.sh
    // writing to ~/.claude/last-status.json. Stale when no Claude session
    // is running — same constraint as the /usage TUI command.
    var fiveHour: RateLimitWindow?
    var sevenDay: RateLimitWindow?
    var rateLimitsUpdatedAt: Date?

    private var timer: Timer?
    private let ccusagePath: String
    private let rateLimitsURL = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".claude/last-status.json")

    init() {
        // Resolve ccusage path at init so we don't rely on shell PATH later.
        let which = Shell.run("command -v ccusage || echo ''")
        self.ccusagePath = which.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        readRateLimits()

        guard !ccusagePath.isEmpty else {
            error = "ccusage not installed (npm i -g ccusage)"
            return
        }
        let path = ccusagePath
        Task.detached(priority: .utility) {
            let blocksResult = Shell.run("\(path) blocks --json --offline -o desc 2>/dev/null")
            let dailyResult = Shell.run("\(path) daily --json --offline -o desc 2>/dev/null")
            await self.apply(blocksJSON: blocksResult.stdout, dailyJSON: dailyResult.stdout)
        }
    }

    private func readRateLimits() {
        guard let data = try? Data(contentsOf: rateLimitsURL),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let limits = obj["rate_limits"] as? [String: Any] else {
            fiveHour = nil
            sevenDay = nil
            return
        }
        fiveHour = parseWindow(limits["five_hour"])
        sevenDay = parseWindow(limits["seven_day"])
        if let attrs = try? FileManager.default.attributesOfItem(atPath: rateLimitsURL.path),
           let mtime = attrs[.modificationDate] as? Date {
            rateLimitsUpdatedAt = mtime
        }
    }

    private func parseWindow(_ raw: Any?) -> RateLimitWindow? {
        guard let dict = raw as? [String: Any],
              let pct = dict["used_percentage"] as? Double,
              let resets = dict["resets_at"] as? Double else { return nil }
        return RateLimitWindow(usedPercentage: pct, resetsAt: Date(timeIntervalSince1970: resets))
    }

    private func apply(blocksJSON: String, dailyJSON: String) {
        let decoder = JSONDecoder()
        if let data = blocksJSON.data(using: .utf8),
           let resp = try? decoder.decode(UsageResponse.self, from: data) {
            activeBlock = resp.blocks.first(where: { $0.isActive })
        }

        // daily JSON: { "daily": [{ date, totalCost, totalTokens, ... }] }
        if let data = dailyJSON.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let arr = obj["daily"] as? [[String: Any]] {
            let today = ISO8601DateFormatter.dateFormatter.string(from: Date())
            if let todayEntry = arr.first(where: { ($0["date"] as? String) == today }) {
                todayCost = (todayEntry["totalCost"] as? Double) ?? 0
                todayTokens = (todayEntry["totalTokens"] as? Int) ?? 0
            } else {
                todayCost = 0
                todayTokens = 0
            }
        }

        lastUpdated = Date()
        error = nil
    }

    var resetDate: Date? {
        guard let active = activeBlock else { return nil }
        return ISO8601DateFormatter.iso.date(from: active.endTime)
    }

    var resetCountdown: String {
        guard let reset = resetDate else { return "—" }
        let interval = reset.timeIntervalSinceNow
        if interval <= 0 { return "resetting…" }
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    var blockProgress: Double {
        guard let active = activeBlock,
              let start = ISO8601DateFormatter.iso.date(from: active.startTime),
              let end = ISO8601DateFormatter.iso.date(from: active.endTime) else { return 0 }
        let total = end.timeIntervalSince(start)
        let elapsed = Date().timeIntervalSince(start)
        return max(0, min(1, elapsed / total))
    }
}

extension ISO8601DateFormatter {
    nonisolated(unsafe) static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    nonisolated(unsafe) static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}
