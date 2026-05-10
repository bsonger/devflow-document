---
title: "五大服务观测字段清单"
weight: 77
---

# 🧾 五大服务观测字段清单

<span class="df-badge">meta-service</span> <span class="df-badge">config-service</span> <span class="df-badge">network-service</span> <span class="df-badge">release-service</span> <span class="df-badge">runtime-service</span>

这页把“原则”进一步落到每个服务应该重点打哪些字段。

目标不是要求每条日志/每个 Span 都完全一样，而是给每个服务一份**最小但够用**的观测清单。

---

## 🧭 所有服务共同必备

### 启动层

- `service.name`
- `service.version`

### Collector 层

- `deployment.environment`
- `k8s.cluster.name`
- `k8s.namespace.name`
- `k8s.pod.name`

### 请求层

- `trace_id`
- `span_id`
- `http.method`
- `http.route`
- `http.status_code`

---

## 📚 meta-service

### 建议重点字段

- `devflow.project.id`
- `devflow.application.id`
- `devflow.environment.id`
- `devflow.cluster.id`
- `devflow.user.id`

### 典型观测场景

- 创建/更新项目
- 注册应用
- 创建环境
- 绑定应用到环境

### 推荐日志消息

- `project created`
- `application registered`
- `environment created`
- `application environment binding created`

---

## 🧩 config-service

### 建议重点字段

- `devflow.application.id`
- `devflow.environment.id`
- `devflow.config.kind`
- `devflow.config.mount_path`

### 典型观测场景

- AppConfig 创建/更新
- 配置仓库同步
- 渲染前配置读取

### 推荐日志消息

- `app config created`
- `config sync started`
- `config sync completed`
- `config read for rendering`

---

## 🌐 network-service

### 建议重点字段

- `devflow.application.id`
- `devflow.environment.id`
- `devflow.route.host`
- `devflow.route.path`
- `devflow.service.port`

### 典型观测场景

- Service 定义变更
- Route 定义变更
- 发布阶段网络配置读取

### 推荐日志消息

- `service spec saved`
- `route spec saved`
- `network spec loaded for release`

---

## 🚀 release-service

### 建议重点字段

- `devflow.project.id`
- `devflow.application.id`
- `devflow.environment.id`
- `devflow.manifest.id`
- `devflow.release.id`
- `devflow.intent.kind`
- `devflow.intent.status`
- `devflow.cluster.id`

### 典型观测场景

- 创建 Manifest
- 创建 Release
- 触发 Tekton
- 渲染部署包
- 推送 OCI bundle
- 创建 Argo CD Application
- 回滚

### 推荐日志消息

- `manifest created`
- `release created`
- `build triggered`
- `release rendering started`
- `release bundle published`
- `argo application created`
- `release rollback started`

> release-service 是 observability 字段最重的服务，因为它串起了完整发布链路。

---

## 🛠️ runtime-service

### 建议重点字段

- `devflow.application.id`
- `devflow.environment.id`
- `devflow.release.id`
- `devflow.cluster.id`
- `k8s.workload.kind`
- `k8s.workload.name`
- `k8s.pod.name`

### 典型观测场景

- Pod 状态变化
- Workload 健康状态更新
- 运维操作（重启/删 Pod/扩缩容）

### 推荐日志消息

- `workload observed`
- `pod ready status changed`
- `runtime operation requested`
- `runtime operation completed`

---

## ✅ 最小落地建议

如果你不想一口气把所有字段都打全，建议优先级如下：

### P0

- `service.name`
- `deployment.environment`
- `trace_id`
- `devflow.application.id`

### P1

- `devflow.release.id`
- `devflow.environment.id`
- `k8s.cluster.name`
- `k8s.pod.name`

### P2

- `devflow.manifest.id`
- `devflow.intent.kind`
- `devflow.intent.status`
- 依赖调用上下文（`db.operation` / `messaging.*`）

---

## 关联阅读

- [公共 Attributes](../attributes/)
- [结构化日志规范](../logging/)
- [Go 服务最小 OTel 接入示例](../go-example/)
