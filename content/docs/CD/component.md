---
title: "CD 组件矩阵"
weight: 66
---

# CD 用到哪些工具

DevFlow 的 CD 依赖以下几个核心工具，各司其职。

---

## 核心组件

### Argo CD — GitOps 引擎

Argo CD 是 CD 的核心。它盯着 OCI Registry 里的部署包，一旦发现新版本，就自动同步到 Kubernetes 集群。

你可以把它理解成一个**自动同步器**：你更新了仓库里的配置，它自动帮你 apply 到集群。

### Argo Rollouts — 高级发布控制器

原生 Kubernetes 只支持简单的 Rolling Update。Argo Rollouts 扩展了这个能力，支持：

- **Canary** — 按权重逐步切流量
- **Blue-Green** — 两套实例并行，瞬时切换
- **Analysis** — 自动基于指标判断要不要继续

### Istio — 流量指挥官

Istio 负责控制流量怎么分配：

- **VirtualService** — 定义流量路由规则（权重、匹配条件）
- **DestinationRule** — 定义 Pod 分组（stable / canary）
- **Gateway** — 外部流量入口

没有 Istio，Canary 和 Blue-Green 就做不了流量控制。

### OCI Registry — 部署包仓库

DevFlow 把渲染好的 Kubernetes 配置打包成 OCI artifact，和镜像存在同一个仓库里。

好处：镜像和部署包一起版本管理，不会搞混。

---

## 组件关系

```
DevFlow
  └─ release-service ──→ OCI Registry
                              ↑
Argo CD ←─────────────────────┘
  └─ Argo Rollouts ←── Istio (VirtualService / DestinationRule)
                              ↓
                        Kubernetes
                              ↓
                        runtime-service
```

---

## 必须 vs 可选

| 组件 | Rolling | Canary | Blue-Green |
|------|---------|--------|------------|
| Argo CD | ✅ 必须 | ✅ 必须 | ✅ 必须 |
| OCI Registry | ✅ 必须 | ✅ 必须 | ✅ 必须 |
| Argo Rollouts | ❌ 不需要 | ✅ 必须 | ✅ 必须 |
| Istio | ❌ 不需要 | ✅ 必须 | ⚪ 可选 |

如果你只需要 Rolling 发布，Argo Rollouts 和 Istio 可以不装。
