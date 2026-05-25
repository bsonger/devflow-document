---
title: "release-service"
weight: 34
---

# 🚀 release-service

**发布经理** — 发布全流程的编排者。从你在 Console 上点"发布"按钮，到应用真正跑在 Kubernetes 上，全是 `release-service` 在操心。

---

## 它是做什么的

`release-service` 管理四样东西：

### Manifest — 构建前快照

发布开始时，`release-service` 先把当前应用的完整状态冻结成一份不可变的快照（代码版本、镜像、基础配置、网络拓扑）。

> 详细概念见 [Manifest 与 Release](../../concepts/manifest-release/)。

### Release — 部署前快照

构建成功后，`release-service` 再创建第二份快照，绑定 Manifest 和目标环境。

> 详细概念见 [Manifest 与 Release](../../concepts/manifest-release/)。

### Intent — 执行意图

记录异步执行流程的运行状态：

```
kind: release
status: Running
claimed_by: release-worker-1
attempt_count: 1
```

用于观察 build / release 这类异步执行任务的状态、租约、重试和错误信息。

### Image — 镜像信息

记录构建产物的元数据：

- 镜像 digest（唯一标识）
- SBOM（软件成分清单）
- 签名信息

---

## 一次发布的完整旅程

在当前两段式模型里，`release-service` 的职责分成两步：

### 第一步：Freeze to OCI

`release-service` 先去找其他服务打听情况：

> "meta-service，order-service 的代码仓库在哪？"
> "config-service，order-service 的基础配置和环境差异是什么？"
> "network-service，这个应用暴露哪些端口和路由？"

然后它：

1. 冻结 `Manifest`
2. 渲染 release bundle
3. 发布 OCI artifact

这一步结束时，系统已经知道“要发什么”，但还没有真正进入集群执行。

### 第二步：Deploy from OCI

当 OCI 产物准备好后，`release-service` 再从这个产物开始真正部署：

1. 创建 `Release`
2. 创建 Argo CD Application
3. 触发同步
4. 交给 `runtime-service` 观察真实状态并回写

这一步结束时，系统才真正开始回答“有没有发成功、需不需要回滚”。

也正因为这条链路是 pipeline task 驱动的，所以 operator 想增加一个新的发布动作时，通常不是去改 `release-service` 的代码，而是去改流水线里的 task 组合。

比如：

- 想增加一次额外扫描，就加一个 task
- 想在切流前做人工审批，就插一个 task
- 想把某个检查前移或后移，就调整 task 顺序

release-service 只需要认识这些阶段的状态变化，不需要知道每个步骤内部到底做了什么。

### 如果中途点了取消

取消也分两类：

- **Freeze 阶段取消**：直接停止冻结和上传，保留证据，不进入发布执行
- **Deploy 阶段取消**：停止继续推进；如果已经开始影响集群，就必须按回滚语义处理

---

## 三种发布策略

release-service 支持三种发布策略，在 Deploy from OCI 阶段确定：

### Rolling — 滚动更新

最简单的方式：一个一个替换旧版本 Pod。

适合：内部工具、低优先级服务、资源敏感的场景。

### Canary — 灰度发布

先给 10% 用户用新版本，观察 5 分钟。没问题就扩大到 30%、50%、100%。

适合：核心 API、用户-facing 的服务、需要风险控制。

每个灰度阶段都会自动检查指标（错误率、延迟），不达标就自动回滚。

### Blue-Green — 蓝绿部署

先部署一套完整的新版本（Green），在 Preview 环境里验证。没问题就一键切换流量，瞬时完成。

适合：金融核心、必须零停机的业务、数据库 schema 变更。

---

## 为什么这样设计

### 快照 = 可追溯

传统发布最大的痛点是"不知道当时到底发了什么"。DevFlow 通过 Freeze to OCI 解决这个问题。详情见 [Manifest 与 Release](../../concepts/manifest-release/)。

### 异步 = 不卡主流程

Freeze 可能要 10 分钟，Deploy 可能要 5 分钟。release-service 不会傻等，而是：

1. 先冻结并上传 OCI
2. 再从 OCI 触发发布
3. 每个阶段的状态都写到对应记录里

你可以随时查询进度，不用守着屏幕等。

### 状态机 = 可预期

Release 有明确的状态流转：

```
Pending → Rendering → Publishing → Deploying → Running → Completed
                                                      ↘ Failed
```

每个状态都有明确的含义，不会模棱两可。

如果用户主动取消，会进入：

```
Running → Canceling → Canceled
```

如果已经切流或进入不可安全停止的阶段，取消可能会转成：

```
Running → Canceling → RollingBack → RolledBack
```

这表示“不是简单停掉”，而是为了保证集群状态可控，继续做收尾处理。
