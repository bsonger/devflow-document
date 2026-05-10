---
title: "meta-service"
weight: 31
---

# 📚 meta-service

**档案管理员** — 所有应用、环境、集群的权威信息库。

## 它是做什么的

meta-service 管理 DevFlow 中的"户口本信息"：

- **Project** — 项目，比如"支付系统"
- **Application** — 单个应用，比如"支付网关"
- **Environment** — 运行环境，比如"测试环境"
- **Cluster** — Kubernetes 集群
- **ApplicationEnvironment** — 应用和环境的绑定关系

其他服务想要知道"这个应用叫什么名字"、"生产环境在哪个集群"，都来问 meta-service。

## 一个例子

当你在 DevFlow Console 上看到：

```
项目：电商中台
  └─ 应用：order-service
      └─ 环境：test → 集群：dev-cluster
      └─ 环境：prod → 集群：prod-cluster
```

这些信息全部来自 meta-service。

## 为什么需要它

没有 meta-service 的话，每个服务都要自己维护一份应用列表。改个应用名字，要改 5 个地方。

有了 meta-service，所有元数据只有一份**单一真相源**。改一次，全平台生效。

## API 入口

所有接口以 `/api/v1/meta/` 开头：

```
GET  /api/v1/meta/projects              # 项目列表
GET  /api/v1/meta/projects/{id}         # 项目详情
GET  /api/v1/meta/applications          # 应用列表
GET  /api/v1/meta/applications/{id}     # 应用详情
GET  /api/v1/meta/environments          # 环境列表
GET  /api/v1/meta/clusters              # 集群列表
```

## 关键设计

- **只读为主** — 大部分场景是其他服务来查询元数据，写入操作相对较少
- **下游服务解耦** — config-service、network-service 通过 `application_environment_id` 关联，不直接依赖 meta-service 的内部结构
