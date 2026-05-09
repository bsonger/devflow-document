---
title: "部署指南"
weight: 80
---

# 部署指南

把 DevFlow 平台部署到自己的 Kubernetes 集群。

---

## 前置条件

| 组件 | 版本 | 用途 |
|------|------|------|
| Kubernetes | 1.30+ | 运行平台 |
| Istio | 1.24+ | 流量治理 |
| Argo CD | 3.2+ | GitOps 部署 |
| Argo Rollouts | 1.8+ | 高级发布策略 |
| PostgreSQL | 16+ | 数据存储 |
| Tekton | 1.10+ | CI 流水线 |
| OCI Registry | — | 镜像和部署包存储 |

---

## 部署步骤概览

```
1. 准备 K8s 集群
2. 部署 Istio
3. 部署 Argo CD
4. 部署 Argo Rollouts
5. 部署 PostgreSQL
6. 部署 DevFlow 5 个服务
7. 配置 Ingress
8. 验证部署
9. 配置监控
10. 配置 Tekton
```

详细步骤见 [部署步骤](guide/)。

---

## 最小化部署

如果你只是想快速体验 DevFlow，可以用以下最小组合：

```
Kubernetes 集群
├── Istio（流量治理）
├── Argo CD（部署）
├── PostgreSQL（数据库）
└── DevFlow 5 服务
```

Canary 和 Blue-Green 需要 Argo Rollouts，Rolling 发布不需要。
