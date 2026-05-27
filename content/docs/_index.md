---
title: "DevFlow 文档"
weight: 1
bookFlatSection: true
---

# DevFlow 文档中心

**DevFlow** 是一个云原生应用交付平台。它帮你把代码从仓库安全地送到生产环境，全程可控、可观测、可回滚。

> 如果你刚接触 DevFlow，建议先读 [快速开始](getting-started/)；如果你想先判断它适不适合你的团队，再读 [平台概览](overview/)。

---

## 你现在最适合从哪里开始

| 你的目标 | 建议阅读 |
|---------|---------|
| 我想 30 分钟内跑通一次最小发布 | [快速开始](getting-started/) |
| 我想先知道 DevFlow 解决什么问题 | [平台概览](overview/) |
| 我想理解系统边界和设计原则 | [架构设计](architecture/) |
| 我想了解具体某个服务负责什么 | [服务详解](services/) |
| 我想把平台部署到自己的集群 | [部署指南](deployment/) |

---

## 为什么需要 DevFlow

在没有 DevFlow 之前，发布一个应用通常是这样的：

```
改配置 → 手动打镜像 → 写 YAML → kubectl apply → 
盯着 Pod 看 → 发现有问题 → 紧急回滚 → 祈祷成功
```

有了 DevFlow 之后：

```
点发布按钮 → 自动构建 → 自动部署 → 实时看进度 → 安心下班
```

DevFlow 把发布过程中所有容易出错的地方都标准化了：配置管理、版本冻结、发布策略、运行时观察，全部自动化。

---

## 文档导航

### 新手入门

| 章节 | 适合谁 | 内容 |
|------|--------|------|
| [快速开始](getting-started/) | 第一次用 DevFlow | 5 分钟了解核心工作流，完成第一次发布 |
| [平台概览](overview/) | 想快速了解 DevFlow | 定位、能力、技术栈 |

### 理解 DevFlow

| 章节 | 适合谁 | 内容 |
|------|--------|------|
| [架构设计](architecture/) | 想了解系统怎么设计的 | 5 大服务、领域模型、发布生命周期 |
| [服务详解](services/) | 想深入了解某个服务 | meta-service、config-service、network-service、release-service、runtime-service |
| [核心概念](concepts/) | 对领域模型有疑问 | Project、Application、Manifest、Release 等概念解释 |

如果你想从代码组织本身入手理解后端仓库，可以直接看 [devflow-service 目录结构](architecture/devflow-service-layout/)。

### 使用指南

| 章节 | 适合谁 | 内容 |
|------|--------|------|
| [持续集成](ci/) | 配置 CI 流水线 | Tekton 标准流程、组件选型 |
| [持续交付](cd/) | 选择发布策略 | Rolling / Canary / Blue-Green 详解 |
| [可观测性](observability/) | 搭建监控体系 | Metrics / Logs / Traces |
| [部署指南](deployment/) | 部署 DevFlow 平台 | Kubernetes 部署步骤 |

---

## 核心特性一览

- **应用全生命周期管理** — 从代码仓库到生产运行，一站式管理
- **环境差异自动处理** — 开发/测试/生产配置隔离，不会搞混
- **三种发布策略** — Rolling（默认）、Canary（灰度）、Blue-Green（零停机）
- **不可变快照** — 每次发布都有完整快照，出问题一键回滚到任意历史版本
- **实时观察** — 发布过程中实时看 Pod 状态、流量切换进度
- **GitOps 交付** — 通过 Argo CD 实现声明式部署，所有变更可追溯
