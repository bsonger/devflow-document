# 云原生 Canary 发布实战：Argo CD + Argo Rollouts + Istio

Canary 发布是将新版本的流量逐步引入生产环境的一种发布策略，用于 **降低风险、快速回滚、灰度验证**。在 Kubernetes 环境下，结合 Argo CD、Argo Rollouts 和 Istio 可以实现全自动化 Canary 发布。

---

## 1. 技术栈说明

| 组件 | 作用 | 说明 |
|------|------|------|
| **Argo CD** | GitOps CD 平台 | 自动同步 Kubernetes 资源与 Git 仓库，实现声明式部署 |
| **Argo Rollouts** | 发布控制器 | 提供 Canary、Blue/Green、实验性发布策略，并与服务网格集成 |
| **Istio** | 服务网格 | 流量管理、路由控制、指标采集，实现按比例灰度流量 |
| **Prometheus / Metrics** | 指标监控 | 用于自动判断 Canary 健康和触发回滚 |

---

## 2. 基本原理

1. **Argo CD** 负责将应用 Manifest（Deployment、Service、Rollout 等）同步到集群。
2. **Argo Rollouts** 替代原生 Deployment，对 Pod 版本的发布进行控制（如逐步增量）。
3. **Istio VirtualService / DestinationRule** 控制请求流量，将部分流量导向 Canary Pod。
4. **Metrics & Analysis**：Rollouts 可以根据指标（如错误率、延迟）自动判断 Canary 是否健康。
5. **回滚 / 推进**：
   - 如果指标正常，Rollout 自动增加新版本流量直至 100%。
   - 如果异常，Rollout 自动回滚到旧版本。

---