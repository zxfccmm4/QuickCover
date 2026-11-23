#if SELF_CHECK
import CoreText
import Foundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// The self-check page, only in the build made for the owner's own phone. It runs the 30 fake
/// pictures with their truth through the recognizer on this device, so what the simulator cannot
/// measure is measured here: codes, speed, and a 48-megapixel picture ending well. The page and the
/// pictures are left out of every other build: this file is compiled away and the folder
/// `SelfCheckFixtures` is not put into the bundle.
enum SelfCheck {

    enum Failure: Error {
        case noFixtures
        case cannotOpen(String)
        case cannotMakePicture
    }

    /// Where the fixtures are: copied into the bundle after the self-check archive is built.
    static func fixtureDirectory(in bundle: Bundle = .main) -> URL? {
        bundle.url(forResource: "SelfCheckFixtures", withExtension: nil)
    }

    /// Every fixture in `directory`, by file name.
    static func fixtures(in directory: URL) throws -> [BaselineFixture] {
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { try? JSONDecoder().decode(BaselineFixture.self, from: Data(contentsOf: $0)) }
            .sorted { $0.id < $1.id }
    }

    /// One fixture recognized the way the baseline run does it, with how long that took. Decoding
    /// and recognition run away from the main actor; the numbers are in the picture's own pixels.
    static func measure(_ fixture: BaselineFixture, in directory: URL) async throws -> BaselineSeen {
        let data = try Data(contentsOf: directory.appending(path: fixture.file))
        let measured = try await Task.detached(priority: .userInitiated) { () throws -> (RecognitionResult, Double) in
            let source = try PictureSource(data: data)
            guard let thumb = source.thumbnail(maxLongSide: 2048) else { throw Failure.cannotOpen(fixture.file) }
            let start = ContinuousClock.now
            let result = try await Recognizer(options: .init(mergeGapEm: 0)).recognize(thumb)
            return (result, SelfCheck.milliseconds(start.duration(to: .now)))
        }.value
        let scale = CGSize(width: CGFloat(fixture.width) / measured.0.size.width, height: CGFloat(fixture.height) / measured.0.size.height)
        return BaselineSeen(fixture: fixture, result: measured.0.scaled(by: scale), milliseconds: measured.1)
    }

    /// A 48-megapixel photograph, 8064 × 6048, as a JPEG file the way a camera hands one over:
    /// a gradient with lines of text, so recognition has something to read at every size.
    static func makeLargePicture() throws -> Data {
        let width = 8064, height = 6048
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { throw Failure.cannotMakePicture }
        let colors = [CGColor(red: 0.95, green: 0.55, blue: 0.25, alpha: 1), CGColor(red: 0.2, green: 0.35, blue: 0.75, alpha: 1)] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
            context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: width, y: height), options: [])
        }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: CTFontCreateWithName("Helvetica" as CFString, 140, nil),
            .foregroundColor: CGColor(gray: 1, alpha: 1),
        ]
        for row in 0..<48 {
            let text = "订单 \(row + 1) 电话 1380013800\(row % 10) 卡号 62220212345678\(String(format: "%04d", row)) hello@example.com"
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
            context.textPosition = CGPoint(x: 120, y: height - 300 - row * 118)
            CTLineDraw(line, context)
        }
        guard let image = context.makeImage() else { throw Failure.cannotMakePicture }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else { throw Failure.cannotMakePicture }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.92] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw Failure.cannotMakePicture }
        return data as Data
    }

    /// A duration in milliseconds.
    static func milliseconds(_ duration: Duration) -> Double {
        let parts = duration.components
        return Double(parts.seconds) * 1000 + Double(parts.attoseconds) / 1e15
    }

    /// One timed step of the big-picture run: its milliseconds (or, for the file, its bytes) and
    /// the app's memory right after it.
    struct Step: Sendable {
        let name: String
        let value: Double
        let memory: Double
    }

    /// What the app does with a big picture, timed step by step: the preview, the recognition,
    /// the export at full size. Runs away from the main actor; `peak` is sampled all along.
    static func runLargePicture(_ data: Data, peak: PeakMemory) async throws -> [Step] {
        try await Task.detached(priority: .userInitiated) {
            func milliseconds(since start: ContinuousClock.Instant) -> Double {
                SelfCheck.milliseconds(start.duration(to: .now))
            }
            func step(_ name: String, _ value: Double) -> Step {
                let memory = SelfCheckMemory.footprintMB
                peak.sample(memory)
                return Step(name: name, value: value, memory: memory)
            }
            var start = ContinuousClock.now
            let source = try PictureSource(data: data)
            guard let preview = source.thumbnail(maxLongSide: 2048) else { throw Failure.cannotOpen("48MP") }
            var steps = [step("preview", milliseconds(since: start))]

            start = ContinuousClock.now
            let result = try await Recognizer().recognize(preview)
            steps.append(step("recognition", milliseconds(since: start)))

            start = ContinuousClock.now
            let scale = CGSize(width: source.size.width / result.size.width, height: source.size.height / result.size.height)
            let findings = result.scaled(by: scale).findings
            let file = try MaskRenderer.encode(source.source, orientation: source.orientation, findings: findings,
                                               options: .init(style: .mosaic, stripMetadata: true))
            steps.append(step("export", milliseconds(since: start)))
            steps.append(step("file", Double(file.count)))
            return steps
        }.value
    }

    /// The device this ran on, for the top of the report.
    static var deviceLine: String {
        var system = utsname()
        uname(&system)
        let machine = withUnsafeBytes(of: &system.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let os = ProcessInfo.processInfo.operatingSystemVersion
        return "\(machine) · iOS \(os.majorVersion).\(os.minorVersion).\(os.patchVersion) · 秒遮 \(version) (\(build))"
    }
}

