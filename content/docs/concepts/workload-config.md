---
title: "WorkloadConfig"
weight: 43
---

# WorkloadConfig

**WorkloadConfig** 是应用的"出厂设置"，定义了应用在 Kubernetes 中怎么跑。

## 它回答什么问题

> 这个应用默认应该有几个副本？用多少 CPU？怎么知道它是不是挂了？

## 包含什么

### 副本数

```yaml
replicas: 3
```

应用跑几个 Pod。这是默认值，实际运行时可以通过 runtime-service 动态调整。

### 资源限制

```yaml
resources:
  limits:
    cpu: "1000m"      # 最多用 1 核
    memory: "1Gi"     # 最多用 1GB 内存
  requests:
    cpu: "100m"       # 至少需要 0.1 核
    memory: "128Mi"   # 至少需要 128MB 内存
```

- **limits** — 资源上限，超过会被限制或杀掉
- **requests** — 调度时保证的最低资源，K8s 按这个来分配节点

### 健康探针

K8s 通过探针判断 Pod 是不是健康：

```yaml
probes:
  liveness_probe:
    http_get:
      path: "/health"
      port: 8080
    initial_delay_seconds: 30
    period_seconds: 10
```

| 探针 | 作用 | 失败会怎样 |
|------|------|-----------|
| **Liveness** | 还活着吗？ | 不健康就重启容器 |
| **Readiness** | 能接收流量吗？ | 不健康就移出负载均衡 |
| **Startup** | 启动完成了吗？ | 启动慢的应用用，避免被误杀 |

### 环境变量和启动命令

```yaml
envs:
  - name: "LOG_LEVEL"
    value: "info"
  - name: "SERVER_PORT"
    value: "8080"

command: ["./server"]
args: ["--port=8080"]
```

---

## 重要特性：不随环境变化

WorkloadConfig 属于 **Application**，不属于 Environment。

这意味着：order-service 在测试环境和生产环境，默认都是 3 个副本、1Gi 内存。如果生产环境需要更多资源，那不是改 WorkloadConfig，而是应该：

1. 在生产环境的 ApplicationEnvironment 中通过 AppConfig 覆盖（如果支持）
2. 或者调整 WorkloadConfig 本身的基线（影响所有环境）

这种设计避免了"测试环境改了副本数，不小心把生产也改了"的坑。

---

## 和工作负载类型的关系

WorkloadConfig 是基础定义。实际部署时，会根据应用的类型生成不同的 K8s 工作负载：

- 普通无状态服务 → Deployment
- 有状态服务 → StatefulSet
- 守护进程 → DaemonSet
