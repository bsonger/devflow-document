---
title: "config-service"
weight: 32
---

# config-service

**配置专员** — 管理应用的运行时配置，确保不同环境的配置不会串台。

## 它是做什么的

config-service 管理两层配置：

### WorkloadConfig — 应用级基线

定义应用**不随环境变化**的运行规格：

- 副本数
- CPU / 内存限制
- 健康探针
- 启动命令和环境变量

想象成一个应用的"出厂设置"。

### AppConfig — 环境级差异

定义应用**在不同环境下**的特殊配置：

- 开发环境用开发数据库
- 生产环境用生产数据库
- 测试环境开 debug 日志，生产环境开 warn 日志

想象成给同一辆车配不同的轮胎：赛道用光头胎，雨天用雨胎。

## 一个例子

**order-service 的基础配置（WorkloadConfig）：**

```yaml
replicas: 3
resources:
  limits:
    cpu: "1000m"
    memory: "1Gi"
envs:
  - name: SERVER_PORT
    value: "8080"
```

**order-service 在测试环境的差异（AppConfig）：**

```yaml
config_data:
  DB_HOST: "postgres-test.internal"
  LOG_LEVEL: "debug"
  FEATURE_FLAG_NEW_CHECKOUT: "true"
```

**order-service 在生产环境的差异（AppConfig）：**

```yaml
config_data:
  DB_HOST: "postgres-prod.internal"
  LOG_LEVEL: "warn"
  FEATURE_FLAG_NEW_CHECKOUT: "false"
```

发布时，DevFlow 自动把基础配置和环境差异**叠加**在一起，生成最终的 Kubernetes 配置。

## 为什么分层

如果不分层，所有环境的配置混在一起，很容易出错：

- 小明改了测试环境的配置，不小心把生产环境也改了
- 发布时手动挑配置，漏了一个字段

分层之后：
- 基线变一次，所有环境自动继承
- 环境差异独立管理，互不干扰
- 发布时自动叠加，不会漏配

## API 入口

```
GET/POST/PUT/DELETE  /api/v1/config/workload-configs
GET/POST/PUT/DELETE  /api/v1/config/app-configs
```
