import Foundation

/// 进程内存占用采样（真机回归性能打点用）
enum MemoryFootprint {
    /// 当前物理内存占用（MB）；phys_footprint 与活动监视器「内存」列一致，读取失败返回 nil
    static func currentMB() -> Double? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) { infoPointer in
            infoPointer.withMemoryRebound(to: natural_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS, info.phys_footprint > 0 else { return nil }
        return Double(info.phys_footprint) / 1024 / 1024
    }
}
