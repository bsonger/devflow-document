---
title: "Architecture"
weight: 1
---

# 🏗️ CD 架构图（Architecture）

下面是 CD 核心发布链路与控制闭环的整体关系图。

## 🗺️ Mermaid 版

```mermaid
flowchart LR
  Dev[Developer] -->|Release| Devflow[Devflow Console / Job]
  Devflow --> Argo[Argo CD]
  Argo --> App[Application]
  App --> Rollout[Argo Rollouts]

  subgraph Release[Release Strategy]
    Canary[Canary]
    BG[Blue/Green]
    Rolling[Rolling]
  end

  Rollout --> Release
  Release --> Svc[Service / Gateway]
  Svc --> Users[Users]

  Argo -. watch .-> Ctrl[Devflow Controller]
  Rollout -. watch .-> Ctrl
  Ctrl --> Mongo[(MongoDB)]

  Svc --> Metrics[Metrics / Traces / Logs]
  Metrics --> Grafana[Grafana]
```

## ✅ 关键说明

- **触发**：Devflow Console / Job 创建并驱动发布流程
- **发布**：Rollouts 负责策略执行（Canary / Blue-Green / Rolling）
- **闭环**：Controller 监听状态回写 Mongo，形成可观测发布闭环
- **验证**：发布过程依赖指标与链路进行自动或人工决策
