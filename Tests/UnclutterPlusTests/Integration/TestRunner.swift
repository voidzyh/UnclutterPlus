import Foundation
import SwiftUI

/// 集成测试运行器
@MainActor
struct IntegrationTestRunner: View {
    @StateObject private var testManager = TestExecutionManager.shared
    @State private var selectedTestType: TestType = .notesService
    @State private var isRunning = false
    
    var body: some View {
        VStack(spacing: 20) {
            // 标题
            Text("架构集成测试运行器")
                .font(.title)
                .fontWeight(.bold)
            
            // 测试类型选择
            Picker("测试类型", selection: $selectedTestType) {
                ForEach(TestType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            
            // 测试控制
            HStack(spacing: 15) {
                Button("运行测试") {
                    runSelectedTests()
                }
                .disabled(isRunning)
                
                Button("运行所有集成测试") {
                    runAllIntegrationTests()
                }
                .disabled(isRunning)
                
                if isRunning {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            // 测试结果显示
            Group {
                if isRunning {
                    VStack {
                        Text("正在运行测试...")
                        ProgressView()
                        Text("当前测试: \(testManager.currentTest ?? "准备中...")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    TestResultsView()
                }
            }
            .frame(maxHeight: 300)
            
            Spacer()
        }
        .padding()
        .frame(width: 600, height: 500)
    }
    
    // MARK: - Actions
    
    private func runSelectedTests() {
        Task {
            await MainActor.run {
                isRunning = true
            }
            
            switch selectedTestType {
            case .notesService:
                await runNotesServiceTests()
            case .storage:
                await runStorageTests()
            case .cache:
                await runCacheTests()
            case .errorHandling:
                await runErrorHandlingTests()
            case .security:
                await runSecurityTests()
            case .performance:
                await runPerformanceTests()
            case .memory:
                await runMemoryTests()
            case .multiComponent:
                await runMultiComponentTests()
            }
            
            await MainActor.run {
                isRunning = false
            }
        }
    }
    
    private func runAllIntegrationTests() {
        Task {
            await MainActor.run {
                isRunning = true
            }
            
            let statistics = await testManager.runCoreComponentTests()
            
            await MainActor.run {
                isRunning = false
            }
        }
    }
    
    // MARK: - Individual Test Runners
    
    private func runNotesServiceTests() async {
        _ = await testManager.runNotesServiceTests()
    }
    
    private func runStorageTests() async {
        _ = await testManager.runStorageIntegrationTests()
    }

    private func runCacheTests() async {
        _ = await testManager.runCacheIntegrationTests()
    }

    private func runErrorHandlingTests() async {
        _ = await testManager.runErrorHandlingIntegrationTests()
    }

    private func runSecurityTests() async {
        _ = await testManager.runSecurityIntegrationTests()
    }

    private func runPerformanceTests() async {
        _ = await testManager.runPerformanceBenchmarks()
    }

    private func runMemoryTests() async {
        _ = await testManager.runMemoryIntegrationTests()
    }

    private func runMultiComponentTests() async {
        _ = await testManager.runMultiComponentIntegrationTests()
    }
}

// MARK: - Supporting Views

struct TestResultsView: View {
    @ObservedObject var testManager = TestExecutionManager.shared
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("测试结果")
                .font(.headline)
            
            if testManager.testResults.isEmpty {
                Text("暂无测试结果")
                    .foregroundColor(.secondary)
            } else {
                List(testManager.testResults.prefix(10), id: \.id) { result in
                    HStack {
                        Image(systemName: result.status.icon)
                            .foregroundColor(result.status.color)
                        
                        VStack(alignment: .leading) {
                            Text(result.testName)
                                .font(.body)
                            
                            Text(result.suiteName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()

                        Text(String(format: "%.3fs", result.duration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if testManager.testResults.count > 10 {
                    Text("显示前10个结果，共\(testManager.testResults.count)个")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Test Types

enum TestType: String, CaseIterable, Identifiable {
    case notesService = "notes_service"
    case storage = "storage"
    case cache = "cache"
    case errorHandling = "error_handling"
    case security = "security"
    case performance = "performance"
    case memory = "memory"
    case multiComponent = "multi_component"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .notesService: return "笔记服务"
        case .storage: return "存储系统"
        case .cache: return "缓存系统"
        case .errorHandling: return "错误处理"
        case .security: return "安全管理"
        case .performance: return "性能测试"
        case .memory: return "内存管理"
        case .multiComponent: return "多组件协作"
        }
    }
}

// MARK: - Preview

#if DEBUG
struct IntegrationTestRunner_Previews: PreviewProvider {
    static var previews: some View {
        IntegrationTestRunner()
    }
}
#endif
