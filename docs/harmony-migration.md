# shuiTime 鸿蒙版本迁移设计文档

## 1. 文档目标

本文档用于指导 `shuiTime` 从当前 iOS 原生版本迁移到鸿蒙原生版本。

目标不是直接移植 SwiftUI 代码，而是：

- 抽离现有产品能力与业务规则
- 在鸿蒙生态中以原生方式重建
- 优先实现可上线的 MVP
- 为后续双端数据互通预留统一的数据协议

## 2. 当前项目现状

当前仓库是一个 iOS 原生应用，核心技术栈如下：

- UI：`SwiftUI`
- 持久化：`SwiftData`
- 图片/媒体：`UIKit`、`PhotosUI`、`AVKit`
- 文件导入导出：iOS 原生文件选择器与导出能力

项目当前已落地的核心产品结构：

- 时间线
- 瞬息
- 时光回顾
- 全局搜索
- 本地备份导入导出

对应关键文件：

- App 入口：`/Users/sundusk/App/shuiTime/shuiTime/shuiTimeApp.swift`
- 主容器：`/Users/sundusk/App/shuiTime/shuiTime/ContentView.swift`
- 数据模型：`/Users/sundusk/App/shuiTime/shuiTime/Model/TimelineItem.swift`
- 备份逻辑：`/Users/sundusk/App/shuiTime/shuiTime/Model/BackupManager.swift`
- 时间线：`/Users/sundusk/App/shuiTime/shuiTime/timeLine/TimeLineView.swift`
- 瞬息：`/Users/sundusk/App/shuiTime/shuiTime/inspiration/InspirationView.swift`
- 时光回顾：`/Users/sundusk/App/shuiTime/shuiTime/lookBack/LookBackView.swift`
- 搜索：`/Users/sundusk/App/shuiTime/shuiTime/search/GlobalSearchView.swift`

## 3. 迁移原则

### 3.1 不直接移植 UI 代码

SwiftUI、SwiftData、UIKit、PhotosUI 都是 iOS 专属实现，无法在鸿蒙直接复用。

鸿蒙版本应采用：

- ArkUI 作为界面层
- ArkTS 作为应用逻辑层
- 鸿蒙原生存储、媒体、文件 API

因此迁移策略应是：

- 复用“产品定义”
- 重写“平台实现”

### 3.2 优先复用产品规则和数据协议

最值得继承的不是页面代码，而是：

- 数据字段定义
- 内容分区规则
- 搜索和筛选规则
- 回顾与归档规则
- 备份文件格式

### 3.3 先做 MVP，再补高复杂特性

鸿蒙首版应先跑通主链路，降低迁移风险。

MVP 不追求与 iOS 100% 一致，而追求：

- 可记录
- 可浏览
- 可搜索
- 可存储
- 可迁移数据

## 4. 功能盘点与迁移结论

### 4.1 可直接迁移为“产品能力”的部分

- 三大 Tab 结构：时间线、瞬息、时光回顾
- `TimelineItem` 数据模型
- 标签解析规则
- 搜索范围与筛选方式
- 去年今日与指定日期回顾
- 备份导入导出机制

### 4.2 必须按鸿蒙原生重写的部分

- 所有 `SwiftUI` 页面
- `SwiftData` 查询与存储
- 相机/相册选择
- Live Photo 相关能力
- 文件选择器和文件导出
- 震动反馈和浮层交互

### 4.3 建议延后的高复杂能力

- Live Photo 的完整兼容
- 与 iOS 完全一致的动画细节
- 高度定制的日历蓝点与复杂视觉特效
- 所有平台特有的媒体编辑细节

## 5. 现有产品结构拆解

### 5.1 主导航结构

当前主入口位于 `ContentView`，结构是三 Tab：

- 时间线：记录按日期展示的主内容
- 瞬息：偏灵感、标签化、可编辑的卡片流
- 时光回顾：聚合历史、热力图、去年今日、按日浏览

鸿蒙版建议保留完全相同的信息架构，以减少产品心智变化。

### 5.2 核心数据模型

当前核心实体为 `TimelineItem`，字段如下：

| 字段 | 类型 | 用途 |
| --- | --- | --- |
| `id` | UUID | 主键 |
| `timestamp` | Date | 记录时间 |
| `content` | String | 文本内容 |
| `iconName` | String | 图标名 |
| `type` | String | 内容类型 |
| `imageData` | Data? | 图片数据 |
| `isLivePhoto` | Bool | 是否 Live Photo |
| `livePhotoVideoData` | Data? | Live Photo 对应视频 |
| `borderColorHex` | String? | 圈选颜色 |

当前 `type` 至少已包含：

- `timeline`
- `inspiration`
- `moment`

鸿蒙版首版建议保留同名字段与同名枚举值，避免未来数据转换复杂化。

### 5.3 关键业务规则

#### 时间线

- 按日期查看记录
- 允许文字输入
- 支持当日“瞬影”图片记录
- 当日 `moment` 数量有限制
- 支持全局搜索跳转到指定时间点

#### 瞬息

