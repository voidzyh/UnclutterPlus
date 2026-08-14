# UnclutterPlus iCloud/CloudKit 同步技术调研报告

调研日期：2026-08-14 · 调研方式：Apple 官方一手来源（developer.apple.com 文档/Technote/WWDC、github.com/apple 官方示例），每条事实附来源链接

> 背景：UnclutterPlus 为 macOS 菜单栏浮动面板应用（Swift/SwiftUI，macOS 14+，SwiftPM 可执行目标 + build.sh 打包 .app，非沙盒、无后台模式）。数据域：剪贴板历史（JSON 分片，高频写入）、笔记（JSON 分片，低频）、文件暂存（引用 + 元数据）、截图（图片 + 元数据）。市场调研确认「缺 iCloud 同步」是原版 Unclutter 用户第一大痛点，为本项目头号差异化机会。
>
> 本报告合并自两份分项调研：`icloud_drive_sync_research.md`（iCloud Drive 文件同步）与 `cloudkit-native-ckrecord-research.md`（CloudKit 原生 CKRecord），并补充 NSPersistentCloudKitContainer 评估、配额限制与落地路线。

---

## 1. 结论摘要

**推荐方案：CloudKit 私有数据库 + CKSyncEngine（原生 CKRecord API，不引入 Core Data），首个同步域选「笔记」。**

三个关键理由：

1. **数据模型匹配**：CloudKit 是**记录级**同步，服务端以 `recordChangeTag` 做乐观并发检测、冲突时返回 `serverRecordChanged`（含服务器/客户端/祖先三份记录供合并）——与「逐条笔记」模型天然匹配。iCloud Drive 文件同步是**整文件版本冲突**（`NSFileVersion`），与现有「多 JSON 分片 + 图片 + 元数据」相互关联的文件布局冲突代价高，且必须全量改造读写路径走 `NSFileCoordinator` 才能收到变更。
2. **官方推荐路径**：Apple 现推荐 CKSyncEngine 直接做原生 CKRecord 增量同步（WWDC23 session 10188 + 官方示例 `apple/sample-cloudkit-sync-engine`），封装了 `CKFetchRecordZoneChangesOperation` 等编排，避免自研同步引擎的坑。
3. **工程适配成本最低**：CloudKit 数据访问不要求 App Sandbox，菜单栏/非沙盒应用只需 entitlement（`com.apple.developer.icloud-container-identifiers`）+ 签名即可读写私有数据库；变更推送依赖 APNs，但菜单栏应用无后台模式，**第一版可退化为「启动/激活时增量拉取」**，不阻塞立项。

**不推荐** NSPersistentCloudKitContainer（需为此引入整套 Core Data 栈，现有自研 JSON 分片存储迁移成本 > 收益）；iCloud Drive 文件同步仅作为「单设备为主编辑 + 备份镜像」的低成本备选，不适合剪贴板高频写入。

---

## 2. 四个方案对比