/// The most memory seen during a run, kept safe to update from anywhere.
final class PeakMemory: @unchecked Sendable {
    private let lock = NSLock()
    private var peak = 0.0

    func sample(_ megabytes: Double) {
        lock.lock(); peak = max(peak, megabytes); lock.unlock()
    }

    var value: Double {
        lock.lock(); defer { lock.unlock() }
        return peak
    }
}

/// The memory the system counts against this app, in megabytes.
enum SelfCheckMemory {
    static var footprintMB: Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let status = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return status == KERN_SUCCESS ? Double(info.phys_footprint) / 1_048_576 : 0
    }
}

/// The reports as plain text, the way they are pasted into a chat.
enum SelfCheckText {

    static let ruleNames: [(rule: String, label: String)] = [
        ("phone", "手机号"), ("id", "身份证"), ("bank", "银行卡"), ("email", "邮箱"),
        ("url", "网址"), ("ipv4", "IP"), ("ref", "长串编号"), ("plate", "车牌"),
    ]

    static func ruleLabel(_ rule: String) -> String {
        ruleNames.first { $0.rule == rule }?.label ?? ["face": "人脸", "code": "二维码/条码"][rule] ?? rule
    }

    static func percent(_ hit: Int, _ total: Int) -> String {
        total > 0 ? "\(hit)/\(total) = " + String(format: "%.1f%%", Double(hit) / Double(total) * 100) : "0/0"
    }

    static func fixtures(_ report: [String: Any]) -> String {
        func count(_ key: String) -> Int { report[key] as? Int ?? 0 }
        func rows(_ key: String) -> [[String: Any]] { report[key] as? [[String: Any]] ?? [] }
        var lines: [String] = []
        lines.append("【30 张测试图】共 \(count("images")) 张")
        lines.append("规则文字 \(percent(count("text_recall_hit"), count("text_recall_total")))（整段盖住才算中），误遮 \(count("text_false")) 处（占 " + String(format: "%.1f%%", (report["text_false_positive_rate"] as? Double ?? 0) * 100) + "）")
        let rules = report["per_rule"] as? [String: [String: Int]] ?? [:]
        lines.append(ruleNames.compactMap { name, label in rules[name].map { "\(label) \($0["hit"] ?? 0)/\($0["total"] ?? 0)" } }.joined(separator: " · "))
        lines.append("人脸 \(percent(count("face_recall_hit"), count("face_recall_total")))")
        lines.append("二维码/条码 \(percent(count("code_recall_hit"), count("code_recall_total")))")
        let detail = report["shadow_detail"] as? [[String: Any]] ?? []
        lines.append("「所有文字都遮」盖住姓名、地址 \(detail.filter { $0["covered"] as? Bool == true }.count)/\(detail.count)")
        let missed = rows("missed")
        if missed.isEmpty {
            lines.append("漏遮：无")
        } else {
            lines.append("漏遮 \(missed.count) 处：")
            for item in missed {
                let rule = item["rule"] as? String ?? "?"
                lines.append("  · \(item["id"] as? String ?? "?") \(ruleLabel(rule)) \(item["text"] as? String ?? "")")
            }
        }
        let falsePositives = rows("false_positives")
        if !falsePositives.isEmpty {
            lines.append("误遮 \(falsePositives.count) 处：")
            for item in falsePositives {
                lines.append("  · \(item["id"] as? String ?? "?") \(ruleLabel(item["rule"] as? String ?? ""))「\(item["text"] as? String ?? "")」")
            }
        }
        let images = rows("per_image")
        let times = images.compactMap { $0["ms"] as? Double }
        if !times.isEmpty {
            lines.append(String(format: "每张耗时：最慢 %.0f 毫秒，平均 %.0f 毫秒", times.max()!, times.reduce(0, +) / Double(times.count)))
            for image in images.sorted(by: { ($0["ms"] as? Double ?? 0) > ($1["ms"] as? Double ?? 0) }).prefix(8) {
                lines.append(String(format: "  · %@ %.0f 毫秒", image["id"] as? String ?? "?", image["ms"] as? Double ?? 0))
            }
        }
        return lines.joined(separator: "\n")
    }

    static func largePicture(_ steps: [SelfCheck.Step], peak: Double) -> String {
        var lines = ["【4800 万像素】8064 × 6048"]
        let names = ["preview": "出预览", "recognition": "识别", "export": "导出", "file": "文件大小"]
        for step in steps {
            let value = step.name == "file" ? String(format: "%.1f MB", step.value / 1_048_576) : String(format: "%.0f 毫秒", step.value)
            lines.append("  \(names[step.name] ?? step.name) \(value)")
        }
        lines.append(String(format: "内存峰值 %.0f MB", peak))
        lines.append("没有闪退")
        return lines.joined(separator: "\n")
    }
}
#endif