- 数据类型为 `inspiration`
- 支持标签提取与标签筛选
- 支持编辑、删除、搜索
- 支持为卡片设置圈选颜色

#### 时光回顾

- 可展示热力图
- 支持按日期浏览历史
- 支持“去年今日”
- 支持从历史数据中挑选封面内容

#### 备份

- 支持导出
- 支持合并导入
- 支持覆盖导入
- 导入时有去重逻辑

## 6. 鸿蒙版技术方案建议

### 6.1 技术选型建议

建议采用鸿蒙原生技术栈：

- 语言：ArkTS
- UI：ArkUI
- 工程形态：Stage 模型

首版尽量避免引入过多第三方跨端框架，原因如下：

- 当前 iOS 项目本身不是跨端架构
- 鸿蒙媒体、文件、权限能力通常需要原生 API 适配
- 迁移重点在数据和交互重建，而不是代码共享

### 6.2 模块划分建议

建议按以下方式组织鸿蒙工程：

```text
entry/src/main/ets/
  app/
    EntryAbility.ets
  common/
    constants/
    utils/
    types/
  data/
    model/
    repository/
    storage/
    backup/
  features/
    timeline/
    inspiration/
    lookback/
    search/
  components/
  resources/
```

推荐职责划分：

- `data/model`：实体定义、DTO、字段映射
- `data/repository`：查询、保存、删除、筛选
- `data/backup`：导入导出、压缩解压、JSON 编解码
- `features/timeline`：时间线页面和逻辑
- `features/inspiration`：瞬息页面和逻辑
- `features/lookback`：回顾页、热力图、去年今日
- `features/search`：全局搜索和结果跳转

## 7. 数据层迁移方案

### 7.1 实体定义建议

鸿蒙版建议定义统一实体 `TimelineItemEntity`：

```ts
export interface TimelineItemEntity {
  id: string
  timestamp: number
  content: string
  iconName: string
  type: 'timeline' | 'inspiration' | 'moment'
  imagePath?: string
  isLivePhoto: boolean
  livePhotoVideoPath?: string
  borderColorHex?: string
}
```

说明：

- `timestamp` 建议使用毫秒时间戳存储
- 首版不建议直接把大图片二进制塞进数据库
- 图片与视频建议落本地文件，再在数据库中存路径

### 7.2 本地存储策略

建议拆成两层：

- 结构化数据：数据库
- 媒体文件：应用沙箱文件目录

建议原则：

- 文本、时间、类型、颜色存在数据库
- 图片和视频保存在文件系统
- 数据库只存文件相对路径

这样做的好处：

- 降低数据库膨胀
- 便于导入导出时打包媒体资源
- 后续更容易做数据修复和清理

### 7.3 Repository 层设计

建议建立统一仓储接口：

```ts
interface TimelineRepository {
  listAll(): Promise<TimelineItemEntity[]>
  listByDate(dayStart: number, dayEnd: number): Promise<TimelineItemEntity[]>
  listByType(type: string): Promise<TimelineItemEntity[]>
  search(keyword: string, scope?: string): Promise<TimelineItemEntity[]>
  create(item: TimelineItemEntity): Promise<void>
  update(item: TimelineItemEntity): Promise<void>
  remove(id: string): Promise<void>
  removeAll(): Promise<void>
}
```

目的：

- 页面层不直接耦合数据库 API
- 后续如果切换存储方案，改动更小

## 8. 备份协议兼容方案

### 8.1 当前 iOS 备份结构

从 `BackupManager.swift` 看，当前备份数据核心结构为：

- `BackupData`
- `BackupItem`

核心字段包括：

- `version`
- `exportDate`
- `items`

每条记录包括：

- `id`
- `timestamp`
- `content`
- `iconName`
- `type`
- `imageBase64`
- `isLivePhoto`
- `livePhotoVideoBase64`

### 8.2 鸿蒙版兼容目标

鸿蒙版应做到：

- 能读取 iOS 导出的备份文件
- 能导出结构一致或兼容增强版的备份文件
- 导入时具备去重能力

### 8.3 推荐兼容策略

第一阶段：

- 严格兼容现有 JSON 字段名
- 支持 ZIP 包中的 JSON 主文件
- 对图片和视频仍接受 Base64

第二阶段：

- 可扩展为“JSON + 媒体文件目录”的增强包格式
- 通过 `version` 字段区分不同打包策略

### 8.4 去重规则建议

先沿用现有逻辑：

- `content + timestamp + type` 视为重复

后续可增强为：

- 优先比对 `id`
- 若缺失或跨端生成不同，再回退到业务字段组合去重

## 9. 页面迁移设计

### 9.1 时间线页

目标：

- 展示指定日期的记录
- 支持新增文字记录
- 支持新增图片记录
- 支持打开日历切换日期
- 支持跳转搜索结果定位

鸿蒙首版建议能力：

- 顶部日期栏
- 列表展示
- 底部新增按钮
- 简化版日历选择器
- 图片选择与预览

建议暂缓：

