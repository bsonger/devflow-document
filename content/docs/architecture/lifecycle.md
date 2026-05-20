---
title: "发布生命周期"
weight: 23
---

# 🧭 发布生命周期

<span class="df-badge">🧩 release-service</span> <span class="df-badge">{{< brand-icon name="tekton" alt="Tekton" >}} Tekton</span> <span class="df-badge">📦 OCI Registry</span> <span class="df-badge">{{< brand-icon name="argocd" alt="Argo CD" >}} Argo CD</span> <span class="df-badge">👀 runtime-service</span>

在 DevFlow 中发布一个应用，会经历 8 个阶段。这个流程由 `release-service` 牵头，串起 `meta-service`、`config-service`、`network-service`、Tekton、OCI Registry、Argo CD 和 `runtime-service`。

---

## 🗺️ 整体流程

```mermaid
graph LR
    A["1. 收集信息"] --> B["2. 冻结构建快照"]
    B --> C["3. 构建镜像"]
    C --> D["4. 冻结部署快照"]
    D --> E["5. 打包配置"]
    E --> F["6. 推送到仓库"]
    F --> G["7. 部署到集群"]
    G --> H["8. 观察状态"]
```

---

## 📥 阶段 1：收集发布上下文

**谁在干活**：`release-service`

你在 Console 上点了"发布"后，`release-service` 先去收集这次发布需要的上下文：

> "meta-service，这个应用属于哪个项目，目标环境是谁？"
> "config-service，这个应用和环境的工作负载配置是什么？"
> "network-service，这个应用暴露哪些 Service 和 Route？"

**输出**：一份完整的发布上下文

---

## 🧊 阶段 2：冻结构建快照（Manifest）

**谁在干活**：`release-service`

release-service 把阶段 1 收集到的信息打包成第一份快照，叫 **Manifest**：

```
应用: order-service
代码版本: main @ a1b2c3d4
基础配置: 3 副本 / 1Gi 内存 / 健康检查...
网络拓扑: 暴露 80 端口...
```

Manifest 一旦创建就**不能再改**。它记录了"这个应用在构建时刻长什么样"。

**输出**：Manifest ID

---

## 🏗️ 阶段 3：触发构建

**谁在干活**：`release-service` 触发 Tekton Pipeline

`release-service` 通知 Tekton："去构建这个版本的镜像"。

Tekton 开始跑标准流水线：

```
拉代码 → 静态扫描 → 跑测试 → 构建镜像
→ 生成 SBOM → 签名镜像 → 漏洞扫描 → 推送镜像仓库
```

构建完成后，release-service 把镜像地址更新到 Manifest 里。

**输出**：镜像 digest、SBOM、签名证明

---

## 🎫 阶段 4：冻结部署快照（Release）

**谁在干活**：`release-service`

构建成功后，release-service 创建第二份快照，叫 **Release**：

```
关联的构建: Manifest m-001
目标环境: production
环境配置: DB_HOST=prod-db, LOG_LEVEL=warn...
网络规则: host=order.example.com, TLS=true...
发布策略: Canary
```

Release 也**不能再改**。它记录了"这次发布要部署到哪、用什么配置"。

**输出**：Release ID

---

## 📦 阶段 5：渲染部署包

**谁在干活**：`release-service`

release-service 把所有配置叠加起来，生成最终的 Kubernetes 部署包：

```
WorkloadConfig（基础运行规格）
+ AppConfig（环境特殊配置）
+ Service（网络端口）
+ Route（外部访问规则）
= 完整的 K8s manifest
```

不同的发布策略会生成不同的资源：

| 策略 | 生成什么 |
|------|---------|
| Rolling | Deployment + Service |
| Canary | Rollout + VirtualService + DestinationRule |
| Blue-Green | Rollout + Active Service + Preview Service |

**输出**：完整的 K8s manifest bundle

---

## 📤 阶段 6：推送到仓库

**谁在干活**：`release-service` → OCI Registry

release-service 把渲染好的部署包打包成 OCI artifact，推送到 OCI Registry。

这样做的好处是：部署包和镜像放在一起，Argo CD 从一个地方就能拉齐所有东西。

**输出**：OCI artifact URL

---

## 🚀 阶段 7：部署到集群

**谁在干活**：`release-service` 触发 Argo CD，Argo CD 执行同步

`release-service` 创建 Argo CD Application，告诉它："去这个仓库拉取部署包，同步到生产集群"。

Argo CD 开始干活：

```
拉取 bundle → 解析 K8s 资源 → 同步到集群
→ Rolling: 逐步替换 Pod
→ Canary: 先给 10% 流量
→ Blue-Green: 先部署到 Preview
```

**输出**：Argo CD Application 状态

---

## 👀 阶段 8：观察状态

**谁在干活**：`runtime-service`

`runtime-service` 盯着 Kubernetes，实时看 Pod 的状态变化，然后回写给 `release-service`：

> "新版本 3/10 个 Pod 已经 Ready"
> "Canary 10% 流量切换完成，正在观察指标"

你在 Console 上看到的发布进度条、Pod 状态、流量切换百分比，全部来自这里。

**输出**：实时发布状态

---

## 🔄 Release 状态机

Release 从创建到完成，会经历以下状态：

```mermaid
stateDiagram-v2
    [*] --> Pending: 创建 Release
    Pending --> Rendering: 开始打包配置
    Rendering --> Publishing: 打包完成
    Publishing --> Deploying: 推送到仓库
    Deploying --> Running: Argo CD 开始部署
    Running --> Completed: 发布成功
    Running --> Failed: 超时或异常
    Failed --> RollingBack: 触发回滚
    RollingBack --> RolledBack: 回滚完成
    Completed --> [*]
    RolledBack --> [*]
```

### 状态说明

| 状态 | 含义 | 对应阶段 |
|------|------|---------|
| Pending | 刚创建，等待开始 | 阶段 4 |
| Rendering | 正在叠加配置生成 K8s manifest | 阶段 5 |
| Publishing | 正在把包推送到镜像仓库 | 阶段 6 |
| Deploying | Argo CD 正在同步资源 | 阶段 7 |
| Running | 正在执行发布策略 | 阶段 7 |
| Completed | 发布成功 | 阶段 8 |
| Failed | 发布失败 | — |
| RollingBack | 正在回滚 | — |
| RolledBack | 回滚完成 | — |

---

## 🧠 关键设计

### 为什么先冻结 Manifest，再冻结 Release？

因为构建和部署是两个独立的过程：

- **Manifest** 在构建前创建，记录"要构建什么"
- **Release** 在构建成功后创建，记录"要部署到哪"

如果构建失败，Manifest 已经存在但 Release 不会创建。你可以修复问题后重新构建，不用从头再收集信息。

### 为什么两份快照都要不可变？

假设发布后出了问题，你想回滚。如果快照是可变的，回滚时你可能会意外拿到一个"被同事改过"的配置，导致回滚也失败。

不可变快照保证了：**回滚到什么时刻，就精确恢复到那个时刻的状态**。
