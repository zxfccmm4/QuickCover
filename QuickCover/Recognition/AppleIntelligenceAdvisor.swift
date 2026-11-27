import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// On-device semantic privacy detector powered by iOS 26/27 Apple Intelligence (`FoundationModels` /
/// `SystemLanguageModel`), identifying contextual PII that deterministic regex rules cannot catch
/// (e.g., personal names, street addresses, company/school names, order numbers, balances, handles).
/// Runs 100% locally on-device with zero cloud network calls, and degrades gracefully to a fast
/// local contextual matcher when Apple Intelligence hardware is unavailable.
enum AppleIntelligenceAdvisor {

    enum Engine: Equatable, Sendable {
        case appleIntelligence
        case onDeviceContext
    }

    struct Advice: Equatable, Sendable {
        let sensitiveLineIndices: [Int]
        let engine: Engine
    }

    /// True when the on-device Apple Intelligence `SystemLanguageModel` is available and ready.
    static var isAppleIntelligenceAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return SystemLanguageModel.default.availability == .available
        }
        #endif
        return false
    }

    /// Evaluates candidate OCR text lines and returns 0-based indices of lines likely containing
    /// personal or private information.
    static func detectSensitiveLines(_ lines: [String]) async -> Advice {
        guard !lines.isEmpty else {
            return Advice(sensitiveLineIndices: [], engine: isAppleIntelligenceAvailable ? .appleIntelligence : .onDeviceContext)
        }

        let fallback = contextualSensitiveIndices(in: lines)

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), SystemLanguageModel.default.availability == .available {
            if let aiIndices = await runFoundationModel(on: lines) {
                let merged = Array(Set(aiIndices).union(fallback)).sorted()
                return Advice(sensitiveLineIndices: merged, engine: .appleIntelligence)
            }
        }
        #endif

        return Advice(sensitiveLineIndices: fallback, engine: .onDeviceContext)
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    @Generable
    struct SensitiveLineSelection {
        @Guide(description: "0-based integer indices of text lines that contain personal or private details such as a person's name, home or shipping address, company or school name, account handle, order or tracking number, license plate, financial amount, or private note.")
        var indices: [Int]
    }

    @available(iOS 26.0, *)
    private static func runFoundationModel(on lines: [String]) async -> [Int]? {
        let clipped = lines.prefix(40).enumerated().map { idx, text in
            "[\(idx)] \(text.prefix(120))"
        }.joined(separator: "\n")

        let instructions = """
        You are an on-device privacy assistant for an iOS screenshot redaction app.
        Given numbered OCR lines from a screenshot or document, identify ONLY lines that contain
        personally identifiable or sensitive private data: real person names, shipping/home addresses,
        company/workplace/school names, account usernames/handles, order/tracking numbers, license plates,
        financial balances/salaries, or private medical/verification codes.
        Ignore generic UI chrome, titles, navigation buttons, timestamps, and boilerplate labels without values.
        Return their 0-based indices.
        """

        let session = LanguageModelSession(instructions: instructions)
        do {
            let response = try await session.respond(
                to: "Inspect these OCR lines and return sensitive line indices:\n\(clipped)",
                generating: SensitiveLineSelection.self
            )
            let validRange = 0..<min(lines.count, 40)
            return response.content.indices.filter { validRange.contains($0) }
        } catch {
            return nil
        }
    }
    #endif

    /// Fast deterministic contextual privacy detector for labeled personal fields (names, addresses,
    /// order/tracking numbers, handles, license plates, financial lines) that complements Vision rules
    /// and ensures consistent on-device behavior even on devices without Apple Intelligence enabled.
    static func contextualSensitiveIndices(in lines: [String]) -> [Int] {
        var matched: [Int] = []
        for (index, raw) in lines.enumerated() {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= 3 else { continue }
            if isContextualPrivateLine(trimmed) {
                matched.append(index)
            }
        }
        return matched
    }

    private static let labeledValuePattern = try! NSRegularExpression(
        pattern: #"(?:姓名|收货人|收件人|联系人|寄件人|持卡人|户名|地址|住址|收货地址|详细地址|公司|单位|学校|微信号|微信|账号|账户|户号|订单号|单号|运单号|快递单号|流水号|车牌|密码|验证码|余额|实付|金额|工资|薪资|Name|Recipient|Contact|Address|Company|Account|Username|Order\s*(?:No|ID|#)|Tracking|License\s*Plate)\s*[:：#]?\s*\S{2,}"#,
        options: [.caseInsensitive]
    )

    private static let streetAddressPattern = try! NSRegularExpression(
        pattern: #"[\u4e00-\u9fff]{2,}(?:省|市|区|县)[\u4e00-\u9fff0-9A-Za-z\s\-]{2,}(?:路|街|道|巷|弄|号|栋|幢|室|楼|园|村)"#,
        options: []
    )

    private static let orderCodePattern = try! NSRegularExpression(
        pattern: #"\b[A-Z]{2,4}[-_]\d{4}[-_]\d{4,}\b"#,
        options: []
    )

    private static let cnPlatePattern = try! NSRegularExpression(
        pattern: #"[京津沪渝冀豫云辽黑湘皖鲁新苏浙赣鄂桂甘晋蒙陕吉闽贵粤青藏川宁琼][A-Z][·•\s]?[A-Z0-9]{5,6}"#,
        options: []
    )

    private static func isContextualPrivateLine(_ line: String) -> Bool {
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        if labeledValuePattern.firstMatch(in: line, range: range) != nil { return true }
        if streetAddressPattern.firstMatch(in: line, range: range) != nil { return true }
        if orderCodePattern.firstMatch(in: line, range: range) != nil { return true }
        if cnPlatePattern.firstMatch(in: line, range: range) != nil { return true }
        return false
    }
}
