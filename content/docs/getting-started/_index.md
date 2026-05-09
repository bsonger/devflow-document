---
title: "快速开始"
weight: 5
bookCollapseSection: false
---

# 快速开始

用 5 分钟了解 DevFlow 能做什么，以及如何在平台上完成第一次应用发布。

---

## DevFlow 是什么

想象你管理着几十个微服务，每个服务都有开发环境、测试环境、预发布环境、生产环境。每次发布都要：

- 改一堆配置文件（还总把测试环境的配置带到生产）
- 盯着 Kubernetes 看 Pod 有没有起来
- 出问题不知道回滚到哪个版本
- 半夜被叫醒修发布故障

**DevFlow 就是来解决这些问题的。**

它把应用的元数据、配置、网络、发布流程全部标准化，让你像点按钮一样完成一次安全可控的发布。

---

## 核心工作流程

DevFlow 围绕一个简单的工作流运转：

```
注册应用 → 配置环境 → 选择版本 → 一键发布 → 观察状态
```

### 第一步：注册你的应用

在 DevFlow 中，一切从**应用（Application）**开始。

```
应用名称：payment-gateway
代码仓库：github.com/your-org/payment-gateway
部署类型：Canary（灰度发布）
```

一次注册，所有环境复用同一套配置基线。

### 第二步：配置环境差异

同一套应用，不同环境有不同的需求：

| 环境 | 数据库地址 | 日志级别 | 域名 |
|------|-----------|---------|------|
| 开发 | postgres-dev.internal | debug | payment-dev.example.com |
| 生产 | postgres-prod.internal | warn | payment.example.com |

DevFlow 的**环境配置（AppConfig）**自动把这些差异管理起来，发布时自动叠加，不用担心配错环境。

### 第三步：发起发布

选择要发布的版本，DevFlow 自动完成后续所有事情：

1. **冻结** — 把当前应用的完整状态快照保存下来（Manifest）
2. **构建** — 触发 CI 流水线，自动跑测试、扫描漏洞、构建镜像
3. **渲染** — 把应用配置 + 环境差异打包成 Kubernetes 部署包
4. **发布** — 通过 Argo CD 推送到集群
5. **观察** — 实时看 Pod 状态、发布进度

### 第四步：选择发布策略

根据业务重要程度，选择不同的发布方式：

- **Rolling（滚动更新）** — 适合内部工具，成本低
- **Canary（灰度发布）** — 适合核心服务，先给 10% 用户试用
- **Blue-Green（蓝绿部署）** — 适合关键业务，零停机切换

---

## 第一次发布：Hello World

假设你有一个简单的 HTTP 服务，想部署到测试环境。

### 1. 创建项目

```bash
curl -X POST https://devflow.bei.com/api/v1/meta/projects \
  -d '{"name": "demo", "description": "演示项目"}'
```

### 2. 注册应用

```bash
curl -X POST https://devflow.bei.com/api/v1/meta/applications \
  -d '{
    "project_id": "proj-xxx",
    "name": "hello-app",
    "repo_url": "github.com/your-org/hello-app",
    "type": "Rolling"
  }'
```

### 3. 创建测试环境

```bash
curl -X POST https://devflow.bei.com/api/v1/meta/environments \
  -d '{
    "name": "test",
    "cluster_id": "cluster-xxx",
    "namespace": "hello-test"
  }'
```

### 4. 绑定应用到环境

```bash
curl -X POST https://devflow.bei.com/api/v1/meta/application-environments \
  -d '{
    "application_id": "app-xxx",
    "environment_id": "env-xxx"
  }'
```

### 5. 配置环境变量

```bash
curl -X POST https://devflow.bei.com/api/v1/config/app-configs \
  -d '{
    "application_environment_id": "ae-xxx",
    "config_data": {
      "LOG_LEVEL": "debug",
      "ENV": "test"
    }
  }'
```

### 6. 一键发布

```bash
curl -X POST https://devflow.bei.com/api/v1/release/releases \
  -d '{
    "manifest_id": "m-xxx",
    "environment_id": "env-xxx",
    "strategy": "Rolling"
  }'
```

然后就可以在 DevFlow Console 里看到发布进度了。

---

## 下一步

| 如果你想... | 阅读 |
|-------------|------|
| 深入了解 DevFlow 的架构 | [架构设计](../architecture/) |
| 了解 5 个服务各自的作用 | [服务详解](../services/) |
| 搞清楚 Project、Application、Release 这些概念 | [核心概念](../concepts/) |
| 学习如何选择发布策略 | [持续交付](../cd/) |
| 把 DevFlow 部署到自己的集群 | [部署指南](../deployment/) |
