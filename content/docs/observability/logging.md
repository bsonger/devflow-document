---
title: "结构化日志规范"
weight: 76
---

# 📜 结构化日志规范

<span class="df-badge">Logs</span> <span class="df-badge">trace_id</span> <span class="df-badge">devflow.*</span>

这页回答两个问题：

1. **一条 DevFlow 日志最少应该长什么样？**
2. **哪些字段适合放日志，哪些不适合？**

目标不是把所有内容都塞进日志，而是保证日志能和 Metrics / Traces 稳定关联。

---

## ✅ 一条最小可用日志

推荐每条关键日志至少包含：

| 字段 | 作用 |
|------|------|
| `timestamp` | 发生时间 |
| `log.level` | 级别 |
| `log.message` | 人能读懂的事件描述 |
| `service.name` | 哪个服务打的 |
| `trace_id` | 跳转到链路 |
| `span_id` | 对齐当前 Span |

如果是发布链路里的关键日志，再加：

- `devflow.application.id`
- `devflow.release.id`
- `devflow.manifest.id`（如果处在构建/渲染链路）

---

## 🧱 推荐字段分层

### 基础字段

| Key | 说明 | 必须 |
|-----|------|------|
| `timestamp` | 时间戳 | ✅ |
| `log.level` | 日志级别 | ✅ |
| `log.message` | 日志消息 | ✅ |
| `service.name` | 服务名 | ✅ |
| `deployment.environment` | 环境 | ✅ |

### 关联字段

| Key | 说明 | 必须 |
|-----|------|------|
| `trace_id` | Trace ID | 强烈建议 |
| `span_id` | Span ID | 建议 |
| `k8s.pod.name` | Pod 名 | 建议 |

### DevFlow 业务字段

| Key | 说明 | 何时打 |
|-----|------|---------|
| `devflow.project.id` | 项目 ID | 入口日志 |
| `devflow.application.id` | 应用 ID | 应用相关操作 |
| `devflow.environment.id` | 环境 ID | 环境相关操作 |
| `devflow.manifest.id` | 构建快照 ID | 构建 / 渲染链路 |
| `devflow.release.id` | 发布 ID | 发布 / 回滚 / 状态回写 |
| `devflow.intent.kind` | Worker 任务类型 | 异步任务 |
| `devflow.intent.status` | Worker 任务状态 | 异步任务 |

---

## ✍️ 推荐日志示例

### HTTP 入口日志

```json
{
  "timestamp": "2026-05-10T14:12:01Z",
  "log.level": "INFO",
  "log.message": "request accepted",
  "service.name": "release-service",
  "deployment.environment": "prod",
  "trace_id": "2e71abb92e031efc2a7a1c4280959f4b",
  "span_id": "abc123def456",
  "http.method": "POST",
  "http.route": "/api/v1/release/releases",
  "devflow.application.id": "app-123",
  "devflow.environment.id": "env-456"
}
```

### 发布阶段日志

```json
{
  "timestamp": "2026-05-10T14:12:03Z",
  "log.level": "INFO",
  "log.message": "release rendering started",
  "service.name": "release-service",
  "trace_id": "2e71abb92e031efc2a7a1c4280959f4b",
  "devflow.application.id": "app-123",
  "devflow.manifest.id": "mf-001",
  "devflow.release.id": "rel-001"
}
```

### 错误日志

```json
{
  "timestamp": "2026-05-10T14:12:08Z",
  "log.level": "ERROR",
  "log.message": "failed to create argo application",
  "service.name": "release-service",
  "trace_id": "2e71abb92e031efc2a7a1c4280959f4b",
  "devflow.release.id": "rel-001",
  "error.type": "argocd_api_error",
  "error.message": "permission denied"
}
```

---

## 🚫 不建议直接打进日志的内容

| 内容 | 原因 |
|------|------|
| 明文 token / secret | 敏感信息 |
| 完整 SQL 参数 | 可能泄露业务数据 |
| 巨大的 response body | 成本高、可读性差 |
| 高频 debug 噪声 | 淹没关键信息 |

---

## 🧭 日志级别建议

| 级别 | 适用场景 |
|------|----------|
| `DEBUG` | 本地调试、低层细节 |
| `INFO` | 关键业务事件、状态变化 |
| `WARN` | 可恢复异常、重试、降级 |
| `ERROR` | 明确失败、用户感知问题、需要处理 |

发布链路里，建议至少把这些事件打成 `INFO`：

- release created
- manifest created
- rendering started / completed
- deploy started / completed
- rollback started / completed

---

## ✅ 最佳实践

1. **人能读懂 `log.message`**，机器读结构化字段
2. **字段名和 Trace 统一**，不要日志叫 `releaseId`、Trace 叫 `devflow.release.id`
3. **关键事件打 INFO，失败打 ERROR**
4. **所有错误日志尽量带 `trace_id` 和业务对象 ID**

---

## 关联阅读

- [Labels / Attributes 规范](../standard/)
- [公共 Attributes](../attributes/)
- [Go 服务最小 OTel 接入示例](../go-example/)
