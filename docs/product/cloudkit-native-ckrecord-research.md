# CloudKit 原生 CKRecord API（无 Core Data）事实清单

> 调研范围：macOS Swift/SwiftUI 使用 CloudKit 原生 CKRecord API（不经过 Core Data）。
> 来源限定：developer.apple.com/documentation/cloudkit、developer.apple.com/videos（WWDC）、github.com/apple 官方示例。
> 每条事实后附官方来源 markdown 链接。

---

## 1. CKDatabase 三种作用域（private / shared / public）

- CloudKit 用 `CKDatabase.Scope` 枚举区分三种作用域，case 为 `.public`、`.private`、`.shared`。
  来源：[CKDatabase.Scope.public](https://developer.apple.com/documentation/CloudKit/CKDatabase/Scope/public)、[CKDatabase](https://developer.apple.com/documentation/cloudkit/ckdatabase)
- **public database（公共数据库）**：存储对该 app 所有用户可见的数据，是「app 级」的共享数据空间；读写受 CloudKit 权限/安全角色控制。
  来源：[CKDatabase](https://developer.apple.com/documentation/cloudkit/ckdatabase)
- **private database（私有数据库）**：属于当前登录的 iCloud 用户，只有该用户能访问，是「用户级」的私有数据空间。
  来源：[CKDatabase](https://developer.apple.com/documentation/cloudkit/ckdatabase)
- **shared database（共享数据库）**：存放通过共享（CKShare）分享给「当前用户」的记录，即「他人分享给我」的数据。
  来源：[CKDatabase](https://developer.apple.com/documentation/cloudkit/ckdatabase)
- 通过 `CKContainer` 的 `privateCloudDatabase` / `publicCloudDatabase` / `sharedCloudDatabase` 获取对应 `CKDatabase` 实例。
  来源：[CKContainer](https://developer.apple.com/documentation/cloudkit/ckcontainer)

## 2. CKRecord / CKRecord.ID / CKRecordZone / recordChangeTag / systemFields

- **CKRecord**：CloudKit 中一条记录的容器，含 `recordType`（类型）与字段键值字典。
  来源：[CKRecord](https://developer.apple.com/documentation/cloudkit/ckrecord)
- **CKRecord.ID**：记录的唯一标识，由 `recordName`（该 zone 内唯一的名字）与 `zoneID`（所属 zone）组成；构造用 `CKRecord.ID(recordName:zoneID:)`。
  来源：[CKRecord.ID](https://developer.apple.com/documentation/cloudkit/ckrecord/id)、[init(recordName:zoneID:)](https://developer.apple.com/documentation/cloudkit/ckrecord/id/init(recordname:zoneid:))
- **CKRecordZone**：记录分区。分「默认 zone」与「自定义 zone」：
  - 默认 zone：`CKRecordZone.default()`，zone 名为 `CKRecordZone.ID.defaultZoneName`（值 `_defaultZone`）；不能用于 CKShare 共享。
  - 自定义 zone：`CKRecordZone(zoneName:)` 创建；支持共享，且支持 zone 粒度的增量同步（change token 按 zone 管理）。
  来源：[CKRecordZone](https://developer.apple.com/documentation/cloudkit/ckrecordzone)、[CKRecordZoneDefaultName](https://developer.apple.com/documentation/cloudkit/ckrecordzonedefaultname-8mfij?language=objc)
- **recordChangeTag**：`CKRecord.recordChangeTag`（`String?`），是服务器每次保存后下发的「版本标记」，用于乐观并发/冲突检测。
  来源：[recordChangeTag](https://developer.apple.com/documentation/cloudkit/ckrecord/recordchangetag)
- **systemFields（系统字段）**：官方没有公开的 `CKRecord.systemFields` 属性；系统字段（record type、ID、zone、change tag 等）通过
  `encodeSystemFields(with:)` 编码进 `NSCoder`，再用 `CKRecord(coder:)` 反解重建记录，用于把「服务器元数据」本地持久化。
  来源：[encodeSystemFields(with:)](https://developer.apple.com/documentation/cloudkit/ckrecord/encodesystemfields(with:))、[init(coder:)](https://developer.apple.com/documentation/cloudkit/ckrecord/init(coder:))、[CKRecord.SystemFieldKey](https://developer.apple.com/documentation/cloudkit/ckrecord/systemfieldkey)
- ⚠️ 修正：`CKRecord.ID` 没有 `recordChangeTag` 属性，change tag 属于 `CKRecord`（见上）。

## 3. 冲突解决机制

- **CKModifyRecordsOperation.savePolicy**：类型为 `CKModifyRecordsOperation.RecordSavePolicy` 枚举，控制保存时的冲突策略。
  来源：[savePolicy](https://developer.apple.com/documentation/cloudkit/ckmodifyrecordsoperation/savepolicy)、[CKModifyRecordsOperation.RecordSavePolicy](https://developer.apple.com/documentation/cloudkit/ckmodifyrecordsoperation/recordsavepolicy)
  - `.ifServerRecordUnchanged`：仅当服务器上记录自你上次读取后未被修改时才保存；否则返回 serverRecordChanged 错误。
    来源：[ifServerRecordUnchanged](https://developer.apple.com/documentation/cloudkit/ckmodifyrecordsoperation/recordsavepolicy/ifserverrecordunchanged)
  - `.changedKeys`：只保存客户端实际改动过的键，服务器上未被改动的字段保留（partial save/合并）。
    来源：[changedKeys](https://developer.apple.com/documentation/cloudkit/ckmodifyrecordsoperation/recordsavepolicy/changedkeys)
  - `.allKeys`：保存记录的所有键，覆盖服务器上的全部字段。
    来源：[allKeys](https://developer.apple.com/documentation/cloudkit/ckmodifyrecordsoperation/recordsavepolicy/allkeys)
- **server record 与 client change tag 语义**：保存时客户端记录携带其持有的 `recordChangeTag`（base 版本）；若与服务器当前版本不一致，服务器拒绝写入并返回 `serverRecordChanged` 错误，同时通过错误 userInfo 提供服务器版本、客户端版本与祖先（ancestor）版本。
  来源：[serverRecordChanged](https://developer.apple.com/documentation/cloudkit/ckerror/serverrecordchanged)、[CKError.Code.serverRecordChanged](https://developer.apple.com/documentation/cloudkit/ckerror/code/serverrecordchanged)
- **错误 userInfo 键**（用于读取服务器/客户端/祖先记录做合并）：
  - `CKRecordChangedErrorClientRecordKey`：客户端尝试保存的记录。
  - `CKRecordChangedErrorServerRecordKey`：服务器上的当前记录。
  - `CKRecordChangedErrorAncestorRecordKey`：服务器认定的 base/祖先记录。
  来源：[Record Changed Error Keys](https://developer.apple.com/documentation/cloudkit/record-changed-error-keys)
- ⚠️ 命名修正：官方没有名为 `CKRecordChangedError` 的类；冲突错误在 Swift 中是 `CKError.Code.serverRecordChanged`。

## 4. 增量同步推荐 API

- **CKFetchRecordZoneChangesOperation**：按 zone 增量拉取记录变更。配置待同步 zone 及其 change token；回调含 `recordChangedBlock`、`recordWithIDWasDeletedBlock`、`recordZoneChangeTokensUpdatedBlock`（拿到新 change token）、`recordZoneFetchCompletionBlock`。
  来源：[CKFetchRecordZoneChangesOperation](https://developer.apple.com/documentation/cloudkit/ckfetchrecordzonechangesoperation)、[recordZoneChangeTokensUpdatedBlock](https://developer.apple.com/documentation/cloudkit/ckfetchrecordzonechangesoperation/recordzonechangetokensupdatedblock)
- **CKFetchDatabaseChangesOperation**：按数据库拉取 zone 级变更（哪些 zone 新增/删除/变更），返回新的 server change token 与变更的 zone；用 `previousServerChangeToken` 指定起点。
  来源：[CKFetchDatabaseChangesOperation](https://developer.apple.com/documentation/cloudkit/ckfetchdatabasechangesoperation)、[recordZoneWithIDChangedBlock](https://developer.apple.com/documentation/cloudkit/ckfetchdatabasechangesoperation/recordzonewithidchangedblock)、[previousServerChangeToken](https://developer.apple.com/documentation/cloudkit/ckfetchdatabasechangesoperation/previousserverchangetoken)
- **change token**：`CKServerChangeToken` 是服务器生成的不透明令牌，标记「已同步到哪」；本地持久化它，下次请求作为起点传给上述 operation，实现增量同步。
  来源：[CKServerChangeToken](https://developer.apple.com/documentation/CloudKit/CKServerChangeToken)、[Remote Records（Change Tokens 章节）](https://developer.apple.com/documentation/cloudkit/remote-records)
- 📌 现代推荐：Apple 现在推荐用 **CKSyncEngine** 直接做原生 CKRecord 的增量同步（封装了 fetch/save/冲突处理与上述 operation 的编排），见 WWDC23《Sync to iCloud with CKSyncEngine》。
  来源：[CKSyncEngine](https://developer.apple.com/documentation/cloudkit/cksyncengine-5sie5)、[WWDC23 · Sync to iCloud with CKSyncEngine](https://developer.apple.com/videos/play/wwdc2023/10188/)

## 5. 变更推送（Subscription + APNs）

- **CKSubscription**：订阅基类；`CKSubscription.SubscriptionType` 枚举含 `.query`、`.recordZone`、`.database` 三种。
  来源：[CKSubscription](https://developer.apple.com/documentation/cloudkit/cksubscription)、[CKSubscription.SubscriptionType](https://developer.apple.com/documentation/cloudkit/cksubscription/subscriptiontype-swift.enum)
  - **CKQuerySubscription**：按查询条件匹配记录的订阅。[CKQuerySubscription](https://developer.apple.com/documentation/cloudkit/ckquerysubscription)
  - **CKRecordZoneSubscription**：订阅某个 zone 内所有记录变更。[CKRecordZoneSubscription](https://developer.apple.com/documentation/cloudkit/ckrecordzonesubscription)
  - **CKDatabaseSubscription**：订阅整个数据库（含各 zone 的变更）的变更。[CKDatabaseSubscription](https://developer.apple.com/documentation/cloudkit/ckdatabasesubscription)
- **CKQueryNotification**：订阅触发后经推送到达的通知对象，携带 `recordID`、`recordFields`、`subscriptionID`、`isPublicDatabase` 等；从推送 payload 的 `ck` 键解析。
  来源：[CKQueryNotification](https://developer.apple.com/documentation/cloudkit/ckquerynotification)
- **通知配置**：订阅的 `notificationInfo`（`CKSubscription.NotificationInfo`）控制是否弹窗/角标/静默；`shouldSendContentAvailable` 对应「静默推送」（APNs 的 content-available）。
  来源：[CKSubscription.NotificationInfo](https://developer.apple.com/documentation/cloudkit/cksubscription/notificationinfo-swift.class)、[shouldSendContentAvailable](https://developer.apple.com/documentation/cloudkit/cksubscription/notificationinfo-swift.class/shouldsendcontentavailable)
- **推送需要 APNs**：macOS 上通过 `NSApplication.registerForRemoteNotifications()` 注册远程通知。
  来源：[registerForRemoteNotifications()](https://developer.apple.com/documentation/appkit/nsapplication/registerforremotenotifications())
- **回调**：macOS 由 `NSApplicationDelegate.application(_:didReceiveRemoteNotification:)` 接收远程通知。
  来源：[application(_:didReceiveRemoteNotification:)](https://developer.apple.com/documentation/appkit/nsapplicationdelegate/application(_:didreceiveremotenotification:))

## 6. 最小工程事实

- **CKContainer(identifier:)**：用容器标识符创建/获取容器；`CKContainer.default()` 返回 app 的默认容器。
  来源：[init(identifier:)](https://developer.apple.com/documentation/cloudkit/ckcontainer/init(identifier:))、[default()](https://developer.apple.com/documentation/cloudkit/ckcontainer/default())
- **容器必须在工程里配置**：app 需在 entitlements（`com.apple.developer.icloud-container-identifiers`）与 CloudKit 后台声明/启用容器。
  来源：[Identifying an App's Containers](https://developer.apple.com/documentation/cloudkit/identifying-an-app-s-containers)
- **accountStatus**：`CKContainer.accountStatus(completionHandler:)` 返回 `CKAccountStatus`；只有 `.available`（用户已登录 iCloud）时才能访问 **private database**。
  来源：[accountStatus(completionHandler:)](https://developer.apple.com/documentation/cloudkit/ckcontainer/accountstatus(completionhandler:))

## 7. apple 组织的官方 CloudKit 示例仓库

- **apple/sample-cloudkit-sync-engine**：CKSyncEngine 官方示例（对应 WWDC23 10188）。
  来源：[https://github.com/apple/sample-cloudkit-sync-engine](https://github.com/apple/sample-cloudkit-sync-engine)
- **apple/sample-cloudkit-privatedb**：私有数据库（private database）官方示例。
  来源：[https://github.com/apple/sample-cloudkit-privatedb](https://github.com/apple/sample-cloudkit-privatedb)
- **apple/sample-cloudkit-privatedb-sync**：私有数据库增量同步官方示例。
  来源：[https://github.com/apple/sample-cloudkit-privatedb-sync](https://github.com/apple/sample-cloudkit-privatedb-sync)

### 相关 WWDC 官方 session

- [Sync to iCloud with CKSyncEngine · WWDC23（10188）](https://developer.apple.com/videos/play/wwdc2023/10188/)
- [What's new in CloudKit · WWDC21（10086）](https://developer.apple.com/videos/play/wwdc2021/10086/)
- [What's new in CloudKit Console · WWDC22（10115）](https://developer.apple.com/videos/play/wwdc2022/10115/)
- [Build apps that share data through CloudKit and Core Data · WWDC21（10015）](https://developer.apple.com/videos/play/wwdc2021/10015/)（Core Data 相关，仅作对照）

---

## 附：菜单栏（非沙盒、无后台模式）应用的适用性与限制分析

**官方依据**：CloudKit 数据访问只要求 app 在 entitlements 中声明并启用 CloudKit 容器（[Identifying an App's Containers](https://developer.apple.com/documentation/cloudkit/identifying-an-app-s-containers)）；private database 要求用户 `accountStatus == .available`（已登录 iCloud）（[accountStatus(completionHandler:)](https://developer.apple.com/documentation/cloudkit/ckcontainer/accountstatus(completionhandler:))）；变更推送需要 `registerForRemoteNotifications()` 并依赖 APNs（[registerForRemoteNotifications()](https://developer.apple.com/documentation/appkit/nsapplication/registerforremotenotifications())）。

**推论（官方未明确承诺，需实测）**：菜单栏（LSUIElement/NSStatusItem）与「非沙盒」本身不影响 CKRecord 读写——CloudKit 并未把 App Sandbox 列为前置条件，只要求进程运行且 entitlement 正确；但「无后台模式」下，macOS 没有 iOS 的 `remote-notification` UIBackgroundModes 概念，静默推送能否唤醒未运行/无后台模式的 app、以及非 App Store 非沙盒构建能否稳定收到 APNs 生产推送，Apple CloudKit 文档未明确承诺，属于平台行为，需以实际签名/分发配置验证。