- 完全一致的悬浮球行为
- 特殊拖拽边界动画
- iOS 风格的所有触觉反馈

### 9.2 瞬息页

目标：

- 展示 `inspiration` 内容流
- 支持新增、编辑、删除
- 支持标签点击筛选
- 支持搜索
- 支持设置圈选颜色

鸿蒙首版建议：

- 卡片列表
- 富文本中标签提取
- 标签筛选结果页
- 简单的操作菜单
- 基础颜色选择器

### 9.3 时光回顾页

目标：

- 汇总历史内容
- 支持热力图
- 支持去年今日
- 支持按日查看

鸿蒙首版建议：

- 回顾页概览卡
- 去年今日模块
- 月历按日查看

热力图如果实现成本较高，可拆到第二阶段。

### 9.4 搜索页

当前搜索支持：

- 全部
- 时间线
- 瞬息
- 瞬影

鸿蒙首版建议完整保留这个范围设计，因为：

- 用户心智稳定
- 与现有数据结构完全契合
- 实现成本可控

## 10. MVP 范围建议

### 10.1 第一阶段必须完成

- 底部三 Tab 骨架
- `TimelineItem` 数据模型
- 本地数据库与仓储封装
- 时间线浏览
- 新增/编辑/删除文字记录
- 瞬息列表与标签筛选
- 全局搜索
- 普通图片选择与展示
- 备份导入导出

### 10.2 第一阶段可以降级实现

- 回顾页视觉效果
- 热力图样式
- 封面卡片随机逻辑
- 浮层动画

### 10.3 第二阶段再做

- Live Photo 完整兼容
- 更复杂的图片/视频协同展示
- 高级视觉还原
- 更细的手势和动画体验

## 11. Live Photo 迁移建议

当前 iOS 已存储：

- 封面图片
- 对应视频数据
- `isLivePhoto` 标记

鸿蒙侧风险在于：

- 没有与 iOS Live Photo 完全同构的原生对象模型
- 播放与预览方式可能不同

建议策略：

第一阶段：

- 导入时保留 `isLivePhoto`
- 若有封面图则正常显示静态图
- 视频数据先保存但不强依赖首版展示

第二阶段：

- 把“Live Photo”降级抽象为“图片 + 可播放短视频”
- 在鸿蒙侧以组合媒体内容的方式呈现

## 12. 风险与难点

### 12.1 平台能力差异

- SwiftData 与鸿蒙数据库 API 差异大
- PhotosUI 与鸿蒙图库接口差异大
- Live Photo 无法保证完全一比一行为

### 12.2 媒体存储与备份体积

- 当前 iOS 备份使用 Base64，会显著增大体积
- 如果鸿蒙继续沿用，导入导出性能要重点测试

### 12.3 复杂 UI 还原成本

- 当前项目存在较多视觉效果和自定义交互
- 若首版追求像素级一致，会拖慢主链路完成

## 13. 推荐实施顺序

### 阶段 0：设计和对齐

- 盘点现有页面和业务规则
- 明确 MVP 范围
- 固化数据模型与备份协议

### 阶段 1：数据底座

- 建鸿蒙项目骨架
- 定义实体、DTO、Repository
- 完成本地存储
- 完成备份导入导出

### 阶段 2：主流程页面

- 底部 Tab
- 时间线页
- 瞬息页
- 全局搜索

### 阶段 3：回顾能力

- 时光回顾
- 去年今日
- 按日期浏览

### 阶段 4：增强体验

- 视觉打磨
- 媒体能力增强
- Live Photo 降级或增强支持

## 14. 建议的新线程执行方式

建议在新线程中按以下目标推进：

1. 先根据本仓库输出鸿蒙项目目录结构
2. 再定义数据模型和仓储接口
3. 优先实现备份导入导出兼容
4. 再逐页搭建 MVP

建议新线程的首条任务描述直接使用下面这段：

```text
请基于 /Users/sundusk/App/shuiTime 这个 iOS 项目，帮助我设计并实现一个鸿蒙原生版本。

要求：
1. 先分析现有数据模型、页面结构、业务规则
2. 优先抽离可迁移的产品能力，不直接照搬 SwiftUI
3. 鸿蒙版本采用原生 ArkUI/ArkTS 思路
4. 第一阶段先实现 MVP：时间线、瞬息、搜索、本地存储、图片附件、备份导入导出
5. 尽量兼容现有 BackupManager 的数据格式
6. 请先输出目录设计、模块拆分、数据模型、开发顺序，再开始写代码
```

## 15. 最终建议

对当前项目，最优迁移策略不是“共享代码”，而是“共享产品定义和数据协议”。

优先级建议如下：

1. 统一数据模型和备份格式
2. 完成鸿蒙 MVP 主链路
3. 保证 iOS 与鸿蒙的数据可迁移
4. 再逐步追平视觉和高级媒体能力

如果后续开始实际开发，建议再补两份文档：

- 数据契约文档
- 页面与组件映射文档

这样能把“设计决策”和“具体开发”拆开，后面无论你自己开发还是交给新的线程继续做，都会轻松很多。
