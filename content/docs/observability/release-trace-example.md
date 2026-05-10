---
title: "发布链路 Trace 示例"
weight: 80
---

# 🧵 发布链路 Trace 示例

<span class="df-badge">release-service</span> <span class="df-badge">runtime-service</span> <span class="df-badge">trace_id</span> <span class="df-badge">devflow.release.id</span>

这页不是讲概念，而是回答一个更实际的问题：

> **当一次发布变慢或失败时，一条“可排障”的 Trace 到底应该长什么样？**

适合的读者：

- 想验证 release-service observability 是否打通的开发者
- 想知道 `devflow.*` 字段该挂在哪些 Span 上的维护者
- 想从 Trace 继续跳日志、跳指标排查问题的值班工程师

读完后，你应该能完成一件事：

> **对照一条发布 Trace，判断自己的发布链路字段是否足够支撑排障。**

---

## 🧭 先看一条理想的发布链路

一次典型发布，链路通常会跨过这些阶段：

```mermaid
graph LR
    A[API: Create Release] --> B[Load App Context]
    B --> C[Create Manifest]
    C --> D[Trigger Tekton]
    D --> E[Render Bundle]
    E --> F[Push OCI Bundle]
    F --> G[Create Argo Application]
    G --> H[Observe Runtime Status]
```

如果 observability 接得足够完整，这些阶段应该出现在**同一条 Trace**里，而不是散落在多个互不关联的日志里。

---

## ✅ 根 Span 最少应该带什么

发布链路最重要的是入口 Span，也就是用户或系统真正发起发布请求的那一层。

### 推荐字段

| 字段 | 为什么需要 |
|------|------------|
| `trace_id` | 串起整条发布链路 |
| `service.name=release-service` | 明确入口服务 |
| `http.request.method` | 确认入口动作 |
| `http.route` | 确认入口 API |
| `devflow.project.id` | 识别项目 |
| `devflow.application.id` | 识别应用 |
| `devflow.environment.id` | 识别目标环境 |
| `devflow.release.id` | 识别这次发布 |

### 示例

```json
{
  "span.name": "POST /api/v1/release/releases",
  "service.name": "release-service",
  "http.request.method": "POST",
  "http.route": "/api/v1/release/releases",
  "devflow.project.id": "proj-001",
  "devflow.application.id": "app-123",
  "devflow.environment.id": "env-prod",
  "devflow.release.id": "rel-001"
}
```

如果根 Span 上连 `devflow.release.id` 都没有，后面即使子 Span 很多，也很难快速定位到“是哪次发布”。

---

## 🌳 推荐的 Span 树结构

下面是一棵更接近实际排障需求的 Span 树：

```text
POST /api/v1/release/releases
├── meta-service.GetApplication
├── meta-service.GetEnvironment
├── config-service.ListAppConfigs
├── network-service.GetRoutes
├── release.CreateManifest
├── tekton.TriggerPipelineRun
├── release.RenderBundle
├── registry.PushBundle
├── argocd.CreateApplication
└── runtime-service.WatchReleaseStatus
```

### 这棵树的意义

- **上半段**说明 release-service 在收集上下文
- **中间段**说明它在创建 Manifest / Release、触发构建、渲染 bundle
- **下半段**说明它已经进入部署与观察阶段

如果链路停在某一层，你就知道故障大概落在哪一段。

---

## 🧩 哪些 Span 必须带业务字段

不是每个 Span 都要打满所有 `devflow.*`，但关键节点必须带。

| Span | 建议字段 |
|------|----------|
| 入口 API Span | `devflow.project.id` `devflow.application.id` `devflow.environment.id` `devflow.release.id` |
| `release.CreateManifest` | `devflow.manifest.id` `devflow.application.id` |
| `tekton.TriggerPipelineRun` | `devflow.manifest.id` `devflow.release.id` `devflow.intent.kind=build` |
| `release.RenderBundle` | `devflow.manifest.id` `devflow.release.id` |
| `registry.PushBundle` | `devflow.release.id` |
| `argocd.CreateApplication` | `devflow.release.id` `devflow.environment.id` |
| `runtime-service.WatchReleaseStatus` | `devflow.release.id` `devflow.application.id` |

