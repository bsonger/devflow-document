---
title: "WorkloadConfig"
weight: 43
---

# 🧱 WorkloadConfig

**WorkloadConfig** 是应用的"出厂设置"，定义了应用在 Kubernetes 中怎么跑。

## 它回答什么问题

> 这个应用默认应该有几个副本？用多少 CPU？怎么知道它是不是挂了？

---

## 为什么需要它

想象一下，每个开发者在各自的 Kubernetes YAML 里写配置：

```yaml
# 小明的 order-service
replicas: 3
resources:
  size_class: "medium"

# 小红的 payment-gateway
replicas: 2
resources:
  size_class: "small"
```

小明和小红各自为政，标准不统一。运维同学想统一调资源限制，得去改几十个文件。

WorkloadConfig 就是来解决这个问题的：
- 每个应用有一份**标准化的基线配置**
- 运维团队可以统一调整资源策略
- 新应用创建时，可以直接复用已有模板

就像汽车的出厂配置：所有同款车都有相同的发动机参数、轮胎规格，4S 店可以按统一标准维护。

---

## 包含什么

### 副本数

```yaml
replicas: 3
```

应用跑几个 Pod。这是默认值，实际运行时可以通过 runtime-service 动态调整。

### 资源规格

```yaml
resources:
  size_class: "medium"
```

当前实现里，写入时推荐的是 **`size_class`**，例如：

- `small`
- `medium`
- `large`
- `xlarge`

具体的 `requests / limits` 会在下游渲染阶段展开，不建议在这里把它当作主写入接口来理解。

### 健康探针

K8s 通过探针判断 Pod 是不是健康：

```yaml
probes:
  liveness:
    path: "/health"
    port: "http"
    initial_delay_seconds: 30
    period_seconds: 10
```

| 探针 | 作用 | 失败会怎样 |
|------|------|-----------|
| **Liveness** | 还活着吗？ | 不健康就重启容器 |
| **Readiness** | 能接收流量吗？ | 不健康就移出负载均衡 |
| **Startup** | 启动完成了吗？ | 启动慢的应用用，避免被误杀 |

### 环境变量

```yaml
env:
  - name: "LOG_LEVEL"
    value: "info"
  - name: "SERVER_PORT"
    value: "8080"
```

当前实现里 `env` 是一个有序数组，适合表达稳定的基础环境变量。

### Metrics

```yaml
metrics:
  enabled: true
  port: 9090
  scrape_profile: "default"
```

这部分描述“这个应用是否暴露 metrics 监听口”，后续 release render 会据此生成相关运行时配置。

---

## 重要特性：不随环境变化

WorkloadConfig 属于 **Application**，不属于 Environment。

这意味着：order-service 在测试环境和生产环境，默认共享同一份应用级基线。

如果你要改副本数、探针、资源规格，应该优先理解为“修改这份应用基线”，而不是把它当成环境级开关。

这种设计避免了"测试环境改了副本数，不小心把生产也改了"的坑。

---

## 和发布渲染的关系

WorkloadConfig 是基础定义。实际部署时，Manifest / Release 渲染会把它翻译成最终 K8s 工作负载字段。

- Rolling 发布通常渲染成 `Deployment`
- Canary / Blue-Green 发布通常渲染成 `Rollout`

也就是说，`WorkloadConfig` 关注的是**应用级运行基线**，不是直接声明“我要生成哪种发布策略资源”。
