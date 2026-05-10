---
title: "快速开始"
weight: 5
bookCollapseSection: false
---

# 快速开始

这篇文档面向**第一次接触 DevFlow 的平台使用者**。

读完后，你应该能完成一件具体的事：**把一个示例应用发布到测试环境，并在 Console 里看到发布进度。**

---

## 你会得到什么

- 一个 `demo` 项目
- 一个 `hello-app` 应用
- 一个 `test` 测试环境
- 一次从“选择版本”到“观察发布状态”的最小闭环

如果你还不确定 DevFlow 适不适合你，先读 [平台概览](../overview/)；如果你只想尽快跑通一遍，继续往下看。

---

## 先理解 30 秒工作流

DevFlow 围绕一个简单的工作流运转：

```
注册应用 → 配置环境 → 选择版本 → 一键发布 → 观察状态
```

发布时，当前实现会分成两个显式步骤：

1. **创建 Manifest**：冻结“这次要构建什么”
2. **创建 Release**：冻结“这次要部署到哪个环境、用什么策略”

所以在快速开始里，你需要先创建 `manifest_id`，再基于这个 Manifest 创建 Release。

---

## 前置条件

开始之前，请确保你已经有：

- 一个可访问的 DevFlow 地址，例如 `https://devflow.example.com`
- 一个可用的 API Token
- 至少一个已接入的 Kubernetes Cluster
- 一个可构建的 Git 仓库示例应用

下面的示例统一使用这些环境变量：

```bash
export DEVFLOW_BASE_URL="https://devflow.example.com"
export DEVFLOW_TOKEN="<your-token>"
```

后续所有 `curl` 请求都默认带上：

```bash
-H "Authorization: Bearer $DEVFLOW_TOKEN" \
-H "Content-Type: application/json"
```

---

## 第一步：注册你的应用

在 DevFlow 中，一切从**应用（Application）**开始。

```
应用名称：payment-gateway
代码仓库：github.com/your-org/payment-gateway
```

一次注册，所有环境复用同一套配置基线。

## 第二步：配置环境差异

同一套应用，不同环境有不同的需求：

| 环境 | 数据库地址 | 日志级别 | 域名 |
|------|-----------|---------|------|
| 开发 | postgres-dev.internal | debug | payment-dev.example.com |
| 生产 | postgres-prod.internal | warn | payment.example.com |

DevFlow 的**环境配置（AppConfig）**自动把这些差异管理起来，发布时自动叠加，不用担心配错环境。

## 第三步：发起发布

选择要发布的版本，DevFlow 自动完成后续所有事情：

1. **冻结** — 把当前应用的完整状态快照保存下来（Manifest）
2. **构建** — 触发 CI 流水线，自动跑测试、扫描漏洞、构建镜像
3. **渲染** — 把应用配置 + 环境差异打包成 Kubernetes 部署包
4. **发布** — 通过 Argo CD 推送到集群
5. **观察** — 实时看 Pod 状态、发布进度

## 第四步：选择发布策略

根据业务重要程度，选择不同的发布方式：

- **Rolling（滚动更新）** — 适合内部工具，成本低
- **Canary（灰度发布）** — 适合核心服务，先给 10% 用户试用
- **Blue-Green（蓝绿部署）** — 适合关键业务，零停机切换

---

## 第一次发布：Hello World

假设你有一个简单的 HTTP 服务，想部署到测试环境。

### 1. 创建项目

```bash
curl -X POST "$DEVFLOW_BASE_URL/api/v1/meta/projects" \
  -H "Authorization: Bearer $DEVFLOW_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "demo", "description": "演示项目"}'
```

示例响应：

```json
{
  "id": "proj-xxx",
  "name": "demo"
}
```

### 2. 注册应用

```bash
curl -X POST "$DEVFLOW_BASE_URL/api/v1/meta/applications" \
  -H "Authorization: Bearer $DEVFLOW_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "project_id": "proj-xxx",
    "name": "hello-app",
    "repo_address": "github.com/your-org/hello-app"
  }'
```

说明：

- 当前实现里 `Application` 主要存项目归属、名称、仓库地址等元数据
- 默认发布策略不是 `Application` 的创建字段
- 发布策略在创建 `Release` 时指定

### 3. 创建测试环境

```bash
curl -X POST "$DEVFLOW_BASE_URL/api/v1/meta/environments" \
  -H "Authorization: Bearer $DEVFLOW_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "test",
    "cluster_id": "cluster-xxx"
  }'
```

说明：

- 当前实现的 `Environment` 只保存环境元数据和目标集群绑定
- 它**不接受用户自定义 `namespace` 字段**

### 4. 绑定应用到环境

```bash
curl -X POST "$DEVFLOW_BASE_URL/api/v1/meta/applications/app-xxx/environments" \
  -H "Authorization: Bearer $DEVFLOW_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "environment_id": "env-xxx"
  }'
```

### 5. 创建 AppConfig 记录

```bash
curl -X POST "$DEVFLOW_BASE_URL/api/v1/config/app-configs" \
  -H "Authorization: Bearer $DEVFLOW_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "application_id": "app-xxx",
    "environment_id": "env-xxx",
    "mount_path": "/etc/config"
  }'
```

说明：

- 当前实现中的 `AppConfig` 不是自由键值对 `config_data`
- 它更像“**环境级配置挂载记录**”
- 配置文件内容通过后续 repo sync 进入 `files / latest_revision`

### 6. 创建 Manifest

Manifest 负责冻结这次构建要消费的应用级输入。

```bash
curl -X POST "$DEVFLOW_BASE_URL/api/v1/release/manifests" \
  -H "Authorization: Bearer $DEVFLOW_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "application_id": "app-xxx",
    "git_revision": "main"
  }'
```

示例响应：

```json
{
  "data": {
    "id": "m-xxx",
    "application_id": "app-xxx",
    "git_revision": "main",
    "status": "Pending"
  }
}
```

### 7. 基于 Manifest 创建 Release

```bash
curl -X POST "$DEVFLOW_BASE_URL/api/v1/release/releases" \
  -H "Authorization: Bearer $DEVFLOW_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "manifest_id": "m-xxx",
    "environment_id": "env-xxx",
    "strategy": "rolling"
  }'
```

### 8. 查看发布进度

```bash
curl "$DEVFLOW_BASE_URL/api/v1/release/releases/rel-xxx" \
  -H "Authorization: Bearer $DEVFLOW_TOKEN"
```

如果一切正常，你会看到类似下面的状态流转：

```text
pending -> rendering -> publishing -> deploying -> running -> completed
```

到这一步，你就已经完成了第一次最小发布闭环。

---

## 下一步

| 如果你想... | 阅读 |
|-------------|------|
| 深入了解 DevFlow 的架构 | [架构设计](../architecture/) |
| 了解 5 个服务各自的作用 | [服务详解](../services/) |
| 搞清楚 Project、Application、Release 这些概念 | [核心概念](../concepts/) |
| 学习如何选择发布策略 | [持续交付](../cd/) |
| 把 DevFlow 部署到自己的集群 | [部署指南](../deployment/) |
