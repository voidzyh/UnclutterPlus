import Foundation

class DeepseekOCREngine: OCREngine {
    private let config = ConfigurationManager.shared
    
    func recognize(imageURL: URL) async -> OCRResult {
        // 检查是否配置了二进制路径
        guard !config.deepseekBinaryPath.isEmpty else {
            return .failure(OCRError.binaryNotConfigured)
        }
        
        let binaryPath = config.deepseekBinaryPath
        let languages = config.deepseekLanguages
        
        // 检查二进制文件是否存在
        guard FileManager.default.fileExists(atPath: binaryPath) else {
            return .failure(OCRError.binaryNotFound)
        }
        
        // 检查文件是否可执行
        guard FileManager.default.isExecutableFile(atPath: binaryPath) else {
            return .failure(OCRError.binaryNotExecutable)
        }
        
        // 构建命令
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = [
            "--image", imageURL.path,
            "--lang", languages,
            "--format", "json"
        ]
        
        // 设置输出管道
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus != 0 {
                // 读取错误信息
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                return .failure(OCRError.executionFailed(errorString))
            }
            
            // 读取输出
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            
            // 解析 JSON
            guard let json = try? JSONSerialization.jsonObject(with: outputData) as? [String: Any],
                  let text = json["text"] as? String else {
                // 尝试直接读取文本
                if let text = String(data: outputData, encoding: .utf8), !text.isEmpty {
                    return .success(text.trimmingCharacters(in: .whitespacesAndNewlines))
                }
                return .failure(OCRError.invalidOutput)
            }
            
            return .success(text.trimmingCharacters(in: .whitespacesAndNewlines))
            
        } catch {
            return .failure(error)
        }
    }
}

enum OCRError: LocalizedError {
    case binaryNotConfigured
    case binaryNotFound
    case binaryNotExecutable
    case executionFailed(String)
    case invalidOutput
    
    var errorDescription: String? {
        switch self {
        case .binaryNotConfigured:
            return "DeepSeek OCR binary path is not configured"
        case .binaryNotFound:
            return "DeepSeek OCR binary not found at specified path"
        case .binaryNotExecutable:
            return "DeepSeek OCR binary is not executable"
        case .executionFailed(let message):
            return "OCR execution failed: \(message)"
        case .invalidOutput:
            return "Invalid OCR output format"
        }
    }
}
