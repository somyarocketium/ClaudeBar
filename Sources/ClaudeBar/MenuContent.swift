import SwiftUI

struct MenuContent: View {
    @Bindable var processes: ProcessMonitor
    @Bindable var usage: UsageMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            sessionsSection
            Divider()
            planUsageSection
            Divider()
            footer
        }
        .frame(width: 340)
        .padding(.vertical, 4)
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(processes.processes.isEmpty ? Color.secondary.opacity(0.3) : Color.green)
                    .frame(width: 10, height: 10)
                if !processes.processes.isEmpty {
                    Circle()
                        .stroke(Color.green.opacity(0.5), lineWidth: 2)
                        .frame(width: 18, height: 18)
                }
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(processes.processes.isEmpty ? "Idle" : "Running")
                    .font(.system(size: 13, weight: .semibold))
                Text(processes.processes.isEmpty
                     ? "No Claude Code sessions"
                     : "\(processes.processes.count) session\(processes.processes.count == 1 ? "" : "s") active")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !processes.processes.isEmpty {
                Text("\(processes.processes.count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.green))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var sessionsSection: some View {
        if processes.processes.isEmpty {
            HStack {
                Image(systemName: "moon.zzz")
                    .foregroundStyle(.tertiary)
                Text("No active sessions")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("SESSIONS")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 8)
                ForEach(processes.processes) { p in
                    SessionRow(process: p)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private var planUsageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("PLAN USAGE")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                Spacer()
                if usage.fiveHour == nil && usage.sevenDay == nil {
                    Text("waiting for session")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.top, 8)

            if let five = usage.fiveHour {
                planRow(label: "5-hour", window: five)
            }
            if let week = usage.sevenDay {
                planRow(label: "7-day", window: week)
            }
            if usage.fiveHour == nil && usage.sevenDay == nil {
                Text("Run a Claude session to populate plan limits")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }

    private func planRow(label: String, window: RateLimitWindow) -> some View {
        let pct = max(0, min(100, window.usedPercentage))
        let tint: Color = pct >= 90 ? .red : (pct >= 70 ? .orange : .accentColor)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Text(String(format: "%.0f%%", pct))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(tint)
                Text("· resets \(planResetCountdown(window.resetsAt))")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            ProgressView(value: pct / 100)
                .progressViewStyle(.linear)
                .tint(tint)
        }
    }

    private func planResetCountdown(_ date: Date) -> String {
        let interval = date.timeIntervalSinceNow
        if interval <= 0 { return "now" }
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours >= 24 { return "in \(hours / 24)d \(hours % 24)h" }
        if hours > 0 { return "in \(hours)h \(minutes)m" }
        return "in \(minutes)m"
    }

    private var footer: some View {
        HStack {
            Button(action: { usage.refresh(); processes.refresh() }) {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer()

            if let t = usage.lastUpdated {
                Text(relativeTime(t))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func relativeTime(_ date: Date) -> String {
        let sec = Int(Date().timeIntervalSince(date))
        if sec < 60 { return "updated \(sec)s ago" }
        return "updated \(sec/60)m ago"
    }
}

struct SessionRow: View {
    let process: ClaudeProcess

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.green)
                .frame(width: 6, height: 6)
            VStack(alignment: .leading, spacing: 1) {
                Text(shortPath(process.cwd ?? "unknown"))
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: 6) {
                    Text("pid \(process.id)")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    if let m = process.model {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(shortModel(m))
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            Text(process.elapsed)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private func shortPath(_ p: String) -> String {
        let home = NSHomeDirectory()
        if p.hasPrefix(home) { return "~" + p.dropFirst(home.count) }
        return p
    }

    private func shortModel(_ m: String) -> String {
        m.replacingOccurrences(of: "claude-", with: "")
            .replacingOccurrences(of: "-", with: " ")
    }
}
