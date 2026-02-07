---
title: "CD"
weight: 2
# bookFlatSection: false
# bookToc: true
# bookHidden: false
# bookCollapseSection: false
# bookComments: false
# bookSearchExclude: false
bookCollapseSection: true
---

# 持续交付（Continuous Delivery, CD）

## 🧭 速览

- 目标：让制品安全、可回滚地进入生产  
- 方法：声明式 + GitOps + 自动化发布策略  
- 关键能力：灰度、回滚、可观测  

## 📖 1. 什么是持续交付（CD）

持续交付（Continuous Delivery，简称 CD）是指将**通过持续集成（CI）验证后的制品（如镜像、配置、Manifest）**，以**自动化、可控、可回滚**的方式持续部署到各个环境（测试 / 预发 / 生产）。

CD 的核心目标包括：

- 快速交付业务价值
- 降低发布风险
- 支持灰度与回滚
- 发布过程可观测、可审计
- 尽量减少人工干预

---

## 🗺️ 2. 云原生场景下的 CD 位置

典型的软件交付链路如下：

Code Commit
→ CI（Build / Test / Scan / Sign）
→ Artifact（Image / Manifest）
→ CD（Deploy / Release Strategy）
→ Runtime（Service / Traffic）

在云原生体系中，CD 通常具备以下特征：

- 基于声明式配置（YAML / GitOps）
- 与 Kubernetes 深度集成
- 发布过程与流量治理解耦
- 强调可回滚与可观测性

---

## 🧩 3. 主流发布策略概览

| 发布策略 | 是否中断流量 | 是否支持灰度 | 回滚成本 | 实现复杂度 | 常见实现 |
|---------|--------------|--------------|----------|------------|----------|
| Recreate | 是 | 否 | 高 | 低 | Deployment |
| Rolling Update | 否 | 否 | 中 | 低 | Deployment |
| Blue / Green | 否 | 否 | 低 | 中 | Argo CD / Rollouts |
| Canary | 否 | 是 | 低 | 高 | Argo Rollouts |
| A/B Testing | 否 | 是 | 中 | 高 | Rollouts + 网关 |
| Shadow / Mirror | 否 | 是（不影响用户） | 无 | 高 | Service Mesh |

---

## 🔍 4. 发布策略详解

### 4.1 Recreate（重建发布）

**发布方式**

先终止旧版本 Pod，再启动新版本 Pod。

**特点**

- 发布期间存在服务中断
- 不支持并行版本

**适用场景**

- 内部系统
- 非核心服务
- 可接受短时间不可用的场景

**优缺点**

- 优点：实现简单
- 缺点：服务中断、无灰度能力

---

### 4.2 Rolling Update（滚动发布）

**发布方式**

新旧版本 Pod 同时存在，逐步用新版本替换旧版本。

**特点**

- Kubernetes 默认发布策略
- 通过 `maxSurge`、`maxUnavailable` 控制节奏

**适用场景**

- 大多数 Web 服务
- 对精细流量控制要求不高的业务

**优缺点**

- 优点：无中断、实现简单
- 缺点：无法控制具体流量比例，回滚能力有限

---

### 4.3 Blue / Green（蓝绿发布）

**发布方式**

同时运行两套完整环境（Blue 和 Green），通过切换流量完成发布。

**特点**

- 切流即完成发布
- 回滚只需切回旧版本

**适用场景**

- 对稳定性要求极高的系统
- 可接受双倍资源占用的场景

**优缺点**

- 优点：发布与回滚速度快
- 缺点：资源消耗较高，不支持渐进灰度

---

### 4.4 Canary（金丝雀发布）

**发布方式**

将一小部分流量（如 10%）引入新版本，逐步扩大比例。

**特点**

- 当前生产环境最主流的发布方式
- 可结合监控指标进行自动决策

**适用场景**

- 核心业务系统
- 高并发、高可用服务

**优缺点**

- 优点：风险可控、支持自动回滚
- 缺点：实现复杂，对监控和流量治理依赖高

---

### 4.5 A/B Testing（A/B 发布）

**发布方式**

基于用户特征（Header、Cookie、User ID）进行流量分组。

**特点**

- 用户级流量隔离
- 支持业务效果对比

**适用场景**

- 功能实验
- 产品效果验证
- 数据驱动决策

**优缺点**

- 优点：精细化控制用户流量
- 缺点：策略复杂，对网关能力要求高

---

### 4.6 Shadow / Traffic Mirroring（流量镜像）

**发布方式**

将生产流量复制一份发送给新版本，但不影响用户响应。

**特点**

- 不对真实用户生效
- 零风险验证新版本

**适用场景**

- 新架构验证
- 性能压测
- 行为回放测试

**优缺点**

- 优点：安全性极高
- 缺点：资源消耗大，无法验证真实响应结果

---

## ✅ 5. 发布策略选型建议

| 场景 | 推荐策略 |
|----|----|
| 内部系统 | Recreate / Rolling |
| 普通业务 | Rolling |
| 核心生产系统 | Canary |
| 高回滚要求 | Blue / Green |
| 功能实验 | A/B |
| 新系统验证 | Shadow |

---

## 🧰 6. 云原生 CD 最佳实践

- 构建与发布完全解耦
- 使用 Git 作为唯一事实源（GitOps）
- 发布过程必须可回滚
- 基于指标和 SLO 驱动发布决策
- 发布过程全链路可观测（Metric / Trace / Log）
- 所有发布行为可审计、可追溯

---

## 🧱 7. 常见 CD 技术栈参考

- GitOps：Argo CD
- 发布控制：Argo Rollouts
- 流量治理：Istio / NGINX / Gateway API
- 可观测性：Prometheus / OpenTelemetry
- 安全：Cosign / SBOM / Policy Engine

---

持续交付的本质不是“如何部署”，  
而是**如何安全、可控地把变化交付给用户**。
