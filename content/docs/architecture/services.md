---
title: "五大微服务"
weight: 21
---

# 五大微服务

DevFlow 由 5 个独立服务组成。你可以把它们理解成一个发布团队里的 5 个角色。

---

## 服务总览

| 角色比喻 | 服务 | 核心职责 | 数据存储 |
|---------|------|---------|---------|
| 档案管理员 | meta-service | 管理应用、环境、集群的元数据 | PostgreSQL |
| 配置专员 | config-service | 管理应用配置和环境差异 | PostgreSQL |
| 网络工程师 | network-service | 管理网络拓扑和访问入口 | PostgreSQL |
| 发布经理 | release-service | 编排发布全流程 | PostgreSQL |
| 运维值班 | runtime-service | 观察集群状态，执行运维操作 | 内存索引 |

---

## meta-service — 档案管理员

**管什么**：Project、Application、Environment、Cluster、ApplicationEnvironment

**一句话**：所有应用的"户口本"都存在这里。其他服务想知道"这个应用叫什么名字"、"生产环境在哪个集群"，都来问它。

**为什么独立出来**：元数据相对稳定，独立后不会被频繁变更影响。同时保证所有服务看到的应用信息是一致的。

---

## config-service — 配置专员

**管什么**：WorkloadConfig、AppConfig

**一句话**：管理"应用默认怎么跑"（WorkloadConfig）和"这个环境有什么特殊要求"（AppConfig）。

**核心设计**：配置分层。
- WorkloadConfig 是出厂设置，不随环境变化
- AppConfig 是环境适配器，随环境变化

发布时自动叠加，测试环境不会串到生产配置。

---

## network-service — 网络工程师

**管什么**：Service、Route

**一句话**：管理"应用暴露了哪些端口"（Service）和"外部怎么访问这个环境"（Route）。

**核心设计**：网络和配置一样分层。
- Service 是应用的固有属性（我有哪些端口）
- Route 是环境相关的（这个环境用什么域名）

---

## release-service — 发布经理

**管什么**：Manifest、Release、Intent、Image

**一句话**：发布全流程的编排者。你点了"发布"后，它负责收集信息、冻结快照、触发构建、渲染配置、推送部署包、通知 Argo CD、接收状态回写。

**核心设计**：冻结点模式。
- Manifest：构建前快照，记录"构建时刻的应用状态"
- Release：部署前快照，记录"这次发布的完整上下文"

两份快照都不可变，确保发布可重现、可回滚。

---

## runtime-service — 运维值班

**管什么**：RuntimeSpec、RuntimeObservedPod、RuntimeObservedWorkload、RuntimeOperation

**一句话**：盯着 Kubernetes 集群，实时汇报 workload 和 pod 的状态，同时帮你执行运维操作（删 Pod、重启、扩缩容）。

**核心设计**：PostgreSQL-free。
- 所有状态存在内存里，从 K8s API 实时拉取
- 查询毫秒级响应，Console 刷新不卡顿
- 运维操作直接调 K8s API，不绕数据库

---

## 为什么拆成 5 个服务

| 服务 | 变更频率 | 为什么需要独立 |
|------|---------|--------------|
| meta-service | 低 | 元数据稳定，独立出来不会频繁重启 |
| config-service | 中 | 配置变更多，需要独立扩展 |
| network-service | 中 | 网络策略复杂，独立管理更安全 |
| release-service | 高 | 发布逻辑最复杂，迭代最快 |
| runtime-service | 高 | 查询量最大，需要水平扩展 |

拆成 5 个服务的好处：
- 独立升级，不影响其他服务
- 按需扩展（runtime-service 通常要更多实例）
- 故障隔离，一个服务挂了不会拖垮整个平台
