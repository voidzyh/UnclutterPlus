import SwiftUI

/// 剪贴板智能洞察面板 —— 展示高频项排行 + AI 聚类 + 生成的学习文档草稿。
///
/// 数据来自 ClipboardInsightEngine。用户点"生成洞察"触发 AI 批处理：
/// 高频项（频率统计）→ AI 相似聚类 → 每组总结成文档 → 可导出 Obsidian。
struct InsightsView: View {
    @StateObject private var engine = ClipboardInsightEngine.shared
    @State private var showExportSuccess = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            contentScroll
        }
        .background(ModernDesignSystem.shared.color(.bgCanvas))
        .onAppear {
            engine.refreshHighFrequencyItems()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("clipboard.insights.title".localized)
                    .font(.headline)
                Text("clipboard.insights.subtitle".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            statusLabel

            Button(action: triggerGenerate) {
                Label("clipboard.insights.generate".localized, systemImage: "sparkles")
            }
            .buttonStyle(.borderedProminent)
            .disabled(isBusy)
            .help("clipboard.insights.generate.help".localized)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch engine.status {
        case .idle:
            EmptyView()
        case .analyzing(let stage):
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text(stage.rawValue).font(.caption).foregroundColor(.secondary)
            }
        case .completed:
            Label("clipboard.insights.completed".localized, systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(.green)
        case .failed:
            Label("clipboard.insights.failed".localized, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundColor(.red)
        }
    }

    private var isBusy: Bool {
        if case .analyzing = engine.status { return true }
        return false
    }

    // MARK: - Content

    private var contentScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let err = engine.lastError {
                    errorBanner(err)
                }

                highFrequencySection
                if !engine.clusters.isEmpty { clustersSection }
                if !engine.drafts.isEmpty { draftsSection }
            }
            .padding(16)
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
            Text(message).font(.caption)
            Spacer()
            Button("common.dismiss".localized) { engine.lastError = nil }
                .buttonStyle(.borderless).font(.caption)
        }
        .padding(10)
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - 高频项

    private var highFrequencySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("clipboard.insights.frequent".localized)
                .font(.subheadline.bold())
                .foregroundColor(.secondary)

            if engine.highFrequencyItems.isEmpty {
                Text("clipboard.insights.frequent.empty".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                ForEach(engine.highFrequencyItems.prefix(20)) { item in
                    HStack(spacing: 10) {
                        Text("\(item.useCount)")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .frame(width: 28, height: 20)
                            .background(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 4))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.text)
                                .font(.caption)
                                .lineLimit(2)
                                .truncationMode(.tail)
                            if let app = item.sourceAppName {
                                Text(app).font(.caption2).foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - 聚类

    private var clustersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("clipboard.insights.clusters".localized)
                .font(.subheadline.bold())
                .foregroundColor(.secondary)

            ForEach(engine.clusters) { cluster in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "folder").foregroundColor(.accentColor)
                        Text(cluster.topic).font(.caption.bold())
                    }
                    Text(cluster.description).font(.caption2).foregroundColor(.secondary)
                    Text("\(cluster.items.count) " + "clipboard.insights.items".localized)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ModernDesignSystem.shared.color(.bgSurface))
                .cornerRadius(8)
            }
        }
    }

    // MARK: - 文档草稿（可导出 Obsidian）

    private var draftsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("clipboard.insights.drafts".localized)
                .font(.subheadline.bold())
                .foregroundColor(.secondary)

            ForEach(engine.drafts) { draft in
                DraftRow(draft: draft, onExport: {
                    exportDraft(draft)
                })
            }
        }
    }

    private func exportDraft(_ draft: DocumentDraft) {
        do {
            let result = try ObsidianExporter.export(draft: draft, openInObsidian: true)
            logger.info("已导出到 Obsidian：\(result.fileURL.path)", category: "InsightsView")
            showExportSuccess = true
        } catch {
            engine.lastError = error.localizedDescription
        }
    }

    // MARK: - 触发

    private func triggerGenerate() {
        engine.generateInsights()
    }
}

// MARK: - 文档草稿行

private struct DraftRow: View {
    let draft: DocumentDraft
    let onExport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "doc.text").foregroundColor(.accentColor)
                Text(draft.title).font(.caption.bold())
                Spacer()
                Button(action: onExport) {
                    Label("clipboard.obsidian.export".localized, systemImage: "arrow.up.doc")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            if !draft.tags.isEmpty {
                HStack {
                    ForEach(draft.tags.prefix(5), id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.caption2)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.15))
                            .cornerRadius(4)
                    }
                }
            }
            Text(draft.content)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(4)
                .truncationMode(.tail)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ModernDesignSystem.shared.color(.bgSurface))
        .cornerRadius(8)
    }
}