| 维度 | A. CloudKit 私有库 + CKRecord | B. NSPersistentCloudKitContainer | C. iCloud Drive 文件同步 | D. 公共库 / CKShare |
|---|---|---|---|---|
| 同步粒度 | 记录级 | 记录级（由 Core Data 托管） | **整文件版本** | 记录级（app 间共享） |
| 冲突处理 | 服务端 changeTag 检测 + serverRecordChanged 三版本供合并（[recordChangeTag](https://developer.apple.com/documentation/cloudkit/ckrecord/recordchangetag)、[serverRecordChanged](https://developer.apple.com/documentation/cloudkit/ckerror/serverrecordchanged)） | 框架自动（field 级合并） | **自行**用 NSFileVersion 列举/合并/标记 isResolved（[unresolvedConflictVersionsOfItem(at:)](https://developer.apple.com/documentation/foundation/nsfileversion/unresolvedconflictversionsofitem(at:))） | 同 A |
| 前置改造 | 字段映射（模型 → CKRecord）+ change token 持久化 | **引入整个 Core Data 栈**，现有 JSON 分片存储弃用或双写 | 所有读写路径包 NSFileCoordinator + NSMetadataQuery 监听 + NSFilePresenter + 容忍 dataless 文件（[NSFilePresenter](https://developer.apple.com/documentation/foundation/nsfilepresenter)、[URLUbiquitousItemDownloadingStatus](https://developer.apple.com/documentation/foundation/urlubiquitousitemdownloadingstatus)） | 同 A + 共享管理 |
| 剪贴板高频写入适配 | 好（记录级 + savePolicy） | 一般 | **差**（文件级冲突 + 上传等待放大） | 不适用（隐私） |
| 沙盒要求 | 无（[Identifying an App's Containers](https://developer.apple.com/documentation/cloudkit/identifying-an-app-s-containers) 只要求 entitlement） | 无 | 无 | 无 |
| 官方现代示例 | `apple/sample-cloudkit-sync-engine`（[GitHub](https://github.com/apple/sample-cloudkit-sync-engine)） | `apple/sample-cloudkit-coredatasync`（[GitHub](https://github.com/apple/sample-cloudkit-coredatasync)） | 仅归档示例 ShapeEdit（[archive](https://developer.apple.com/library/archive/samplecode/ShapeEdit/)） | `apple/sample-cloudkit-sharing`（[GitHub](https://github.com/apple/sample-cloudkit-sharing)） |
| 适配本项目结论 | ✅ **推荐** | ❌ 成本过高 | ⚠️ 仅备份场景 | 暂不需要 |

### 2.1 方案 A 要点（CloudKit 原生 CKRecord）

- 三种作用域 public/private/shared；多设备同步用 **private database**，要求用户 `accountStatus == .available`（已登录 iCloud）（[CKDatabase.Scope](https://developer.apple.com/documentation/CloudKit/CKDatabase/Scope)、[accountStatus(completionHandler:)](https://developer.apple.com/documentation/cloudkit/ckcontainer/accountstatus(completionhandler:))）。
- 增量同步官方编排：`CKFetchDatabaseChangesOperation`（zone 级变更）+ `CKFetchRecordZoneChangesOperation`（记录级变更，change token 续传）（[CKFetchRecordZoneChangesOperation](https://developer.apple.com/documentation/cloudkit/ckfetchrecordzonechangesoperation)、[CKServerChangeToken](https://developer.apple.com/documentation/CloudKit/CKServerChangeToken)）；**现代推荐直接用 CKSyncEngine**（[CKSyncEngine](https://developer.apple.com/documentation/cloudkit/cksyncengine-5sie5)、[WWDC23 10188](https://developer.apple.com/videos/play/wwdc2023/10188/)）。
- 保存策略：`.ifServerRecordUnchanged`（乐观并发）/ `.changedKeys`（部分字段合并）（[savePolicy](https://developer.apple.com/documentation/cloudkit/ckmodifyrecordsoperation/savepolicy)）。
- 变更推送：CKRecordZoneSubscription/CKDatabaseSubscription + APNs（macOS `NSApplication.registerForRemoteNotifications()`），静默推送配置 `shouldSendContentAvailable`（[CKRecordZoneSubscription](https://developer.apple.com/documentation/cloudkit/ckrecordzonesubscription)、[registerForRemoteNotifications()](https://developer.apple.com/documentation/appkit/nsapplication/registerforremotenotifications())）。

### 2.2 方案 B 要点（NSPersistentCloudKitContainer）

- 定位：Core Data 持久化协调器与 CloudKit 私有库之间的桥，**前提是应用已经用 Core Data**（[NSPersistentCloudKitContainer](https://developer.apple.com/documentation/coredata/nspersistentcloudkitcontainer)）。
- 官方调试指南 TN3164 明确其限制与排障面（含 schema 初始化、配额错误、`deduplicate` 等）——对本项目意味着引入「Core Data 数据模型 + CloudKit schema 部署 + 迁移」整条新链路的运维成本（[TN3164](https://developer.apple.com/documentation/technotes/tn3164-debugging-the-synchronization-of-nspersistentcloudkitcontainer)）。
- 适用判断：若未来计划全面 Core Data 化（搜索/关系查询需求爆发）可重新评估；当前自研分片存储够用，不为此引入。

### 2.3 方案 C 要点（iCloud Drive 文件同步）

详见分项报告 `icloud_drive_sync_research.md`，核心结论：可行但非零成本——整文件版本冲突、必须全量 NSFileCoordinator 化、容忍 dataless、跨分片无原子一致性；**只适合「单设备为主编辑 + 备份镜像」**。

### 2.4 方案 D（公共库 / CKShare）

公共库 = app 级共享空间（所有用户可见），CKShare 用于用户间分享；与「个人数据多设备同步」需求不匹配，本期不做（[CKDatabase](https://developer.apple.com/documentation/cloudkit/ckdatabase)）。

---

## 3. 关键工程事实清单

### 3.1 配额与硬限制（[TN3164](https://developer.apple.com/documentation/technotes/tn3164-debugging-the-synchronization-of-nspersistentcloudkitcontainer)「Avoid hitting a CloudKit limit」）

| 限制 | 数值 |
|---|---|
| 容器内 record zone 数量 | ≤ 1000 |
| 单 record type 字段数 | ≤ 256 |
| 单条 record 大小 | ≤ 1MB（Asset 类型字段除外） |
| 存储总量 | 受用户/应用配额限制（个人 iCloud 空间） |

> 注：Apple 免费额度（asset 存储/数据传输/请求速率）的权威数字在其 CloudKit 产品页（[developer.apple.com/cloudkit](https://developer.apple.com/cloudkit/)，JS 渲染页面），本文未逐字引用；实施期以该页 + CloudKit Console 实测为准。**对本项目量级（万级小文本记录）不会触及这些限制。**

### 3.2 entitlement 与打包（SwiftPM → .app）

- 容器声明键（官方两种命名并存）：新写法 `com.apple.developer.icloud-container-identifiers`（[iCloud Container Identifiers Entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.icloud-container-identifiers)）；旧写法 `com.apple.developer.ubiquity-container-identifiers`（[archive](https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/EnablingiCloud.html)）；开发期容器 `com.apple.developer.icloud-container-development-container-identifiers`（[doc](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.icloud-container-development-container-identifiers)）。
- 容器标识符必须为 `<TEAMID>.<CONTAINER>` 形式（[url(forUbiquityContainerIdentifier:)](https://developer.apple.com/documentation/foundation/filemanager/url(forubiquitycontaineridentifier:))）。
- 工程含义：本项目 `scripts/build.sh` 需新增 `.entitlements` + codesign 注入步骤；本地开发测试用开发期容器键可在本地签名验证（无需 App Store）。**立项前置条件：Apple Developer 账号 + 在 Signing & Capabilities 注册容器（[Configuring iCloud services](https://developer.apple.com/documentation/xcode/configuring-icloud-services)）。**

### 3.3 菜单栏（非沙盒、无后台模式）适用性

- 官方依据：CloudKit 数据访问只要求 entitlement 正确（[Identifying an App's Containers](https://developer.apple.com/documentation/cloudkit/identifying-an-app-s-containers)）；private database 要求已登录 iCloud（[accountStatus(completionHandler:)](https://developer.apple.com/documentation/cloudkit/ckcontainer/accountstatus(completionhandler:))）。
- 工程判断：非沙盒与菜单栏形态**不阻碍** CKRecord 读写；但**静默推送在无后台模式菜单栏应用上的可靠性 Apple 未明确承诺**——第一版同步触发改为「启动时 + 面板唤出时增量拉取」，APNs 推送作为后续增强单独验证。

### 3.4 冲突与合并

- 冲突检测：`CKModifyRecordsOperation.savePolicy = .ifServerRecordUnchanged`；冲突时错误 userInfo 提供 server/client/ancestor 三份记录（[Record Changed Error Keys](https://developer.apple.com/documentation/cloudkit/record-changed-error-keys)）。
- 笔记域建议策略：**last-write-wins（按 modifiedAt 取新）**，避免交互式合并的复杂度；剪贴板/截图等追加型数据基本无冲突。

---

## 4. 推荐落地路线（分阶段）

| 阶段 | 内容 | 前置 | 风险 |
|---|---|---|---|
| **P0 立项验证**（1-2 天） | 注册容器 + .entitlements + build.sh codesign 注入；CloudKit Console 建 schema；私有库读写 smoke 测试（写入/读回/删除一条笔记记录） | Apple Developer 账号 | 低；验证签名链路 |
| **P1 笔记域同步**（核心） | Note ↔ CKRecord 字段映射；CKSyncEngine（或自研 CKFetchRecordZoneChanges 编排）；change token + systemFields 本地持久化（[encodeSystemFields(with:)](https://developer.apple.com/documentation/cloudkit/ckrecord/encodesystemfields(with:))）；启动/唤出增量拉取；last-write-wins | P0 | 中；注意 CKRecord 无 public systemFields 属性、须经 NSCoder 编解码持久化 |
| **P2 截图域（可选）** | 截图元数据入 CKRecord、图片走 CKAsset（≤1MB 外的字段类型限制豁免） | P1 | 中；iCloud 空间占用 |
| **P3 剪贴板域（最末）** | 需评估：隐私默认关闭开关、高频写入节流（本地合并批上传）、排除规则沿用 | P2 | 高；同步风暴与隐私，建议作为独立开关的 opt-in 功能 |
| **P4 推送增强** | APNs + CKRecordZoneSubscription 实测（需真机 + 签名配置） | P1 | 中；非沙盒菜单栏应用需实测 |

**范围外（本期不做）**：Core Data 化、公共库/CKShare、iCloud Drive 镜像、iOS 端。

---

## 5. 参考来源

**官方文档（一手）**
- [CloudKit overview](https://developer.apple.com/documentation/cloudkit/overview) · [CKDatabase](https://developer.apple.com/documentation/cloudkit/ckdatabase) · [CKDatabase.Scope](https://developer.apple.com/documentation/CloudKit/CKDatabase/Scope)
- [CKRecord](https://developer.apple.com/documentation/cloudkit/ckrecord) · [recordChangeTag](https://developer.apple.com/documentation/cloudkit/ckrecord/recordchangetag) · [encodeSystemFields(with:)](https://developer.apple.com/documentation/cloudkit/ckrecord/encodesystemfields(with:))
- [CKModifyRecordsOperation.savePolicy](https://developer.apple.com/documentation/cloudkit/ckmodifyrecordsoperation/savepolicy) · [serverRecordChanged](https://developer.apple.com/documentation/cloudkit/ckerror/serverrecordchanged) · [Record Changed Error Keys](https://developer.apple.com/documentation/cloudkit/record-changed-error-keys)
- [CKFetchRecordZoneChangesOperation](https://developer.apple.com/documentation/cloudkit/ckfetchrecordzonechangesoperation) · [CKFetchDatabaseChangesOperation](https://developer.apple.com/documentation/cloudkit/ckfetchdatabasechangesoperation) · [CKServerChangeToken](https://developer.apple.com/documentation/CloudKit/CKServerChangeToken)
- [CKSyncEngine](https://developer.apple.com/documentation/cloudkit/cksyncengine-5sie5) · [CKSubscription](https://developer.apple.com/documentation/cloudkit/cksubscription) · [CKRecordZoneSubscription](https://developer.apple.com/documentation/cloudkit/ckrecordzonesubscription) · [CKDatabaseSubscription](https://developer.apple.com/documentation/cloudkit/ckdatabasesubscription)
- [registerForRemoteNotifications()](https://developer.apple.com/documentation/appkit/nsapplication/registerforremotenotifications()) · [application(_:didReceiveRemoteNotification:)](https://developer.apple.com/documentation/appkit/nsapplicationdelegate/application(_:didreceiveremotenotification:))
- [NSPersistentCloudKitContainer](https://developer.apple.com/documentation/coredata/nspersistentcloudkitcontainer) · [TN3164: Debugging the synchronization of NSPersistentCloudKitContainer](https://developer.apple.com/documentation/technotes/tn3164-debugging-the-synchronization-of-nspersistentcloudkitcontainer)
- [Identifying an App's Containers](https://developer.apple.com/documentation/cloudkit/identifying-an-app-s-containers) · [accountStatus(completionHandler:)](https://developer.apple.com/documentation/cloudkit/ckcontainer/accountstatus(completionhandler:)) · [Configuring iCloud services](https://developer.apple.com/documentation/xcode/configuring-icloud-services)
- [iCloud Container Identifiers Entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.icloud-container-identifiers) · [com.apple.developer.icloud-container-development-container-identifiers](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.icloud-container-development-container-identifiers)
- iCloud Drive 系：[url(forUbiquityContainerIdentifier:)](https://developer.apple.com/documentation/foundation/filemanager/url(forubiquitycontaineridentifier:)) · [setUbiquitous(_:itemAt:destinationURL:)](https://developer.apple.com/documentation/foundation/filemanager/setubiquitous(_:itemat:destinationurl:)) · [NSFilePresenter](https://developer.apple.com/documentation/foundation/nsfilepresenter) · [NSFileVersion](https://developer.apple.com/documentation/foundation/nsfileversion) · [Synchronizing documents in the iCloud environment](https://developer.apple.com/documentation/uikit/synchronizing-documents-in-the-icloud-environment) · [URLUbiquitousItemDownloadingStatus](https://developer.apple.com/documentation/foundation/urlubiquitousitemdownloadingstatus)

**WWDC**
- [Sync to iCloud with CKSyncEngine · WWDC23 10188](https://developer.apple.com/videos/play/wwdc2023/10188/) · [What's new in CloudKit · WWDC21 10086](https://developer.apple.com/videos/play/wwdc2021/10086/)

**官方示例（github.com/apple）**
- [sample-cloudkit-sync-engine](https://github.com/apple/sample-cloudkit-sync-engine) · [sample-cloudkit-privatedb-sync](https://github.com/apple/sample-cloudkit-privatedb-sync) · [sample-cloudkit-coredatasync](https://github.com/apple/sample-cloudkit-coredatasync) · [sample-cloudkit-sharing](https://github.com/apple/sample-cloudkit-sharing)

**分项报告**
- [iCloud Drive 文件同步调研](icloud_drive_sync_research.md) · [CloudKit 原生 CKRecord 事实清单](cloudkit-native-ckrecord-research.md)
