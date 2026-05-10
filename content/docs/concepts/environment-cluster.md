---
title: "Environment 与 Cluster"
weight: 42
---

# 🌍 Environment 与 Cluster

## Cluster — Kubernetes 集群

Cluster 就是 Kubernetes 集群，是应用真正跑起来的地方。

### 例子

```
Cluster: dev-cluster
  位置: 北京机房
  用途: 开发测试

Cluster: prod-cluster
  位置: 上海机房
  用途: 生产环境
```

DevFlow 支持接入多个集群，你可以把不同环境映射到不同集群，甚至把一个环境的应用分发到多个集群。

---

## Environment — 环境

Environment 是一个**逻辑运行环境**，比如开发、测试、预发布、生产。

### 例子

```yaml
名称: production
所在集群: prod-cluster
```

```yaml
名称: test
所在集群: dev-cluster
```

### 环境隔离

Environment 通过三种机制实现隔离：

1. **集群绑定隔离** — 每个 Environment 绑定一个目标 Cluster
2. **配置隔离** — AppConfig 和 Route 跟随应用-环境关系表达环境差异
3. **网络隔离** — 不同环境可以绑定不同的访问入口

> 当前 `devflow-service` 实现里，`Environment` 本身**不接受用户写入 `namespace` 字段**。

---

## ApplicationEnvironment — 应用绑定到环境

当应用要部署到某个环境时，需要先建立绑定关系。这个绑定关系叫 **ApplicationEnvironment**。

### 为什么要先绑定

想象你想把 `order-service` 部署到 `test` 环境：

1. 先创建绑定：`order-service` + `test` = `order-service-test`
2. 然后给这个绑定配置环境专属的东西：
   - AppConfig（测试数据库地址、debug 日志）
   - Route（测试域名）

```mermaid
graph TB
    A["Application: order-service"]
    E1["Environment: test"]
    E2["Environment: prod"]

    AE1["order-service @ test"]
    AE2["order-service @ prod"]

    A --> AE1
    A --> AE2
    AE1 --> E1
    AE2 --> E2

    AC1["AppConfig: DB=test-db"]
    AC2["AppConfig: DB=prod-db"]
    R1["Route: test.example.com"]
    R2["Route: example.com"]

    AE1 --> AC1
    AE1 --> R1
    AE2 --> AC2
    AE2 --> R2
```

### 绑定后有什么用

绑定后，你就可以：
- 为不同环境配置不同的数据库地址
- 为不同环境配置不同的域名
- 分别查看每个环境下的发布历史

---

## 常见环境划分

| 环境 | 用途 | 发布频率 | 策略建议 |
|------|------|---------|---------|
| dev | 开发调试 | 随时 | Rolling |
| test | 功能测试 | 每天多次 | Rolling |
| staging | 集成测试 | 每天 1-2 次 | Canary |
| prod | 生产环境 | 按需 | Canary 或 Blue-Green |

---

## Cluster 和 Environment 的关系

```mermaid
graph TB
    C["Cluster: prod-cluster"]
    E1["Environment: prod"]
    E2["Environment: staging"]

    C --> E1
    C --> E2
```

**规则**：
- 一个 Cluster 可以承载多个 Environment
- 一个 Environment 只能属于一个 Cluster
- 当前实现以环境元数据和集群绑定为主，不把 namespace 作为 Environment 的用户输入字段
