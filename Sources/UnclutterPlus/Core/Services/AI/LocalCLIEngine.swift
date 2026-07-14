import Foundation

/// 本地 CLI 引擎 —— 调用 ollama 等本地命令行模型工具。
///
/// 复用 DeepseekOCREngine 的 Process+Pipe+waitUntilExit 模式。
/// 无需网络与密钥，隐私性好，但依赖用户本地已安装模型。
final class LocalCLIEngine: AIService {
    var displayName: String { "Local CLI (\(cliModel))" }

    private let cliPath: String
    private let cliModel: String
    private let timeout: TimeInterval

    init(cliPath: String, cliModel: String, timeout: TimeInterval = 120) {
        self.cliPath = cliPath
        self.cliModel = cliModel
        self.timeout = timeout
    }

    // MARK: - AIService

    func organize(content: String, instruction: OrganizeInstruction) async throws -> OrganizeResult {
        let prompt = HTTPAPIEngine.makeOrganizePrompt(content: content, action: instruction.action, context: instruction.context)
        switch instruction.action {
        case .titleAndSummary, .autoTag:
            let raw = try await run(system: "你是笔记整理助手。只输出 JSON。", user: prompt)
            // 复用 HTTPAPIEngine 的解码逻辑
            return try HTTPAPIEngine.decodeOrganize(raw: raw, action: instruction.action, fallbackContent: content)
        case .polish, .rewrite:
            let text = try await run(system: "你是文字编辑助手，直接输出整理后的正文。", user: prompt)
            return OrganizeResult(content: text.trimmingCharacters(in: .whitespacesAndNewlines), title: nil, summary: nil, tags: [])
        }
    }

    func cluster(items: [String], existingTopics: [String]) async throws -> [AICluster] {
        let prompt = HTTPAPIEngine.makeClusterPrompt(items: items, existingTopics: existingTopics)
        let raw = try await run(system: "你是知识整理助手，只输出 JSON。", user: prompt)
        return try HTTPAPIEngine.decodeClusters(raw: raw)
    }

    func summarize(cluster: AICluster) async throws -> DocumentDraft {
        let prompt = HTTPAPIEngine.makeSummarizePrompt(cluster: cluster)
        let raw = try await run(system: "你是技术文档撰写助手，输出 Markdown，最终用 JSON 包裹。", user: prompt)
        return try HTTPAPIEngine.decodeSummary(raw: raw, cluster: cluster)
    }

    // MARK: - CLI 执行

    /// 运行 ollama run <model>，通过 stdin 传入 prompt，捕获 stdout。
    private func run(system: String, user: String) async throws -> String {
        guard !cliPath.isEmpty else { throw AIServiceError.notConfigured }

        guard FileManager.default.fileExists(atPath: cliPath) else {
            throw AIServiceError.notConfigured
        }
        guard FileManager.default.isExecutableFile(atPath: cliPath) else {
            throw AIServiceError.executionFailed("CLI 不可执行：\(cliPath)")
        }

        // ollama run <model> 从 stdin 读入，输出到 stdout
        // 完整 prompt = system + user
        let fullPrompt = "\(system)\n\n\(user)"

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: cliPath)
            process.arguments = ["run", self.cliModel]

            let inputPipe = Pipe()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardInput = inputPipe
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            // 写入 prompt
            inputPipe.fileHandleForWriting.writeabilityHandler = { handle in
                if let data = fullPrompt.data(using: .utf8) {
                    handle.write(data)
                }
                handle.closeFile()
                inputPipe.fileHandleForWriting.writeabilityHandler = nil
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: AIServiceError.executionFailed(error.localizedDescription))
                return
            }

            // 超时保护
            let workItem = DispatchWorkItem {
                if process.isRunning {
                    process.terminate()
                }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + self.timeout, execute: workItem)

            // 异步等待进程结束
            DispatchQueue.global().async {
                process.waitUntilExit()
                workItem.cancel()

                if process.terminationStatus != 0 {
                    let errData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errMsg = String(data: errData, encoding: .utf8) ?? "未知错误"
                    continuation.resume(throwing: AIServiceError.executionFailed("exit \(process.terminationStatus): \(errMsg)"))
                    return
                }

                let outData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outData, encoding: .utf8) ?? ""
                continuation.resume(returning: output)
            }
        }
    }
}