最简单的原则：

- **定位发布对象**靠 `devflow.release.id`
- **定位构建快照**靠 `devflow.manifest.id`
- **定位目标环境**靠 `devflow.environment.id`

---

## 📜 一条失败发布应该怎样出日志

Trace 只是骨架，日志负责补细节。

假设失败点出在 `argocd.CreateApplication`，理想的关键日志应该像这样：

```json
{
  "timestamp": "2026-05-10T15:21:08Z",
  "severity_text": "ERROR",
  "logger.name": "http.error",
  "body": "failed to create argo application",
  "service.name": "release-service",
  "trace_id": "2e71abb92e031efc2a7a1c4280959f4b",
  "span_id": "9fa312ab0044cd11",
  "devflow.application.id": "app-123",
  "devflow.environment.id": "env-prod",
  "devflow.release.id": "rel-001",
  "error.type": "argocd_api_error",
  "error.message": "permission denied"
}
```

这样的好处是：

- 从 Trace 能跳到这条日志
- 从日志也能反查这条 Trace
- 不看代码也知道失败发生在 Argo CD 创建阶段

---

## 📈 一条异常 Trace 应该怎样联动指标

如果 Canary 发布卡住，通常不是先从日志发现，而是先从指标发现：

1. Grafana 看到 `release-service` 错误率升高
2. 点击 exemplar 跳到异常 Trace
3. 在 Trace 里发现耗时集中在 `runtime-service.WatchReleaseStatus`
4. 再跳日志看具体是 Pod readiness 慢，还是 rollout condition 异常

所以相关指标至少应该能按这些维度聚合：

- `service.name`
- `http.route`
- `http.response.status_code`
- `deployment.environment.name`

不建议把 `devflow.release.id` 直接打成高频 metrics label；它更适合留在 Trace 和 Logs 中。

---

## 🚨 三种最常见的坏味道

### 1. Trace 有了，但看不出是哪次发布

现象：

- 只能看到 `POST /api/v1/release/releases`
- 没有 `devflow.release.id`
- 没有 `devflow.application.id`

后果：

- 只能知道“发布接口慢了”
- 不能知道“是哪次发布慢了”

### 2. 子 Span 很多，但字段不一致

现象：

- 有的 Span 用 `releaseId`
- 有的 Span 用 `devflow.release.id`
- 日志又写成 `release_id`

后果：

- 查询条件碎裂
- 关联分析变差

### 3. 整条链路断在跨服务调用上

现象：

- 入口 Span 存在
- 调 meta-service / runtime-service 时开了新 Trace
- 看不到父子关系

后果：

- 无法判断时间真正耗在哪个下游步骤

---

## 🧪 最小验收方式

如果你想确认发布链路已经“能排障”，建议至少验这 5 步：

1. 发起一次真实 Release
2. 在 Trace 后端按 `service.name=release-service` 找入口 Span
3. 确认入口 Span 带有：
   - `devflow.application.id`
   - `devflow.environment.id`
   - `devflow.release.id`
4. 确认能看到至少 3 个关键子 Span：
   - `tekton.TriggerPipelineRun`
   - `argocd.CreateApplication`
   - `runtime-service.WatchReleaseStatus`
5. 随机点一个失败或慢 Span，确认能按 `trace_id` 找到对应日志

如果这 5 步都能完成，这条链路就已经具备很强的排障价值。

---

## 关联阅读

- [发布生命周期](../../architecture/lifecycle/)
- [公共 Attributes](../attributes/)
- [结构化日志规范](../logging/)
- [五大服务观测字段清单](../service-checklist/)
- [OTel 接入检查清单](../onboarding-checklist/)
