import SwiftUI
import AppKit
import UserNotifications

@main
struct ClaudeBarApp: App {
    @State private var processes = ProcessMonitor()
    @State private var usage = UsageMonitor()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    init() {
        // UserNotifications authorization (for session-finished alerts as a fallback if hook isn't configured)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContent(processes: processes, usage: usage)
                .onAppear {
                    processes.start()
                    usage.start()
                    processes.onSessionFinished = {
                        postFinishedNotification()
                    }
                }
        } label: {
            MenuBarLabel(processes: processes, usage: usage)
        }
        .menuBarExtraStyle(.window)
    }

    private func postFinishedNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Claude Code finished"
        content.body = "A terminal session just ended."
        content.sound = .default
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }
}

struct MenuBarLabel: View {
    let processes: ProcessMonitor
    let usage: UsageMonitor

    var body: some View {
        HStack(spacing: 3) {
            Image(nsImage: ClaudeSparkleIcon.shared)
            if !processes.processes.isEmpty {
                Text("\(processes.processes.count)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
        }
    }
}

/// Claude's 4-petal sparkle, pre-rendered once to an NSImage template
/// (so the system handles light/dark tinting natively in the menu bar).
enum ClaudeSparkleIcon {
    static let shared: NSImage = render(size: 16)

    private static func render(size: CGFloat) -> NSImage {
        let img = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let s = min(rect.width, rect.height)
            let cx = rect.midX, cy = rect.midY
            let petalLen = s * 0.48
            let petalHalfWidth = s * 0.14

            NSColor.black.setFill()
            for i in 0..<4 {
                let angle = CGFloat(i) * .pi / 2
                ctx.saveGState()
                ctx.translateBy(x: cx, y: cy)
                ctx.rotate(by: angle)

                let path = CGMutablePath()
                path.move(to: CGPoint(x: -petalLen, y: 0))
                path.addQuadCurve(
                    to: CGPoint(x: petalLen, y: 0),
                    control: CGPoint(x: 0, y: -petalHalfWidth)
                )
                path.addQuadCurve(
                    to: CGPoint(x: -petalLen, y: 0),
                    control: CGPoint(x: 0, y: petalHalfWidth)
                )
                path.closeSubpath()
                ctx.addPath(path)
                ctx.fillPath()

                ctx.restoreGState()
            }
            return true
        }
        img.isTemplate = true
        return img
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
