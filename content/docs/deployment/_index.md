---
title: "部署指南"
weight: 80
---

# ☸️ 部署指南

把 DevFlow 平台部署到自己的 Kubernetes 集群。

---

## 🧭 先选路径

在开始之前，先决定你要哪一种部署目标：

| 🎯 你的目标 | 📝 建议路径 |
|---------|---------|
| 先把平台跑起来，验证基本发布流程 | 先看本页的“最小化部署”，再读 [部署步骤](guide/) 中的端到端验证 |
| 直接搭生产可用环境 | 直接按 [部署步骤](guide/) 从前置检查一路执行到可观测性配置 |

---

## ✅ 前置条件

| 🧩 组件 | 🔢 版本 | 🎯 用途 |
|------|------|------|
| {{< brand-icon name="kubernetes" alt="Kubernetes" >}} Kubernetes | 1.30+ | 运行平台 |
| Istio | 1.24+ | 流量治理 |
| Argo CD | 3.2+ | GitOps 部署 |
| Argo Rollouts | 1.8+ | 高级发布策略 |
| PostgreSQL | 16+ | 数据存储 |
| Tekton | 1.10+ | CI 流水线 |
| OCI Registry | — | 镜像和部署包存储 |

---

## 🪜 部署步骤概览

```
1. 准备 K8s 集群
2. 部署 Istio
3. 部署 Argo CD
4. 部署 Argo Rollouts
5. 部署 PostgreSQL
6. 部署 DevFlow 5 个服务
7. 配置 Ingress
8. 验证部署
9. 配置 Tekton
10. 配置监控
11. 验证端到端流程
```

详细步骤见 [部署步骤](guide/)。

---

## 🧪 最小化部署

如果你只是想快速体验 DevFlow，可以用以下最小组合：

```
Kubernetes 集群
├── Istio（Canary 可选）
├── Argo CD（部署）
├── PostgreSQL（数据库）
└── DevFlow 5 服务
```

如果你只验证 **Rolling** 发布：

- **必须**：Kubernetes、Argo CD、PostgreSQL、DevFlow 5 服务
- **可选**：Istio、Argo Rollouts、Tekton、完整观测栈

如果你还要验证 **Canary / Blue-Green**：

- 再补装 **Argo Rollouts**
- Canary 再额外需要 **Istio**
