# iCloud Drive 文件同步技术调研（ubiquity 容器 + NSFileCoordinator + NSMetadataQuery）

> 调研目标：评估「把本地 JSON 分片 / 图片 + JSON 元数据目录直接放进 ubiquity 容器」的可行性与冲突代价。
> 来源原则：只引用 Apple 一手官方来源（developer.apple.com/documentation、/library/archive、/videos，及 github.com/apple 官方仓库）。所有 URL 均已用 HTTP 200 验证存活。未找到官方来源的条目会显式标注。

---

## 1. ubiquity 容器是什么

- **定义与获取**：`FileManager.url(forUbiquityContainerIdentifier:)`「Returns the URL for the iCloud container associated with the specified identifier and establishes access to that container.」。传入 `nil` 时返回 entitlements 数组里的第一个容器；返回值为 `nil` 表示「容器无法定位，或当前用户/设备 iCloud 存储不可用」。
  - 来源：[url(forUbiquityContainerIdentifier:) | Apple Developer Documentation](https://developer.apple.com/documentation/foundation/filemanager/url(forubiquitycontaineridentifier:))

- **容器 ID 形式**：容器标识符必须是 `<TEAMID>.<CONTAINER>` 形式（TEAMID 为开发团队 ID，CONTAINER 为容器 bundle ID）。
  - 来源：同上（[url(forUbiquityContainerIdentifier:)](https://developer.apple.com/documentation/foundation/filemanager/url(forubiquitycontaineridentifier:)) 的 Parameters 小节）。

- **entitlement 声明（键名）**：官方文档明确要求「你的 app 的容器标识符必须声明在 `.entitlements` 文件里的 `com.apple.developer.ubiquity-container-identifiers` 数组中」。同一份文档同时说明「每个同步文档到云端的 app 至少要有一个关联的 ubiquity 容器；该容器可以专属该 app，也可以被多个 app 共享」。
  - 来源：[url(forUbiquityContainerIdentifier:) | Apple Developer Documentation](https://developer.apple.com/documentation/foundation/filemanager/url(forubiquitycontaineridentifier:))

- **entitlement 键名的两个官方写法**（注意：Apple 自身文档存在两种命名，都属官方）：
  - 旧写法 `com.apple.developer.ubiquity-container-identifiers`（见上，以及归档的 Entitlement Key Reference）：
    - 来源：[Enabling iCloud — Entitlement Key Reference（archive）](https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/EnablingiCloud.html)
  - 新写法 `com.apple.developer.icloud-container-identifiers`（「iCloud Container Identifiers Entitlement」）：
    - 来源：[iCloud Container Identifiers Entitlement | Apple Developer Documentation](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.icloud-container-identifiers)
  - 开发期容器键 `com.apple.developer.icloud-container-development-container-identifiers`：
    - 来源：[com.apple.developer.icloud-container-development-container-identifiers | Apple Developer Documentation](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.icloud-container-development-container-identifiers)

- **iCloud Documents capability**：官方 Xcode 文档《Configuring iCloud services》描述如何在 Signing & Capabilities 中开启 iCloud 并勾选「iCloud Documents」。
  - 来源：[Configuring iCloud services | Apple Developer Documentation](https://developer.apple.com/documentation/xcode/configuring-icloud-services)

- **可用性检测**：官方建议在启动时用 `FileManager.ubiquityIdentityToken` 判断 iCloud 是否可用（而不是直接调 `url(forUbiquityContainerIdentifier:)`）。
  - 来源：[url(forUbiquityContainerIdentifier:)](https://developer.apple.com/documentation/foundation/filemanager/url(forubiquitycontaineridentifier:)) 的 Discussion；[ubiquityIdentityToken | Apple Developer Documentation](https://developer.apple.com/documentation/foundation/filemanager/ubiquityidentitytoken)

- **线程注意**：官方明确「不要从 app 主线程调用该方法」。
  - 来源：[url(forUbiquityContainerIdentifier:)](https://developer.apple.com/documentation/foundation/filemanager/url(forubiquitycontaineridentifier:)) 的 Discussion。

---

## 2. 把本地文件放进 iCloud 的方法

- **`FileManager.setUbiquitous(_:itemAt:destinationURL:)`**：「Indicates whether the item at the specified URL should be stored in iCloud.」`flag = true` 表示移动到 iCloud，`false` 表示从 iCloud 移出；`destinationURL` 必须由 `url(forUbiquityContainerIdentifier:)` 返回的 URL 构造（可附加子目录，但中间子目录要自行创建）。
  - 来源：[setUbiquitous(_:itemAt:destinationURL:) | Apple Developer Documentation](https://developer.apple.com/documentation/foundation/filemanager/setubiquitous(_:itemat:destinationurl:))

- **物理移动 + 协调写 + 需要 file presenter**：官方原文「Use this method to move a file from its current location to iCloud. For files located in an app's sandbox, this involves physically removing the file from the sandbox container.」；「this method performs a coordinated write operation on the specified file」；如果 app 正在展示该文件内容，「必须先有活跃的 file presenter 对象监控该文件/目录」。
  - 来源：[setUbiquitous(_:itemAt:destinationURL:)](https://developer.apple.com/documentation/foundation/filemanager/setubiquitous(_:itemat:destinationurl:)) 的 Discussion。

- **不要在主线程调用**：官方 Important 提示「Avoid calling this method from your app's main thread…可能长时间阻塞，且若 file presenter 错误配置在主队列收消息会导致死锁」。
  - 来源：同上（[setUbiquitous(_:itemAt:destinationURL:)](https://developer.apple.com/documentation/foundation/filemanager/setubiquitous(_:itemat:destinationurl:))）。

- **直接写到容器目录也是合法路径**：官方说明「You can use the URL returned by this method to build paths to files and directories within your app's ubiquity container」以及「In addition to writing to its own ubiquity container, an app can write to any container directory for which it has the appropriate permission.」
  - 来源：[url(forUbiquityContainerIdentifier:)](https://developer.apple.com/documentation/foundation/filemanager/url(forubiquitycontaineridentifier:)) 的 Discussion。

- **判断某 URL 是否已在 iCloud**：`FileManager.isUbiquitousItem(at:)`。
  - 来源：[isUbiquitousItem(at:) | Apple Developer Documentation](https://developer.apple.com/documentation/foundation/filemanager/isubiquitousitem(at:))

- **自动上传 / on-demand 逐文件下载（非全量镜像）**：
  - 官方描述：新文件出现时，iCloud「先同步文档 metadata 让设备知道文件存在」，随后是否同步文件数据取决于设备类型；「For iOS devices, iCloud doesn't synchronize the document data until an app asks」——即文件可能只在云端、本地无实体数据，用普通文件系统 API 找不到。
    - 来源：[Synchronizing documents in the iCloud environment | Apple Developer Documentation](https://developer.apple.com/documentation/uikit/synchronizing-documents-in-the-icloud-environment) 的 Overview。
  - 主动按需下载 API：`FileManager.startDownloadingUbiquitousItem(at:)`。
    - 来源：[startDownloadingUbiquitousItem(at:) | Apple Developer Documentation](https://developer.apple.com/documentation/foundation/filemanager/startdownloadingubiquitousitem(at:))
  - 归档指南同义表述见 [Designing for Documents in iCloud（archive）](https://developer.apple.com/library/archive/documentation/General/Conceptual/iCloudDesignGuide/Chapters/DesigningForDocumentsIniCloud.html)。

---

## 3. 协调读写

- **NSFileCoordinator 是什么**：「An object that coordinates the reading and writing of files and directories among file presenters.」它在同一进程多个对象之间、以及跨进程之间协调文件读写；执行操作前会先让已注册的 file presenter 完成其完整性所需的任务。
  - 来源：[NSFileCoordinator | Apple Developer Documentation](https://developer.apple.com/documentation/foundation/nsfilecoordinator)

- **协调读写 API**：`coordinate(readingItemAt:options:writingItemAt:options:error:byAccessor:)`（同一文件读改写）以及对应的 reading/writing 变体。
  - 来源：[coordinate(readingItemAt:options:writingItemAt:options:error:byAccessor:) | Apple Developer Documentation](https://developer.apple.com/documentation/foundation/nsfilecoordinator/coordinate(readingitemat:options:writingitemat:options:error:byaccessor:))

- **NSFilePresenter 协议用途**：「The interface a file coordinator uses to inform an object presenting a file about changes to that file made elsewhere in the system.」
  - 来源：[NSFilePresenter | Apple Developer Documentation](https://developer.apple.com/documentation/foundation/nsfilepresenter)；[presentedSubitemDidChange(at:) | Apple Developer Documentation](https://developer.apple.com/documentation/foundation/nsfilepresenter/presentedsubitemdidchange(at:))

- **关键前提（易被忽略）**：「Your presenter objects are not notified about changes made directly using low-level read and write calls to the file. Only changes that go through a file coordinator result in notifications.」——即协调/通知只在**双方都走 NSFileCoordinator** 时才成立。
  - 来源：[NSFilePresenter | Apple Developer Documentation](https://developer.apple.com/documentation/foundation/nsfilepresenter) 的 Overview。

- **File presenter 的注册**：通过 `NSFileCoordinator.addFilePresenter(_:)` / `removeFilePresenter(_:)` 注册/注销。
  - 来源：[NSFileCoordinator | Apple Developer Documentation](https://developer.apple.com/documentation/foundation/nsfilecoordinator) 的 Overview。

---

## 4. 冲突解决

- **冲突的官方语义**：「A conflict arises when two instances of your iOS app, running on two different devices, attempt to change a document.」冲突是**文件级（整文件版本）冲突**，不是字节级合并。
  - 来源：[Designing for Documents in iCloud（archive）](https://developer.apple.com/library/archive/documentation/General/Conceptual/iCloudDesignGuide/Chapters/DesigningForDocumentsIniCloud.html)

- **NSFileVersion 类**：版本/冲突的核心类型。
  - 来源：[NSFileVersion | Apple Developer Documentation](https://developer.apple.com/documentation/foundation/nsfileversion)

- **列举冲突版本**：`unresolvedConflictVersionsOfItem(at:)`。
  - 来源：[unresolvedConflictVersionsOfItem(at:) | Apple Developer Documentation](https://developer.apple.com/documentation/foundation/nsfileversion/unresolvedconflictversionsofitem(at:))

- **isResolved 语义**：系统检测到冲突时把该版本对象的 `isResolved` 置为 `false`；app 完成合并后应置为 `true` 并删除不再需要的版本。「Never set the value of this property to false. If you do, the system raises an exception.」
  - 来源：[isResolved | Apple Developer Documentation](https://developer.apple.com/documentation/foundation/nsfileversion/isresolved)

- **删除其他版本**：`removeOtherVersionsOfItem(at:)`，官方强调「always call this method from a block passed to a file coordinator object to initiate a write operation」。
  - 来源：[removeOtherVersionsOfItem(at:) | Apple Developer Documentation](https://developer.apple.com/documentation/foundation/nsfileversion/removeotherversionsofitem(at:))

- **创建版本**：`addVersion(ofItemAt:withContentsOf:options:)`。
  - 来源：[addOfItem(at:withContentsOf:options:) | Apple Developer Documentation](https://developer.apple.com/documentation/foundation/nsfileversion/addofitem(at:withcontentsof:options:))

- **配额代价**：官方警告「If you do not explicitly remove versions of a file that are no longer useful, iCloud continues to sync them to all a user's devices and those versions continue to consume user iCloud quota.」
  - 来源：[isResolved | Apple Developer Documentation](https://developer.apple.com/documentation/foundation/nsfileversion/isresolved)

- **用 URLResourceKey 判断是否有未解决冲突**：`ubiquitousItemHasUnresolvedConflictsKey`。
  - 来源：[ubiquitousItemHasUnresolvedConflictsKey | Apple Developer Documentation](https://developer.apple.com/documentation/foundation/urlresourcekey/ubiquitousitemhasunresolvedconflictskey)

---

## 5. 监听远端变更

- **NSMetadataQuery 是什么**：「A query that you perform against Spotlight metadata.」查询分两阶段：initial gathering + live-update。「You must set a predicate with the `predicate` property before starting a query.」
  - 来源：[NSMetadataQuery | Apple Developer Documentation](https://developer.apple.com/documentation/foundation/nsmetadataquery)

- **变更通知**：`NSMetadataQueryDidUpdate` 通知「Posted when the receiver's results have changed during the live-update phase of the query.」
  - 来源：[NSMetadataQueryDidUpdate | Apple Developer Documentation](https://developer.apple.com/documentation/foundation/nsnotification/name-swift.struct/nsmetadataquerydidupdate)

- **匹配 ubiquity 目录的官方写法**（Apple 官方示例 SimpleiCloudDocument 中的真实代码）：
  - `metadataQuery.searchScopes = [NSMetadataQueryUbiquitousDataScope, NSMetadataQueryUbiquitousDocumentsScope]`
  - `metadataQuery.predicate = NSPredicate(format: "%K LIKE %@", NSMetadataItemFSNameKey, "*.ext")`
  - `metadataQuery.notificationBatchingInterval = 1`，然后 `metadataQuery.start()`
  - 来源：[Synchronizing documents in the iCloud environment | Apple Developer Documentation](https://developer.apple.com/documentation/uikit/synchronizing-documents-in-the-icloud-environment)

- **为何必须用 NSMetadataQuery 而非文件系统 API**：官方原文「iOS apps use NSMetadataQuery rather than file system APIs to discover documents in an iCloud container… When an iOS app receives a notification that a new document exists, the document data may not physically exist on the local file system, so it isn't discoverable with file system APIs.」
  - 来源：同上（[Synchronizing documents in the iCloud environment](https://developer.apple.com/documentation/uikit/synchronizing-documents-in-the-icloud-environment)）。

---

## 6. 同步状态（URLResourceKey）

| 键 | 官方语义 | 来源 |
|---|---|---|
| `ubiquitousItemIsDownloadingKey` | 系统是否正在从 iCloud 下载该项 | [doc](https://developer.apple.com/documentation/foundation/urlresourcekey/ubiquitousitemisdownloadingkey) |
| `ubiquitousItemIsDownloadedKey` | 系统是否已把该项数据下载到本地 | [doc](https://developer.apple.com/documentation/foundation/urlresourcekey/ubiquitousitemisdownloadedkey) |
| `ubiquitousItemIsUploadingKey` | 系统是否正在把该项上传到 iCloud | [doc](https://developer.apple.com/documentation/foundation/urlresourcekey/ubiquitousitemisuploadingkey) |
| `ubiquitousItemIsUploadedKey` | 该项数据是否已上传到 iCloud | [doc](https://developer.apple.com/documentation/foundation/urlresourcekey/ubiquitousitemisuploadedkey) |
| `ubiquitousItemIsSharedKey` | 是否为共享项 | [doc](https://developer.apple.com/documentation/foundation/urlresourcekey/ubiquitousitemissharedkey) |
| `ubiquitousItemDownloadingStatusKey` | 下载状态（枚举，见下） | [doc](https://developer.apple.com/documentation/foundation/urlresourcekey/ubiquitousitemdownloadingstatuskey) |
| `ubiquitousItemHasUnresolvedConflictsKey` | 是否有未解决冲突 | [doc](https://developer.apple.com/documentation/foundation/urlresourcekey/ubiquitousitemhasunresolvedconflictskey) |

- **下载状态枚举 `URLUbiquitousItemDownloadingStatus`**：
  - `current`：本地有副本，且是设备已知的最新版。
  - `downloaded`：本地有副本但已过期，最新版会尽快下载。
  - `notDownloaded`：尚未下载（**dataless 状态**），用 `startDownloadingUbiquitousItem(at:)` 触发下载。
  - 来源：[URLUbiquitousItemDownloadingStatus | Apple Developer Documentation](https://developer.apple.com/documentation/foundation/urlubiquitousitemdownloadingstatus)

- **官方坑位提示**：等待上传完成时，「不要在传给 `coordinate(readingItemAt:options:error:byAccessor:)` 的 block 里轮询 `ubiquitousItemIsUploadedKey`」，因为获取该值所需的协调读要等 block 返回才能执行；应改用 `NSMetadataQuery` 或 `NSFilePresenter` 委托异步通知状态变化。
  - 来源：[ubiquitousItemIsUploadedKey | Apple Developer Documentation](https://developer.apple.com/documentation/foundation/urlresourcekey/ubiquitousitemisuploadedkey)

---

## 7. 已知限制

- **不做逐字节实时协同**：冲突被官方定义为「两台设备各自修改同一文档」产生的**整文件版本冲突**，需要 app 自己读出版本、合并、再标记 `isResolved`。没有官方 API 提供字符/字节级自动合并。
  - 依据：[Designing for Documents in iCloud（archive）](https://developer.apple.com/library/archive/documentation/General/Conceptual/iCloudDesignGuide/Chapters/DesigningForDocumentsIniCloud.html)；[isResolved | Apple Developer Documentation](https://developer.apple.com/documentation/foundation/nsfileversion/isresolved)

- **冲突需自行用 NSFileVersion 解决**：见第 4 节；不清理版本会持续占用用户 iCloud 配额（[isResolved](https://developer.apple.com/documentation/foundation/nsfileversion/isresolved)）。

- **文件可能处于未下载（dataless）状态**：本地只有 metadata、无文件数据，用文件系统 API 找不到；必须按需下载（[URLUbiquitousItemDownloadingStatus](https://developer.apple.com/documentation/foundation/urlubiquitousitemdownloadingstatus)、[startDownloadingUbiquitousItem(at:)](https://developer.apple.com/documentation/foundation/filemanager/startdownloadingubiquitousitem(at:))）。

- **协调/通知只对走 NSFileCoordinator 的双方生效**：绕过协调器的裸读写不会产生 presenter 通知（[NSFilePresenter](https://developer.apple.com/documentation/foundation/nsfilepresenter) Overview）。

- **用户可在系统设置里关闭 iCloud Drive**：`url(forUbiquityContainerIdentifier:)` 在「iCloud storage is unavailable for the current user or device」时返回 `nil`，官方建议用 `ubiquityIdentityToken` 判断可用性。
  - 依据：[Synchronizing documents in the iCloud environment](https://developer.apple.com/documentation/uikit/synchronizing-documents-in-the-icloud-environment)；[url(forUbiquityContainerIdentifier:)](https://developer.apple.com/documentation/foundation/filemanager/url(forubiquitycontaineridentifier:))；[ubiquityIdentityToken](https://developer.apple.com/documentation/foundation/filemanager/ubiquityidentitytoken)。

- **跨应用共享文件**：容器本身可「unique to the app or shared by multiple apps」（[url(forUbiquityContainerIdentifier:)](https://developer.apple.com/documentation/foundation/filemanager/url(forubiquitycontaineridentifier:))）；把容器发布到 iCloud Drive 供其他 app 访问，用 `Info.plist` 的 `NSUbiquitousContainers` + `NSUbiquitousContainerIsDocumentScopePublic = true`（[Synchronizing documents in the iCloud environment](https://developer.apple.com/documentation/uikit/synchronizing-documents-in-the-icloud-environment)）。

---

## 8. 官方指南 / 示例

- **指南（archive，权威概念讲解）**：[Designing for Documents in iCloud — Apple Developer（archive）](https://developer.apple.com/library/archive/documentation/General/Conceptual/iCloudDesignGuide/Chapters/DesigningForDocumentsIniCloud.html)
- **现代官方示例文章（含完整代码，SimpleiCloudDocument 示例）**：[Synchronizing documents in the iCloud environment | Apple Developer Documentation](https://developer.apple.com/documentation/uikit/synchronizing-documents-in-the-icloud-environment)
- **Xcode 配置**：[Configuring iCloud services | Apple Developer Documentation](https://developer.apple.com/documentation/xcode/configuring-icloud-services)
- **官方 WWDC sessions**：[Build document-based apps in SwiftUI — WWDC20（10039）](https://developer.apple.com/videos/play/wwdc2020/10039/) · [Building a Document-based App — WWDC14（234）](https://developer.apple.com/videos/play/wwdc2014/234/) · [Sync to iCloud with CKSyncEngine — WWDC23（10188）](https://developer.apple.com/videos/play/wwdc2023/10188/)（注意：这是 **CloudKit** 同步路径，不是 ubiquity 容器文件同步）
- **apple 组织官方 GitHub 示例**（均为 CloudKit 示例，经 GitHub API 核实）：[sample-cloudkit-privatedb-sync](https://github.com/apple/sample-cloudkit-privatedb-sync) · [sample-cloudkit-sync-engine](https://github.com/apple/sample-cloudkit-sync-engine) · [sample-cloudkit-sharing](https://github.com/apple/sample-cloudkit-sharing) · [sample-cloudkit-coredatasync](https://github.com/apple/sample-cloudkit-coredatasync)
- ⚠️ **未找到 apple 组织针对「ubiquity 容器 + NSFileCoordinator + NSMetadataQuery」文件同步的官方 GitHub 示例**；该类示例只存在于 Apple 归档页：[ShapeEdit: Building a Simple iCloud Document App（archive sample code）](https://developer.apple.com/library/archive/samplecode/ShapeEdit/)

---

## 9. 简短分析：现有「本地 JSON 分片 + 图片/JSON 元数据」目录直接放进 ubiquity 容器是否可行

1. **可行但非「零成本」**。官方允许把任意文件/目录放进 ubiquity 容器（[url(forUbiquityContainerIdentifier:)](https://developer.apple.com/documentation/foundation/filemanager/url(forubiquitycontaineridentifier:)) 明确「build paths to files and directories within your app's ubiquity container」），且可直接写入容器目录或用 `setUbiquitous` 移动；iCloud Drive 本身对文件类型无限制，JSON 分片和图片都是普通文件，机制上能同步。**（官方依据）**

2. **最大的代价是冲突模型不匹配**。iCloud Drive 的冲突是**整文件版本冲突**，需自行用 `NSFileVersion` 读出版本、合并、标记 `isResolved`、删除旧版本（[isResolved](https://developer.apple.com/documentation/foundation/nsfileversion/isresolved)、[unresolvedConflictVersionsOfItem(at:)](https://developer.apple.com/documentation/foundation/nsfileversion/unresolvedconflictversionsofitem(at:))）。你的存储是「多 JSON 分片 + 图片 + JSON 元数据」相互关联的一组文件，iCloud 对**每个文件独立**产生版本，不会保证这组文件之间的原子一致性。**（前半句官方依据；跨文件原子一致性与分片粒度代价是工程判断）**

3. **必须改造所有读写路径**。官方明确「只有经过 NSFileCoordinator 的变更才会触发 presenter 通知」（[NSFilePresenter](https://developer.apple.com/documentation/foundation/nsfilepresenter)）；现有本地 JSON 分片读写若不走 `coordinate(reading/writing)`，就收不到远端变更、也拿不到冲突提示。**（官方依据 + 工程判断）**

4. **必须容忍「dataless」状态**。远端文件可能只有 metadata、本地无实体数据（[URLUbiquitousItemDownloadingStatus.notDownloaded](https://developer.apple.com/documentation/foundation/urlubiquitousitemdownloadingstatus)），现有「直接读本地目录文件」的假设会被打破。**（官方依据）**

5. **风险点**：多分片高频小写入会放大「冲突 + 上传等待」的组合问题（官方提示不要在协调块内轮询 `ubiquitousItemIsUploadedKey`，[ubiquitousItemIsUploadedKey](https://developer.apple.com/documentation/foundation/urlresourcekey/ubiquitousitemisuploadedkey)）；剪贴板这类高频改动场景，文件级整版本冲突的合并成本偏高。若目标是多设备「逐记录级」同步，官方更接近的路径是 CloudKit（[WWDC23 CKSyncEngine](https://developer.apple.com/videos/play/wwdc2023/10188/)）。**（工程判断，基于前述官方限制推断）**

6. **结论（工程判断）**：如果只是「备份/镜像到 iCloud Drive 供用户查看 + 单设备为主编辑」，直接把目录放进 ubiquity 容器是低成本可行的；但如果要做「多设备同时编辑、期望自动合并」，现有「一组关联分片文件」的模型与 iCloud Drive 的「单文件整版本冲突」模型冲突代价高，建议先评估 CloudKit（记录级同步 + 服务端冲突处理）或把数据收敛为**单文件**再走 iCloud 文档同步。
