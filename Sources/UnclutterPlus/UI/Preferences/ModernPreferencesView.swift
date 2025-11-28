import SwiftUI

/// 现代化首选项视图 - 简化版本以修复构建错误
struct ModernPreferencesView: View {
    var body: some View {
        VStack {
            Text("UnclutterPlus Preferences")
                .font(.largeTitle)
                .padding()
            
            Text("Settings will be implemented here")
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .frame(minWidth: 600, minHeight: 500)
    }
}