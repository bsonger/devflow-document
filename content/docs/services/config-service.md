---
title: "config-service"
weight: 32
---

# 🧪 config-service

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

- 配置挂载目录
- 最近一次同步到的文件
- 来源配置目录和来源 commit

想象成给同一辆车配不同的轮胎：赛道用光头胎，雨天用雨胎。

## 一个例子

**order-service 的基础配置（WorkloadConfig）：**

```yaml
replicas: 3
resources:
  size_class: "medium"
env:
  - name: SERVER_PORT
    value: "8080"
metrics:
  enabled: true
  port: 9090
  scrape_profile: "default"
```

**order-service 在测试环境的 AppConfig 记录：**

```yaml
application_id: order-service
environment_id: test
mount_path: /etc/config
source_directory: ecommerce/order-service/test
```

**order-service 在生产环境的 AppConfig 记录：**

```yaml
application_id: order-service
environment_id: prod
mount_path: /etc/config
source_directory: ecommerce/order-service/prod
```

发布时，DevFlow 读取同步得到的文件内容，再和基础配置一起进入最终渲染。

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
