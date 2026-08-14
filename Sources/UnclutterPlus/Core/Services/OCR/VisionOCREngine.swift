import Foundation
import AppKit
import Vision

/// 本地 Vision OCR 引擎（macOS 14+，零外部依赖，隐私友好）
///
/// 替代 Deepseek CLI 外部二进制作为默认 OCR 实现；
/// 与 DeepseekOCREngine 遵循同一 OCREngine 协议，由配置 `ocr.engine` 选择。
final class VisionOCREngine: OCREngine {

    func recognize(imageURL: URL) async -> OCRResult {
        guard let image = NSImage(contentsOf: imageURL),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return .failure(OCRError.invalidOutput)
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        // 语言映射自配置（ocr.deepseek.langs）；空配置使用 Vision 默认（跟随系统区域）
        let languages = Self.languages(from: ConfigurationManager.shared.deepseekLanguages)
        if !languages.isEmpty {
            request.recognitionLanguages = languages
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            let text = (request.results ?? [])
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")
            return .success(text)
        } catch {
            return .failure(error)
        }
    }

    /// 配置语言（逗号分隔，如 "zh,en"）→ Vision 识别语言代码（纯函数，便于测试）
    static func languages(from config: String) -> [String] {
        config
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .compactMap { code in
                switch code {
                case "zh": return "zh-Hans"
                case "zh-hans", "zh-hant": return code
                case "en": return "en-US"
                case "ja": return "ja-JP"
                case "ko": return "ko-KR"
                case "fr": return "fr-FR"
                case "de": return "de-DE"
                case "es": return "es-ES"
                default: return nil // Vision 不支持的代码直接跳过
                }
            }
    }
}
