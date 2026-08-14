# UnclutterPlus iCloud/CloudKit 同步技术调研

调研日期：2026-08-14 · 调研方式：Apple 官方文档（developer.apple.com/documentation/cloudkit、/coredata、/foundation、/appkit）、Apple 账号帮助、Apple 技术说明（TN3162/3163/3164）、WWDC 官方 session、GitHub apple 组织官方示例。所有论断附可追溯来源，无法落到官方页面的部分显式标注「未找到官方来源 / 工程判断」。

> 背景：UnclutterPlus 为 macOS 菜单栏浮动面板应用（Swift/SwiftUI，macOS 14+，SwiftPM 可执行目标 + build.sh 打包 .app，非沙盒、无后台模式）。数据域：剪贴板历史（JSON 分片，高频写入）、Markdown 笔记（JSON 分片，低频）、文件暂存（引用 + JSON 元数据）、截图（图片 + JSON 元数据）。市场调研确认「缺 iCloud 同步」是原版 Unclutter 用户第一大痛点，为本项目头号差异化机会。

---

## 一、结论摘要

推荐 **CloudKit 私有数据库 + 原生 CKRecord API**（增量同步优先用 **CKSyncEngine**），作为 UnclutterPlus 的跨设备同步方案：

1. **开发者零存储成本**：私有数据库的数据存在用户自己的 iCloud 账号里（[CKContainer](https://developer.apple.com/documentation/cloudkit/ckcontainer)），不占开发者配额，天然匹配「同一 Apple ID 多台 Mac」的场景。
2. **对现有存储侵入最小**：CloudKit 官方明确「不是现有数据对象的替代品，而是传输数据的互补层」（[CloudKit](https://developer.apple.com/documentation/cloudkit)）——本地 JSON 分片保持原样，只需在其上叠一层同步器 + 记录 change tag，不用重写存储层。
3. **冲突模型最契合**：记录级乐观并发（`recordChangeTag` + `savePolicy=.ifServerRecordUnchanged`）与「JSON 分片 + 图片元数据」的记录粒度一致；相比之下 iCloud Drive 是「整文件版本冲突」、NSPersistentCloudKitContainer 要求为它引入整套 Core Data 栈（建模 + 数据搬迁 + 模型版本化），对没有 Core Data 的项目收益不匹配。

首发阶段建议**先同步笔记**（写入频率低、敏感度低、结构简单），剪贴板与文件/截图后置，并提前在 build.sh 补上 entitlements + 签名这一地基。

---

## 二、四个方案的机制 / 限制 / 利弊

### 方案对比总表

| 维度 | A. CloudKit 私有库 + CKRecord（推荐） | B. NSPersistentCloudKitContainer | C. iCloud Drive（ubiquity 容器） | D. 公共库 / CKShare |
|---|---|---|---|---|
| 机制 | 直接读写 `CKRecord`，用 `CKFetchRecordZoneChangesOperation`/CKSyncEngine 增量同步 | Core Data 栈自动镜像到 CloudKit 私有库 | 把文件目录放进 ubiquity 容器，系统同步文件 | 公共库全用户可见；CKShare 分享私有库记录 |
| 数据粒度 | 记录级（可逐条增删改） | 托管对象级（由 Core Data 建模） | **整文件级**（无跨文件原子性） | 记录级 |
| 冲突解决 | 服务端 change tag + 三副本合并（乐观并发） | 系统自动合并（server truth），细节不可控 | `NSFileVersion` 整文件版本，需自行合并 | 同 A（分享场景参与者可写） |
| 变更通知 | CKSubscription + APNs 静默推送 | 系统后台任务自动 import/export | `NSMetadataQuery` 轮询/通知 | 公共库无推送、需轮询 |
| 开发者成本 | 私有库 = 用户 iCloud 配额，免费 | 同左（私有库） | 用户 iCloud Drive 配额 | 公共库计入开发者配额 |
| 现有代码改动 | 低（叠一层同步器） | **极高**（新建 Core Data 栈 + 数据搬迁） | 中高（所有读写改走 NSFileCoordinator） | 低（复用 A 的基础） |
| 适配本项目 | ✅ 最佳 | ❌ 收益不匹配 | ⚠️ 仅适合「备份/单机为主」 | 部分适用（分享/公共内容） |

### 方案 A：CloudKit 私有数据库 + 原生 CKRecord API（无 Core Data）

**机制**：把每一条剪贴板条目 / 笔记 / 文件元数据映射为一条 `CKRecord`，存进 `CKContainer.default().privateCloudDatabase`。本地仍是 JSON 分片，同步器把本地变更 save 到云端、用 `CKFetchRecordZoneChangesOperation` 按 zone 增量拉取远端变更并合并回本地（[CKFetchRecordZoneChangesOperation](https://developer.apple.com/documentation/cloudkit/ckfetchrecordzonechangesoperation)、[CKServerChangeToken](https://developer.apple.com/documentation/cloudkit/ckserverchangetoken)）。Apple 现推荐用 **CKSyncEngine** 直接编排这套增量同步（[CKSyncEngine](https://developer.apple.com/documentation/cloudkit/cksyncengine-5sie5)、[WWDC23 session 10188](https://developer.apple.com/videos/play/wwdc2023/10188/)）。

**限制**：CloudKit「只提供极小的离线缓存，依赖网络存在」（[CloudKit](https://developer.apple.com/documentation/cloudkit)）——必须保留本地存储作为离线主存储，云端只是同步层；冲突需自己用 `savePolicy` + 三副本合并处理。

**利弊**：✅ 粒度与现有分片存储一致、迁移成本低、私有库免费、记录级冲突可控、可平滑演进到 CKShare/公共库；❌ 同步编排（change token、错误重试、订阅）要自己写，不如方案 B「开箱即用」。

### 方案 B：NSPersistentCloudKitContainer（需引入 Core Data 栈）

**机制**：`NSPersistentCloudKitContainer` 是 `NSPersistentContainer` 子类，把选定的 SQLite store 自动镜像到 CloudKit 私有库，import/export 由系统后台任务完成，应用无需写同步代码（[NSPersistentCloudKitContainer](https://developer.apple.com/documentation/coredata/nspersistentcloudkitcontainer)、[TN3163](https://developer.apple.com/documentation/technotes/tn3163-understanding-the-synchronization-of-nspersistentcloudkitcontainer)）。

**限制**：持久化存储必须是 SQLite；数据模型必须兼容 CloudKit 限制——**不支持 unique constraint、undefined 属性类型、required relationship、ordered relationship**；模型必须完整镜像到 CloudKit schema，schema 部署到 production 后不可删/改字段；**不能复用已在用的 CloudKit container**（[Mirroring a Core Data store with CloudKit](https://developer.apple.com/documentation/coredata/mirroring-a-core-data-store-with-cloudkit)）。同步时机由系统决定、无 API 控制，限流（throttle）可能持续数小时（[TN3164](https://developer.apple.com/documentation/technotes/tn3164-debugging-the-synchronization-of-nspersistentcloudkitcontainer)）。

**利弊**：✅ 同步、冲突、离线、跨设备私有库镜像全自动，还可扩展 public/shared 库与 CKShare 分享（[Sharing Core Data objects between iCloud users](https://developer.apple.com/documentation/coredata/sharing-core-data-objects-between-icloud-users)）；❌ 对一个「现有 JSON 分片、完全没有 Core Data 栈」的项目，接入成本主要落在**新建整套 Core Data 数据模型 + SQLite store + 现有数据全量搬迁 + 持续的模型版本化**，而非「接 API」。**工程判断：高迁移成本、收益不匹配**，除非项目数据本就是高度结构化关系数据且愿意长期接受 Core Data 模型约束。

### 方案 C：iCloud Drive 文件同步（NSFileCoordinator + ubiquity 容器）

**机制**：把现有存储目录放进 ubiquity 容器（`FileManager.url(forUbiquityContainerIdentifier:)` + 直接写容器目录或 `setUbiquitous`），系统自动上传/按需下载（非全量镜像），用 `NSFileCoordinator` 协调读写、`NSMetadataQuery` 监听远端变更、`NSFileVersion` 解决冲突（[url(forUbiquityContainerIdentifier:)](https://developer.apple.com/documentation/foundation/filemanager/url(forubiquitycontaineridentifier:))、[NSFileCoordinator](https://developer.apple.com/documentation/foundation/nsfilecoordinator)、[NSMetadataQuery](https://developer.apple.com/documentation/foundation/nsmetadataquery)、[NSFileVersion](https://developer.apple.com/documentation/foundation/nsfileversion)）。

**限制与可行性判断**：官方允许任意文件/目录进容器，「直接把现有目录放进去」**机制上可行**；但 iCloud Drive 的冲突是**整文件版本冲突**（[Designing for Documents in iCloud（archive）](https://developer.apple.com/library/archive/documentation/General/Conceptual/iCloudDesignGuide/Chapters/DesigningForDocumentsIniCloud.html)），对「多个 JSON 分片 + 图片 + JSON 元数据」这组相互关联的文件，系统**逐文件独立产生版本、不保证跨文件原子一致性**；多设备并发编辑会在文件粒度各自冲突，需自行用 `NSFileVersion` 合并；且必须改造**所有**读写路径走 `NSFileCoordinator`（官方明确「只有经过 file coordinator 的变更才会触发通知」——[NSFilePresenter](https://developer.apple.com/documentation/foundation/nsfilepresenter)），并容忍文件处于未下载（dataless）状态。

**利弊**：✅ 对「备份/镜像 + 单机为主编辑」低成本可行，文件对用户可见（可放进 iCloud Drive）；❌ 对「多设备同时编辑、期望自动合并」代价高，剪贴板这类高频小写入会放大「文件级冲突 + 上传等待」的组合成本。**工程判断：不适合作为主同步方案；可作为「导出/备份到 iCloud Drive」的附加功能。**

### 方案 D：公共数据库 / CKShare

**机制**：公共数据库「所有用户可见、免登录即可读、写需登录」，数据计入**开发者**配额（[CKContainer.publicCloudDatabase](https://developer.apple.com/documentation/cloudkit/ckcontainer/publicclouddatabase)、[CKContainer](https://developer.apple.com/documentation/cloudkit/ckcontainer)）；`CKShare` 把私有库 custom zone 的记录分享给他人（[CKShare](https://developer.apple.com/documentation/cloudkit/ckshare)），macOS 分享 UI 用 `NSCloudSharingServiceDelegate`（[NSCloudSharingServiceDelegate](https://developer.apple.com/documentation/AppKit/NSCloudSharingServiceDelegate)）。

**适用性**：本项目的跨设备同步是「同一用户多台设备」，**应走私有数据库而非公共库**（公共库不隔离用户、且占开发者配额）。CKShare 适用于「把某条笔记/暂存文件分享给另一个 iCloud 用户」这类协作场景，非首发必需，可作为后续扩展；注意 CKShare 要求记录在 custom zone（默认 zone 不能共享），且一条记录只能属于一个 share（[CKShare](https://developer.apple.com/documentation/cloudkit/ckshare)）。

---

## 三、关键工程事实清单

### 3.1 CloudKit 配额与限制

- **私有库 = 用户 iCloud 配额，开发者零成本**：「CloudKit always stores private data in the appropriate container directory in the user's iCloud account.」（[CKContainer](https://developer.apple.com/documentation/cloudkit/ckcontainer)）；公共库「Data in the public database counts toward your app's iCloud storage quota.」（[CKContainer.publicCloudDatabase](https://developer.apple.com/documentation/cloudkit/ckcontainer/publicclouddatabase)）。
- **公共库容量**：现行官方概览页称「get up to 1PB of storage for your app's public data」（[CloudKit 概览](https://developer.apple.com/icloud/cloudkit/)）。
- **历史免费额度**（⚠️ 2016 年官方公开页，现行页已撤下数字，需在 CloudKit Console 查看当前额度）：asset 10 GB、database 100 MB、数据传输 2 GB/天、40 req/s；多 container 不叠加；超额计费（[iCloud — 2016 快照](https://web.archive.org/web/20160304012435/https://developer.apple.com/icloud/)）。
- **硬限制**（现行官方文档）：
  - 单条 `CKRecord` ≤ **1 MB**（`CKAsset` 字段不计入）（[CKRecord](https://developer.apple.com/documentation/cloudkit/ckrecord)）。
  - 单次操作 ≤ **400 条记录/共享**；单次请求 ≤ **2 MB（不计 asset）**；命中 `limitExceeded` 需「对半拆分重试」（[CKError.limitExceeded](https://developer.apple.com/documentation/cloudkit/ckerror/limitexceeded)）。
  - 每个 container 最多 **1000 个 record zone**、每个 record type 最多 **256 个字段**、单条 record ≤ 1 MB（CKAsset 除外）、存储受用户/App 配额限制（[TN3164](https://developer.apple.com/documentation/technotes/tn3164-debugging-the-synchronization-of-nspersistentcloudkitcontainer)）。
  - `CKAsset` 用于「字段值超过几 KB」的内容，官方**未公布单个 asset 大小上限**（[CKAsset](https://developer.apple.com/documentation/cloudkit/ckasset)）。
  - `CKSubscription` 数量上限、每 zone 记录数上限：**未找到官方来源**。
- **速率限制**：CloudKit 是共享基础设施，会限流（throttle），返回 `requestRateLimited` + `retryAfter` 秒数；官方建议减少操作次数、每个操作都处理错误、非关键操作用后台任务调度（[TN3162: Understanding CloudKit throttles](https://developer.apple.com/documentation/technotes/tn3162-understanding-cloudkit-throttles)）；硬性速率阈值**官方未公布**（「The server can change its limits at any time」——[CKError.limitExceeded](https://developer.apple.com/documentation/cloudkit/ckerror/limitexceeded)）。

### 3.2 冲突解决机制

- **记录版本标记**：`CKRecord.recordChangeTag` 是服务器每次保存后更新的「版本标记」，用于乐观并发（[recordChangeTag](https://developer.apple.com/documentation/cloudkit/ckrecord/recordchangetag)）。⚠️ 命名修正：change tag 属于 `CKRecord`，`CKRecord.ID` 没有该属性。
- **保存策略** `CKModifyRecordsOperation.savePolicy`（[savePolicy](https://developer.apple.com/documentation/cloudkit/ckmodifyrecordsoperation/savepolicy)）：
  - `.ifServerRecordUnchanged`：仅当服务器版本自上次读取后未变才保存，否则返回冲突（[ifServerRecordUnchanged](https://developer.apple.com/documentation/cloudkit/ckmodifyrecordsoperation/recordsavepolicy/ifserverrecordunchanged)）；
  - `.changedKeys`：只写客户端实际改动的键（部分合并）（[changedKeys](https://developer.apple.com/documentation/cloudkit/ckmodifyrecordsoperation/recordsavepolicy/changedkeys)）；
  - `.allKeys`：写全部键、覆盖服务器（[allKeys](https://developer.apple.com/documentation/cloudkit/ckmodifyrecordsoperation/recordsavepolicy/allkeys)）。
- **冲突错误与三副本合并**：版本不一致时返回 `CKError.Code.serverRecordChanged`（Swift `.serverRecordChanged`），错误 userInfo 提供 `CKRecordChangedErrorClientRecordKey`（本地）、`CKRecordChangedErrorServerRecordKey`（服务器）、`CKRecordChangedErrorAncestorRecordKey`（祖先）三份副本，官方要求合并后再保存（[serverRecordChanged](https://developer.apple.com/documentation/cloudkit/ckerror/serverrecordchanged)、[Record Changed Error Keys](https://developer.apple.com/documentation/cloudkit/record-changed-error-keys)）。⚠️ 命名修正：官方无 `CKRecordChangedError` 类，是 `CKError.Code.serverRecordChanged`。
- **custom zone**：私有库可在默认 zone 之外创建 custom zone；custom zone 支持「把多条记录写为单个原子事务」、支持共享与 zone 级增量同步；**公共库不能建 custom zone**（[CKRecordZone](https://developer.apple.com/documentation/cloudkit/ckrecordzone)）。

### 3.3 变更推送（CKSubscription + APNs）

- **订阅**：`CKSubscription` 是「服务器上的持久查询」，保存后变更触发推送；订阅需**先在开发环境创建再 promote 到生产环境**；「Xcode 在启用 CloudKit 时自动把 APNs entitlement 加入 entitlements 文件」，无需单独开启推送 App ID（[CKSubscription](https://developer.apple.com/documentation/cloudkit/cksubscription)）。
- **推送到达**：服务器向「除发起变更的那台设备外」的所有设备推送（[CKSubscription](https://developer.apple.com/documentation/cloudkit/cksubscription)）；macOS 用 `NSApplication.registerForRemoteNotifications()` 注册、`application(_:didReceiveRemoteNotification:)` 接收（[registerForRemoteNotifications()](https://developer.apple.com/documentation/appkit/nsapplication/registerforremotenotifications())、[application(_:didReceiveRemoteNotification:)](https://developer.apple.com/documentation/appkit/nsapplicationdelegate/application(_:didreceiveremotenotification:))）。
- **静默推送**：`CKQueryNotification` 区分 medium/high priority；静默（后台）推送需在 Background Modes 勾选「Background fetch」+「Remote notifications」；**「Don't rely on push notifications for changes because the system can coalesce them」**——推送可能被合并，必须配合增量拉取兜底；APNs 有负载大小限制，CloudKit 可能裁剪字段（[CKQueryNotification](https://developer.apple.com/documentation/cloudkit/ckquerynotification)）。
- **菜单栏（非沙盒、无后台模式）应用的适用性**：CloudKit 数据访问只要求 entitlement 正确 + private 库要求 `accountStatus == .available`（[Identifying an App's Containers](https://developer.apple.com/documentation/cloudkit/identifying-an-app-s-containers)、[accountStatus(completionHandler:)](https://developer.apple.com/documentation/cloudkit/ckcontainer/accountstatus(completionhandler:))），**官方未把 App Sandbox 列为 CloudKit 前提**（App Sandbox 是 Mac App Store 上架要求，见 3.4）。⚠️ 推论（官方未明确承诺，需实测）：macOS 没有 iOS 的 `remote-notification` UIBackgroundModes，「静默推送能否唤醒未运行 app」「非沙盒/Developer ID 构建能否稳定收到 APNs 生产推送」属平台行为；好在菜单栏 app 登录期间常驻运行，推送在运行态即可收到，退出后靠下次启动的 change token 全量拉取兜底。

### 3.4 使用 CloudKit 的最低配置（entitlements / 签名 / 打包）

- **必需 entitlements**：
  - `com.apple.developer.icloud-container-identifiers`（iCloud Container Identifiers，生产环境 container ID 数组）——「To add this entitlement to your app, enable the iCloud capability.」（[iCloud Container Identifiers Entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.icloud-container-identifiers)）。
  - `com.apple.developer.icloud-services`（取值 `CloudKit` 或 `CloudDocuments`）——「enable the iCloud capability and the iCloud Documents or CloudKit service.」（[iCloud Services Entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.icloud-services)）。
  - 配套：开发环境 container `com.apple.developer.icloud-container-development-container-identifiers`、环境 `com.apple.developer.icloud-container-environment`（[开发容器 ID](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.icloud-container-development-container-identifiers)）。
- **签名要求**：需 **Apple Developer Program 付费账号**；官方账号帮助页「Supported capabilities (macOS)」明确 **`iCloud: CloudKit` 对 Developer ID（Mac 直接分发、不经 App Store）也打 ✓，免费 Apple Developer 账号 ✗**（[Supported capabilities (macOS)](https://developer.apple.com/help/account/reference/supported-capabilities-macos)）。即 **CloudKit 不强制上 App Store**，Developer ID + 公证即可；付费会员是硬前提。
- **沙盒关系**：App Sandbox（`com.apple.security.app-sandbox`）是 **Mac App Store 上架要求**，不是 CloudKit 要求（[Configuring the macOS App Sandbox](https://developer.apple.com/documentation/Xcode/configuring-the-macos-app-sandbox)、[Protecting user data with App Sandbox](https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox)）。→ 非沙盒（Developer ID）app 亦可使用 CloudKit（工程判断）。
- **entitlements 注入方式**：entitlements 以 key-value 形式**嵌入代码签名**（[Entitlements](https://developer.apple.com/documentation/bundleresources/entitlements)）；现代签名用 DER 格式嵌入（[Using the latest code signature format](https://developer.apple.com/documentation/Xcode/using-the-latest-code-signature-format)）。SwiftPM 没有 Xcode 的 `CODE_SIGN_ENTITLEMENTS` 自动注入，需手动：组装 `.app` 后执行 `codesign --force --sign "<Developer ID identity>" --entitlements UnclutterPlus.entitlements --options runtime UnclutterPlus.app`（`man codesign` 的 `--entitlements`；[CODE_SIGN_ENTITLEMENTS（archive）](https://developer.apple.com/library/archive/documentation/DeveloperTools/Reference/XcodeBuildSettingRef/1-Build_Setting_Reference/build_setting_ref.html)）。`-sectcreate __TEXT __entitlements` 旧式 ldflag 在当前 codesign man page 已无记载，不建议。
- **本项目现状与差距**：`scripts/build.sh` 目前组装 `.app` 后**没有任何 codesign 步骤**（也未带 `--options runtime`）；bundle id 为 `com.unclutterplus.app`（`Sources/UnclutterPlus/Resources/Info.plist`）。接入 CloudKit 需在 build.sh 增加 codesign + entitlements 注入步骤，并新建 iCloud container（`iCloud.com.unclutterplus.app`）。

### 3.5 Core Data 迁移成本评估

- `NSPersistentCloudKitContainer` **本身就是一套 Core Data 栈**（`NSPersistentContainer` 子类），要求 store 为 SQLite、模型兼容 CloudKit 限制（无 unique/undefined/required/ordered），且模型必须完整镜像到 CloudKit schema（[Mirroring a Core Data store with CloudKit](https://developer.apple.com/documentation/coredata/mirroring-a-core-data-store-with-cloudkit)）。
- 因此「没有 Core Data 栈」的项目不是在现有存储上「加一层同步」，而是要先**新建整套数据模型 + SQLite store + 把现有 JSON 分片全量导入 + 部署并长期维护 CloudKit schema**（schema 上线后不可删改字段，[TN3164](https://developer.apple.com/documentation/technotes/tn3164-debugging-the-synchronization-of-nspersistentcloudkitcontainer)）。
- Core Data 自身的 schema 演进有 lightweight migration（自动迁移）兜底（[Migrating your data model automatically](https://developer.apple.com/documentation/coredata/migrating-your-data-model-automatically)），但那只解决「Core Data 模型版本演进」，不解决「JSON → Core Data」的首次搬迁与长期双栈维护成本。
- **工程判断**：为「iCloud 同步」而引入整套 Core Data + CloudKit，是**高迁移成本、收益不匹配**——除非数据本就是高度结构化关系数据且愿意长期接受 Core Data 模型约束。本项目（JSON 分片 + 图片元数据）更宜用方案 A 直接同步现有记录。

### 3.6 剪贴板同步的隐私与「同步风暴」风险

- **macOS 剪贴板读取权限**：`NSPasteboard.AccessBehavior` 定义 `.allow` / `.ask` / `.deny` 三种行为；「General 剪贴板默认在程序化访问时询问」，首次触发后 app 出现在系统设置里、用户可按 app 切换 allow/ask/deny；用户主动粘贴始终放行（[NSPasteboard.AccessBehavior](https://developer.apple.com/documentation/appkit/nspasteboard/accessbehavior-swift.enum)）。→ 剪贴板历史功能本身会触发该权限询问；同步功能必须优雅处理「用户拒绝读取 / 无内容」场景。
- **剪贴板数据敏感**：剪贴板为跨进程共享、含用户复制/剪切的内容（[NSPasteboard](https://developer.apple.com/documentation/appkit/nspasteboard)）。同步前应排除密码管理器等敏感来源（本项目市场调研已把「密码管理器内容自动忽略」列为基线能力），并提供「关闭剪贴板同步」开关。
- **同步风暴风险**：用户复制操作频繁 → 若每次复制都立即写一条 CKRecord，会同时打爆「免费速率 + CKSubscription 推送 + APNs 负载」。官方最佳实践指向**批量保存（`CKModifyRecordsOperation`，≤400 条/2 MB）+ 去抖/合并写入 + 乐观并发重试 + 遵守 `retryAfter`**（[CKModifyRecordsOperation](https://developer.apple.com/documentation/cloudkit/ckmodifyrecordsoperation)、[TN3162](https://developer.apple.com/documentation/technotes/tn3162-understanding-cloudkit-throttles)、[WWDC16 session 231: CloudKit Best Practices](https://developer.apple.com/videos/play/wwdc2016/231/)）。**工程建议**：剪贴板同步做 3–5 秒写入去抖窗口，把高频复制合并为一次批量保存。

---

## 四、推荐落地路线（分阶段）

> 前置条件（P0 之前）：**Apple Developer Program 付费账号** + Developer ID 证书 + 创建 iCloud container（`iCloud.com.unclutterplus.app`）。这是 CloudKit 的硬门槛（见 3.4）。

### 阶段 0 — 同步地基（签名 + entitlements + 容器）
- **做什么**：新增 `UnclutterPlus.entitlements`（`icloud-container-identifiers` + `icloud-services=CloudKit` + `aps-environment`）；在 `scripts/build.sh` 组装 `.app` 后补 `codesign --entitlements ... --options runtime` 步骤；用 `CKContainer.accountStatus` 做 iCloud 可用性探测。
- **工作量**：约 2–3 天。**风险**：低（纯配置 + 工具链）；主要风险是签名/公证流程与 entitlements 是否正确注入，需真机验证。

### 阶段 1 — 笔记同步（pilot，验证全链路）
- **做什么**：用 CloudKit 私有库 + 原生 CKRecord（建议直接上 CKSyncEngine）同步 Markdown 笔记分片；本地保留现有 JSON 分片 + 记录 `recordChangeTag`，实现增量拉取 + `.ifServerRecordUnchanged` 冲突合并 + CKSubscription 推送。
- **为什么先做笔记**：写入频率低（无同步风暴）、敏感度低、结构简单（正文 + 时间戳），最适合先验证 schema 部署、增量同步、冲突处理、推送与「菜单栏 app 收推送」的实测。
- **工作量**：约 1–2 周。**风险**：低-中；主要风险是 CloudKit schema 部署到 production 后不可改名（需在开发环境先把 schema 定型）。

### 阶段 2 — 剪贴板同步
- **做什么**：复用阶段 1 的同步层，新增：写入去抖（3–5 秒合并窗口）、批量保存（≤400 条/2 MB）、`savePolicy=.ifServerRecordUnchanged` + `serverRecordChanged` 三副本合并、订阅推送 + 增量拉取、隐私开关（密码管理器排除 / 可关闭同步 / 敏感内容不进云），并处理 macOS 剪贴板权限提示。
- **工作量**：约 2–3 周。**风险**：中（同步风暴、隐私）；需按 3.6 做去抖与批量，并实测限流表现。

### 阶段 3 — 文件暂存 + 截图
- **做什么**：文件暂存先同步 JSON 元数据 + 小文件（< 1 MB 走 `CKAsset`；大文件先只同步引用/元数据）；截图体积大，先只同步元数据（文件名/时间/OCR 文本/缩略图），原图留在本地或作为 `CKAsset` 可选上传（受用户 iCloud 配额限制）。
- **工作量**：约 2–4 周。**风险**：中-高（asset 体积、用户配额、下载按需性）。

### （可选）阶段 4 — 分享（CKShare / 公共库）
- 如需「把某条笔记/暂存文件分享给他人」，用 CKShare（要求记录在 custom zone，macOS 用 `NSCloudSharingServiceDelegate`）。非首发必需，可后置。

---

## 五、参考来源列表

**CloudKit 官方文档（developer.apple.com/documentation/cloudkit）**
- https://developer.apple.com/documentation/cloudkit （框架总览：非数据对象替代品、最小离线缓存）
- https://developer.apple.com/icloud/cloudkit/ （CloudKit 概览：1PB 公共数据）
- https://developer.apple.com/documentation/cloudkit/ckdatabase （三作用域、公共库免登录可读）
- https://developer.apple.com/documentation/cloudkit/ckcontainer （私有库存用户 iCloud 账号）
- https://developer.apple.com/documentation/cloudkit/ckcontainer/publicclouddatabase （公共库计入开发者配额）
- https://developer.apple.com/documentation/cloudkit/ckrecord （记录、1 MB 上限、支持类型）
- https://developer.apple.com/documentation/cloudkit/ckrecord/recordchangetag （change tag）
- https://developer.apple.com/documentation/cloudkit/ckrecordzone （默认/custom zone、原子事务、公共库无 custom zone）
- https://developer.apple.com/documentation/cloudkit/ckrecord/encodesystemfields(with:) （系统字段持久化）
- https://developer.apple.com/documentation/cloudkit/ckmodifyrecordsoperation/savepolicy （保存策略）
- https://developer.apple.com/documentation/cloudkit/ckmodifyrecordsoperation/recordsavepolicy （.ifServerRecordUnchanged/.changedKeys/.allKeys）
- https://developer.apple.com/documentation/cloudkit/ckerror/serverrecordchanged （冲突错误）
- https://developer.apple.com/documentation/cloudkit/record-changed-error-keys （三副本 userInfo 键）
- https://developer.apple.com/documentation/cloudkit/ckfetchrecordzonechangesoperation （zone 增量拉取）
- https://developer.apple.com/documentation/cloudkit/ckfetchdatabasechangesoperation （数据库变更拉取）
- https://developer.apple.com/documentation/cloudkit/ckserverchangetoken （change token）
- https://developer.apple.com/documentation/cloudkit/cksyncengine-5sie5 （CKSyncEngine）
- https://developer.apple.com/documentation/cloudkit/cksubscription （订阅、APNs entitlement 自动加入）
- https://developer.apple.com/documentation/cloudkit/ckquerynotification （静默推送、系统可能合并、需 Background Modes）
- https://developer.apple.com/documentation/cloudkit/ckerror/limitexceeded （400 条/2 MB 上限）
- https://developer.apple.com/documentation/cloudkit/ckasset （asset 语义、无公开大小上限）
- https://developer.apple.com/documentation/cloudkit/ckshare （CKShare、custom zone 共享）
- https://developer.apple.com/documentation/cloudkit/ckshare/participant （参与者）
- https://developer.apple.com/documentation/cloudkit/ckshare/metadata （macOS 接受分享回调）
- https://developer.apple.com/documentation/cloudkit/identifying-an-app-s-containers （容器 entitlement）
- https://developer.apple.com/documentation/cloudkit/ckcontainer/accountstatus(completionhandler:) （accountStatus）

**Core Data + CloudKit**
- https://developer.apple.com/documentation/coredata/nspersistentcloudkitcontainer
- https://developer.apple.com/documentation/coredata/setting-up-core-data-with-cloudkit
- https://developer.apple.com/documentation/coredata/mirroring-a-core-data-store-with-cloudkit （SQLite、模型限制、不可复用容器）
- https://developer.apple.com/documentation/coredata/syncing-a-core-data-store-with-cloudkit （约 1 分钟同步）
- https://developer.apple.com/documentation/technotes/tn3163-understanding-the-synchronization-of-nspersistentcloudkitcontainer
- https://developer.apple.com/documentation/technotes/tn3164-debugging-the-synchronization-of-nspersistentcloudkitcontainer （1000 zone/256 字段/1 MB、限流、公共库轮询 30 分钟/24 小时）
- https://developer.apple.com/documentation/technotes/tn3162-understanding-cloudkit-throttles （限流 retryAfter）
- https://developer.apple.com/documentation/coredata/sharing-core-data-objects-between-icloud-users
- https://developer.apple.com/documentation/coredata/nspersistentcloudkitcontaineroptions/databasescope-4c72t
- https://developer.apple.com/documentation/coredata/migrating-your-data-model-automatically

**iCloud Drive / ubiquity**
- https://developer.apple.com/documentation/foundation/filemanager/url(forubiquitycontaineridentifier:)
- https://developer.apple.com/documentation/foundation/filemanager/setubiquitous(_:itemat:destinationurl:)
- https://developer.apple.com/documentation/foundation/filemanager/startdownloadingubiquitousitem(at:)
- https://developer.apple.com/documentation/foundation/filemanager/ubiquityidentitytoken
- https://developer.apple.com/documentation/foundation/nsfilecoordinator
- https://developer.apple.com/documentation/foundation/nsfilepresenter （仅走协调器的变更才通知）
- https://developer.apple.com/documentation/foundation/nsfileversion
- https://developer.apple.com/documentation/foundation/nsfileversion/unresolvedconflictversionsofitem(at:)
- https://developer.apple.com/documentation/foundation/nsfileversion/isresolved （未清理版本持续占配额）
- https://developer.apple.com/documentation/foundation/nsfileversion/removeotherversionsofitem(at:)
- https://developer.apple.com/documentation/foundation/nsmetadataquery
- https://developer.apple.com/documentation/foundation/nsnotification/name-swift.struct/nsmetadataquerydidupdate
- https://developer.apple.com/documentation/foundation/urlubiquitousitemdownloadingstatus （dataless 状态）
- https://developer.apple.com/documentation/uikit/synchronizing-documents-in-the-icloud-environment
- https://developer.apple.com/library/archive/documentation/General/Conceptual/iCloudDesignGuide/Chapters/DesigningForDocumentsIniCloud.html
- https://developer.apple.com/documentation/xcode/configuring-icloud-services

**entitlements / 签名 / 分发**
- https://developer.apple.com/documentation/bundleresources/entitlements （entitlements 嵌入代码签名）
- https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.icloud-container-identifiers
- https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.icloud-services
- https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.icloud-container-development-container-identifiers
- https://developer.apple.com/documentation/Xcode/using-the-latest-code-signature-format （DER 签名、codesign）
- https://developer.apple.com/help/account/reference/supported-capabilities-macos （Developer ID 支持 iCloud/CloudKit）
- https://developer.apple.com/documentation/Xcode/configuring-the-macos-app-sandbox （沙盒 = App Store 要求）
- https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox
- https://developer.apple.com/developer-id/ （Developer ID）

**AppKit（剪贴板 / 推送）**
- https://developer.apple.com/documentation/appkit/nspasteboard/accessbehavior-swift.enum （剪贴板访问权限）
- https://developer.apple.com/documentation/appkit/nspasteboard
- https://developer.apple.com/documentation/appkit/nsapplication/registerforremotenotifications()
- https://developer.apple.com/documentation/appkit/nsapplicationdelegate/application(_:didreceiveremotenotification:)
- https://developer.apple.com/documentation/AppKit/NSCloudSharingServiceDelegate

**WWDC 官方 session**
- https://developer.apple.com/videos/play/wwdc2023/10188/ （Sync to iCloud with CKSyncEngine）
- https://developer.apple.com/videos/play/wwdc2020/10650/ （Sync a Core Data store with the CloudKit public database）
- https://developer.apple.com/videos/play/wwdc2021/10015/ （Build apps that share data through CloudKit and Core Data）
- https://developer.apple.com/videos/play/wwdc2022/10119/ （Optimize your use of Core Data and CloudKit）
- https://developer.apple.com/videos/play/wwdc2016/231/ （CloudKit Best Practices）
- https://developer.apple.com/videos/play/wwdc2021/10086/ （What's new in CloudKit）

**GitHub apple 组织官方示例**
- https://github.com/apple/sample-cloudkit-sync-engine （CKSyncEngine）
- https://github.com/apple/sample-cloudkit-privatedb
- https://github.com/apple/sample-cloudkit-privatedb-sync
- https://github.com/apple/sample-cloudkit-sharing （CKShare）
- https://github.com/apple/sample-cloudkit-coredatasync （NSPersistentCloudKitContainer）

**其他（归档 / 快照）**
- https://web.archive.org/web/20160304012435/https://developer.apple.com/icloud/ （2016 免费额度原文）
- https://developer.apple.com/library/archive/documentation/DeveloperTools/Reference/XcodeBuildSettingRef/1-Build_Setting_Reference/build_setting_ref.html （CODE_SIGN_ENTITLEMENTS）
- https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/EnablingiCloud.html （iCloud entitlement 归档）

---

### 数据可靠性备注
- CloudKit 免费额度具体数字（10 GB / 100 MB / 2 GB / 40 req/s）为 2016 年官方公开页原文，Apple 现行页面已撤下具体数字，当前额度需登录 CloudKit Console 查看；硬性 per-request 上限（400 条 / 2 MB、单条 1 MB、1000 zone / 256 字段）来自现行官方文档，可信。
- `CKSubscription` 数量上限、单个 CKAsset 大小上限、per-second 硬性速率阈值：Apple 未在公开文档公布，已在正文标注「未找到官方来源」。
- 「非沙盒/Developer ID 菜单栏 app 静默推送能否唤醒未运行 app」「CloudKit 是否强制沙盒」两条为基于官方事实的工程判断（正文已标注），落地阶段需以真实签名/分发配置实测。
