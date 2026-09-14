// focusmaxxing hub simulator harness: walk plan.json against the installed Hub with XCUITest.
//
// reads FMX_PLAN (the plan), FMX_OUT (where to write) and FMX_BUNDLE_ID from the environment
// (drive_xcui.sh passes them as TEST_RUNNER_ variables). a step that fails is written down and the
// walk carries on, so one missing button does not cost every later screenshot.
import XCTest

private struct StepError: Error, CustomStringConvertible {
    let description: String
}

final class PlanRunner: XCTestCase {
    private var app: XCUIApplication!
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    private var out: URL!
    private var notes = [String]()

    override func setUp() {
        super.setUp()
        continueAfterFailure = true
    }

    func testRunPlan() throws {
        let env = ProcessInfo.processInfo.environment
        guard let planPath = env["FMX_PLAN"], let outPath = env["FMX_OUT"] else {
            XCTFail("FMX_PLAN and FMX_OUT must be set")
            return
        }
        let plan = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: planPath))) as? [String: Any] ?? [:]
        let bundleId = env["FMX_BUNDLE_ID"] ?? (plan["bundleId"] as? String) ?? "com.SideStore.SideStore"
        self.out = URL(fileURLWithPath: outPath, isDirectory: true)
        try FileManager.default.createDirectory(at: self.out, withIntermediateDirectories: true)
        self.app = XCUIApplication(bundleIdentifier: bundleId)

        var failures = 0
        let steps = plan["steps"] as? [[String: Any]] ?? []
        for (index, step) in steps.enumerated() {
            let action = step["do"] as? String ?? "?"
            self.note("step \(index + 1): \(action) \(step.filter { $0.key != "do" })")
            do {
                try self.run(action, step)
            } catch {
                failures += 1
                self.note("  FAILED: \(error)")
                try? self.shot(String(format: "failed-step-%02d", index + 1))
            }
        }
        self.note("done, \(failures) failed step(s)")
        try? self.notes.joined(separator: "\n").write(to: self.out.appendingPathComponent("steps.txt"), atomically: true, encoding: .utf8)
        XCTAssertEqual(failures, 0, "some plan steps failed; see steps.txt")
    }

    // MARK: the actions

    private func run(_ action: String, _ step: [String: Any]) throws {
        switch action {
        case "launch":
            try self.launch(step)
        case "dismissAlerts":
            self.dismissAlerts(labels: step["tap"] as? [String] ?? ["Allow", "OK"], seconds: self.number(step["seconds"], 4))
        case "expectAbsent":
            try self.expectAbsent(step)
        case "shot":
            try self.shot(step["name"] as? String ?? "shot")
        case "drag":
            self.drag(dy: CGFloat(self.number(step["dy"], 300)), x: CGFloat(self.number(step["x"], 8)), hold: self.number(step["hold"], 0.8))
        case "scrollToTop":
            for _ in 0..<3 { self.drag(dy: -800, x: 8, hold: 0.3) }
        case "tap":
            try self.tap(step)
        case "tapPoint":
            self.point(x: CGFloat(self.number(step["x"], 0)), y: CGFloat(self.number(step["y"], 0))).tap()
        case "back":
            let button = self.app.navigationBars.firstMatch.buttons.element(boundBy: 0)
            guard button.waitForExistence(timeout: 5) else { throw StepError(description: "no back button") }
            button.tap()
        case "sleep":
            Thread.sleep(forTimeInterval: self.number(step["seconds"], 1))
        case "activate":
            // bring the Hub back to the front without relaunching it (after it opened another app)
            self.app.activate()
            if let label = step["waitFor"] as? String {
                let timeout = self.number(step["timeout"], 20)
                guard self.element(label, match: "exact", type: step["waitType"] as? String).waitForExistence(timeout: timeout) else {
                    throw StepError(description: "'\(label)' never appeared in \(Int(timeout))s after activating")
                }
                self.note("  '\(label)' is on screen")
            }
        default:
            throw StepError(description: "unknown action \(action)")
        }
    }

    private func launch(_ step: [String: Any]) throws {
        self.app.terminate()
        self.app.launchArguments = step["args"] as? [String] ?? []
        self.app.launch()
        if let label = step["waitFor"] as? String {
            let element = self.element(label, match: "exact", type: step["waitType"] as? String)
            let timeout = self.number(step["timeout"], 120)
            guard element.waitForExistence(timeout: timeout) else {
                throw StepError(description: "'\(label)' never appeared in \(Int(timeout))s")
            }
            self.note("  '\(label)' is on screen")
        }
    }

    private func dismissAlerts(labels: [String], seconds: Double) {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            let alert = self.springboard.alerts.firstMatch
            guard alert.waitForExistence(timeout: 1) else { continue }
            var tapped = false
            for label in labels where alert.buttons[label].exists {
                self.note("  tapping alert button '\(label)'")
                alert.buttons[label].tap()
                tapped = true
                break
            }
            if !tapped {
                self.note("  an alert is up with none of \(labels): \(alert.debugDescription)")
                return
            }
            Thread.sleep(forTimeInterval: 1)
        }
    }

    private func expectAbsent(_ step: [String: Any]) throws {
        let label = step["label"] as? String ?? ""
        let element = self.element(label, match: "exact", type: nil)
        guard element.waitForExistence(timeout: self.number(step["seconds"], 3)) else {
            self.note("  '\(label)' is not on screen, as expected")
            return
        }
        self.note("  WARNING '\(label)' IS on screen")
        if let args = step["orRelaunchWith"] as? [String] {
            self.note("  relaunching with \(args)")
            var relaunch = step
            relaunch["args"] = args
            try self.launch(relaunch)
        }
    }

    private func shot(_ name: String) throws {
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try png.write(to: self.out.appendingPathComponent(name + ".png"))
        var tree = self.app.debugDescription
        if self.springboard.alerts.count > 0 {
            tree += "\n\n--- system alert over the app ---\n" + self.springboard.alerts.firstMatch.debugDescription
        }
        try tree.write(to: self.out.appendingPathComponent(name + ".tree.txt"), atomically: true, encoding: .utf8)
        self.note("  saved \(name).png")
    }

    private func tap(_ step: [String: Any]) throws {
        let label = step["label"] as? String ?? ""
        let match = step["match"] as? String ?? "exact"
        let type = step["type"] as? String
        let maxScrolls = Int(self.number(step["maxScrolls"], 0))
        for attempt in 0...maxScrolls {
            let element = self.element(label, match: match, type: type)
            // "anywhere": true skips the well-inside check, for a button that lives at the very top or
            // bottom of the screen (the first run's big button, a navigation bar's Close or Done)
            let anywhere = (step["anywhere"] as? Bool) ?? false
            if element.exists, element.isHittable, type == "tab" || anywhere || self.isWellInside(element.frame) {
                self.note("  tapping '\(element.label)' at \(element.frame)")
                element.tap()
                return
            }
            if attempt < maxScrolls {
                self.drag(dy: CGFloat(self.number(step["scrollDy"], 300)), x: 8, hold: 0.5)
            }
        }
        // the same fallback the idb driver needs: tap the tab's slot on the bar
        if type == "tab", let index = step["tabIndex"] as? NSNumber {
            let count = CGFloat(self.number(step["tabCount"], 3))
            let x = self.screen.width * (CGFloat(index.doubleValue) + 0.5) / count
            let y = self.screen.height - CGFloat(self.number(step["tabFromBottom"], 58))
            self.note("  no '\(label)' tab found by label; tapping tab slot \(index) of \(Int(count)) at (\(Int(x)), \(Int(y)))")
            self.point(x: x, y: y).tap()
            return
        }
        throw StepError(description: "could not find '\(label)' (\(match)) on screen")
    }

    // MARK: helpers

    private func element(_ label: String, match: String, type: String?) -> XCUIElement {
        let predicate: NSPredicate
        switch match {
        case "prefix": predicate = NSPredicate(format: "label BEGINSWITH %@", label)
        case "contains": predicate = NSPredicate(format: "label CONTAINS %@", label)
        default: predicate = NSPredicate(format: "label == %@", label)
        }
        switch type {
        case "tab": return self.app.tabBars.buttons.matching(predicate).firstMatch
        case "button": return self.app.buttons.matching(predicate).firstMatch
        default: return self.app.descendants(matching: .any).matching(predicate).firstMatch
        }
    }

    private var screen: CGRect {
        let frame = self.app.windows.firstMatch.frame
        return frame.isEmpty ? CGRect(x: 0, y: 0, width: 402, height: 874) : frame
    }

    private func isWellInside(_ frame: CGRect) -> Bool {
        return frame.minY >= self.screen.minY + 110 && frame.maxY <= self.screen.maxY - 95
    }

    private func point(x: CGFloat, y: CGFloat) -> XCUICoordinate {
        return self.app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: y))
    }

    // a slow drag with a hold at the end, so the content stops where the finger stops instead of
    // flying on; started at x=8, in the gutter left of the cards, so it never lands on a control
    private func drag(dy: CGFloat, x: CGFloat, hold: Double) {
        var remaining = dy
        while abs(remaining) > 0.5 {
            let chunk = max(min(remaining, 400), -400)
            let startY = chunk > 0 ? self.screen.height * 0.75 : self.screen.height * 0.25
            let start = self.point(x: x, y: startY)
            let end = self.point(x: x, y: startY - chunk)
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: hold)
            remaining -= chunk
        }
        Thread.sleep(forTimeInterval: 0.6)
    }

    private func number(_ value: Any?, _ fallback: Double) -> Double {
        if let n = value as? NSNumber { return n.doubleValue }
        return fallback
    }

    private func note(_ text: String) {
        print(text)
        self.notes.append(text)
    }
}
