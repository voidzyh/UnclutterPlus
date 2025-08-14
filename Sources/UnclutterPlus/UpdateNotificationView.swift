import SwiftUI

struct UpdateNotificationView: View {
    @ObservedObject var updateManager = UpdateManager.shared
    @State private var isExpanded = false
    
    var body: some View {
        if let updateInfo = updateManager.updateInfo,
           updateInfo.isNewerThanCurrent {
            VStack(alignment: .leading, spacing: 12) {
                // 标题栏
                HStack {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("update.available.title".localized)
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("update.available.subtitle".localized + " \(updateInfo.displayVersion)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                
                // 展开的详细信息
                if isExpanded {
                    VStack(alignment: .leading, spacing: 8) {
                        // 版本信息
                        HStack {
                            Text("update.info.version".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(updateInfo.displayVersion)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        
                        // 发布日期
                        HStack {
                            Text("update.info.release_date".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(formatReleaseDate(updateInfo.releaseDate))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // 更新说明
                        if !updateInfo.releaseNotes.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("update.info.release_notes".localized)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                
                                Text(updateInfo.releaseNotes)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .lineLimit(5)
                                    .textSelection(.enabled)
                            }
                            .padding(.top, 4)
                        }
                        
                        Divider()
                        
                        // 操作按钮
                        HStack(spacing: 12) {
                            Button(action: {
                                updateManager.downloadUpdate()
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.down.circle")
                                    Text("update.action.download".localized)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Button(action: {
                                updateManager.skipCurrentVersion()
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "xmark.circle")
                                    Text("update.action.skip".localized)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(16)
            .background(Color.green.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.green.opacity(0.2), lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.2), value: isExpanded)
        }
    }
    
    private func formatReleaseDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            return date.formatted(.relative(presentation: .named))
        }
        return dateString
    }
}

// MARK: - Update Notification Sheet
struct UpdateNotificationSheet: View {
    @ObservedObject var updateManager = UpdateManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let updateInfo = updateManager.updateInfo {
                    // 更新图标
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.green)
                    
                    // 标题
                    VStack(spacing: 8) {
                        Text("update.available.title".localized)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("update.available.subtitle".localized + " \(updateInfo.displayVersion)")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    
                    // 版本信息
                    VStack(spacing: 12) {
                        HStack {
                            Text("update.info.current_version".localized)
                            Spacer()
                            Text("v\(currentAppVersion)")
                                .fontWeight(.medium)
                        }
                        
                        HStack {
                            Text("update.info.new_version".localized)
                            Spacer()
                            Text(updateInfo.displayVersion)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                        }
                        
                        HStack {
                            Text("update.info.release_date".localized)
                            Spacer()
                            Text(formatReleaseDate(updateInfo.releaseDate))
                        }
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                    
                    // 更新说明
                    if !updateInfo.releaseNotes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("update.info.release_notes".localized)
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            ScrollView {
                                Text(updateInfo.releaseNotes)
                                    .textSelection(.enabled)
                            }
                            .frame(maxHeight: 200)
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                    }
                    
                    Spacer()
                    
                    // 操作按钮
                    VStack(spacing: 12) {
                        Button(action: {
                            updateManager.downloadUpdate()
                            dismiss()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.down.circle")
                                Text("update.action.download".localized)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button(action: {
                            updateManager.skipCurrentVersion()
                            dismiss()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "xmark.circle")
                                Text("update.action.skip".localized)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.secondary)
                    }
                } else {
                    // 无更新可用
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.green)
                        
                        Text("update.no_update.title".localized)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("update.no_update.subtitle".localized)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("common.close".localized) {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding(24)
            .frame(width: 500, height: 600)
            .navigationTitle("update.navigation.title".localized)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("common.close".localized) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func formatReleaseDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            return date.formatted(date: .abbreviated, time: .omitted)
        }
        return dateString
    }
}

#if DEBUG && canImport(SwiftUI) && canImport(PreviewsMacros)
#Preview {
    UpdateNotificationView()
        .frame(width: 400, height: 300)
        .padding()
}
#endif
