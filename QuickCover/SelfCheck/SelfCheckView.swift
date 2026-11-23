#if SELF_CHECK
import SwiftUI
import UIKit

/// What the self-check page shows and does. One thing runs at a time, so the timings are not
/// disturbed by each other.
@MainActor
@Observable
final class SelfCheckModel {

    var runningFixtures = false
    var done = 0
    var total = 0
    var current = ""
    var fixtureReport = ""
    var failure: String?

    var runningLarge = false
    var largeReport = ""

    /// When a 48-megapixel run starts it writes this down and clears it when it ends. Still there
    /// the next time the page opens: the app died in the middle of it, which is what the test is for.
    var largeRunLeftBehind: Date?
    var copied = false

    private let defaults: UserDefaults
    private static let startedKey = "selfcheck.largePicture.startedAt"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        largeRunLeftBehind = defaults.object(forKey: SelfCheckModel.startedKey) as? Date
    }

    var busy: Bool { runningFixtures || runningLarge }

    /// All the fake pictures, each recognized as the baseline run recognizes it.
    func runFixtures() async {
        guard !busy else { return }
        runningFixtures = true
        done = 0; total = 0; current = ""; fixtureReport = ""; failure = nil
        defer { runningFixtures = false }
        do {
            guard let directory = SelfCheck.fixtureDirectory() else { throw SelfCheck.Failure.noFixtures }
            let fixtures = try SelfCheck.fixtures(in: directory)
            total = fixtures.count
            var seen: [BaselineSeen] = []
            for fixture in fixtures {
                current = fixture.id
                seen.append(try await SelfCheck.measure(fixture, in: directory))
                done += 1
            }
            fixtureReport = "秒遮自检\n\(SelfCheck.deviceLine)\n" + SelfCheckText.fixtures(BaselineScore.score(seen))
        } catch {
            failure = "测试图没有跑完：\(error)"
        }
    }

    /// A 48-megapixel picture through preview, recognition and export, timed and watched for memory.
    func runLargePicture() async {
        guard !busy else { return }
        runningLarge = true
        largeReport = ""
        let started = Date()
        defaults.set(started, forKey: SelfCheckModel.startedKey)
        largeRunLeftBehind = nil
        defer { runningLarge = false }
        let peak = PeakMemory()
        let sampler = Task.detached(priority: .utility) {
            while !Task.isCancelled {
                peak.sample(SelfCheckMemory.footprintMB)
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
        defer { sampler.cancel() }
        do {
            let data = try await Task.detached(priority: .userInitiated) { try SelfCheck.makeLargePicture() }.value
            let steps = try await SelfCheck.runLargePicture(data, peak: peak)
            // Ended well: the mark goes, so the page does not say the app died next time.
            defaults.removeObject(forKey: SelfCheckModel.startedKey)
            largeReport = "秒遮自检 · 4800 万像素\n\(SelfCheck.deviceLine)\n" + SelfCheckText.largePicture(steps, peak: peak.value)
        } catch {
            defaults.removeObject(forKey: SelfCheckModel.startedKey)
            failure = "4800 万像素没有跑完：\(error)"
        }
    }

    func forgetLargeRun() {
        defaults.removeObject(forKey: SelfCheckModel.startedKey)
        largeRunLeftBehind = nil
    }

    func copy(_ text: String) {
        UIPasteboard.general.string = text
        copied = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            copied = false
        }
    }
}

/// The page. Plain on purpose: it is for the owner's own phone, not a screen of the app.
struct SelfCheckView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model = SelfCheckModel()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("在本机跑 30 张测试图，量每一类的召回和每张的耗时。大约一分钟。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button {
                        Task { await model.runFixtures() }
                    } label: {
                        if model.runningFixtures {
                            HStack {
                                ProgressView()
                                Text("正在跑 \(model.done)/\(model.total) · \(model.current)")
                            }
                        } else {
                            Text(model.fixtureReport.isEmpty ? "跑 30 张测试图" : "再跑一遍 30 张测试图")
                        }
                    }
                    .disabled(model.busy)
                    if model.runningFixtures {
                        ProgressView(value: Double(model.done), total: Double(max(model.total, 1)))
                    }
                    if let failure = model.failure {
                        Text(failure).font(.footnote).foregroundStyle(.red)
                    }
                } header: {
                    Text("召回与速度")
                }
                if !model.fixtureReport.isEmpty {
                    Section {
                        Text(model.fixtureReport)
                            .font(.system(.footnote, design: .monospaced))
                            .textSelection(.enabled)
                        Button {
                            model.copy(model.fixtureReport)
                        } label: {
                            Label(model.copied ? "已复制" : "复制结果", systemImage: model.copied ? "checkmark" : "doc.on.doc")
                        }
                        .disabled(model.busy)
                    }
                }
                Section {
                    Text("现做一张 4800 万像素的照片（8064 × 6048），走出预览、识别、导出三步，量耗时和内存。做图要等几秒。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if model.largeRunLeftBehind != nil {
                        Label("上一次的 4800 万像素测试没有跑完，App 在中途退出了。", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            Button("知道了，清除这条记录") { model.forgetLargeRun() }
                    }
                    Button {
                        Task { await model.runLargePicture() }
                    } label: {
                        if model.runningLarge {
                            HStack {
                                ProgressView()
                                Text("正在跑，请别离开这一页")
                            }
                        } else {
                            Text("测 4800 万像素")
                        }
                    }
                    .disabled(model.busy)
                } header: {
                    Text("4800 万像素")
                }
                if !model.largeReport.isEmpty {
                    Section {
                        Text(model.largeReport)
                            .font(.system(.footnote, design: .monospaced))
                            .textSelection(.enabled)
                        Button {
                            model.copy(model.largeReport)
                        } label: {
                            Label(model.copied ? "已复制" : "复制结果", systemImage: model.copied ? "checkmark" : "doc.on.doc")
                        }
                        .disabled(model.busy)
                    }
                }
            }
            .navigationTitle("自检")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}
#endif
