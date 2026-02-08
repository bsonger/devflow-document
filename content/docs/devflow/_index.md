---
title: "devflow"
weight: 4
bookCollapseSection: true
---

# 🧩 Devflow（平台 API 核心）

Devflow 是平台的 **核心 API 服务**，类似于 Kubernetes 的 `kube-apiserver`：

- 统一承接平台内外部请求入口
- 作为控制面核心，负责编排与状态治理
- 提供标准 API，解耦上层 UI 与下层控制器

## 🎯 核心职责

- **API 聚合入口**：统一接入 Console、CLI、Webhook
- **业务与发布编排**：管理应用、发布、流程与状态机
- **状态归一化**：聚合 CI/CD/监控状态，输出统一状态视图
- **权限与审计**：鉴权、配额、审计日志与操作追踪

## 🧭 与 kube-apiserver 的类比

| 维度 | Devflow | kube-apiserver |
|------|---------|----------------|
| 入口 | 平台 API 入口 | K8s API 入口 |
| 角色 | 平台控制面核心 | K8s 控制面核心 |
| 对接对象 | Console / Controller / Plugin | kubectl / controller / scheduler |
| 状态存储 | MongoDB / 内部存储 | etcd |
| 资源模型 | 应用 / 发布 / 流程 | Pod / Service / Deployment |

## 🔄 典型调用链

Devflow Console → Devflow API → Controller / Plugin → Mongo

## ✅ 关键价值

- 统一入口，降低系统耦合度
- 统一状态，提升可观测与可运维性
- 标准接口，提升扩展与集成效率
