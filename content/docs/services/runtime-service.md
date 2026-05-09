---
title: "runtime-service"
weight: 35
---

# runtime-service

**运维值班** — 实时观察 Kubernetes 集群，执行运维操作。

## 它是做什么的

runtime-service 是 DevFlow 与 Kubernetes 之间的**眼睛和手**：

### 看 — 实时观察集群状态

- 各个 workload（Deployment / StatefulSet / DaemonSet）跑了多少个 Pod，有多少 Ready
- 每个 Pod 的状态、重启次数、所在节点
- Pod 日志

### 动 — 执行运维操作

- 删除一个卡住的 Pod（让它重新调度）
- 重启一个 workload
- 调整副本数

### 写 — 回写发布进度

发布过程中，runtime-service 把 rollout 的实时进度回写给 release-service：

> "新版本 3/10 个 Pod 已经 Ready 了"  
> "Canary 10% 流量阶段已完成"

Console 上看到的发布进度条，数据来自这里。

## 为什么不用数据库

runtime-service 是 DevFlow 中**唯一不连 PostgreSQL** 的服务。

Kubernetes 的状态变化太快了：Pod 可能在几秒内创建、销毁、重启。如果每个变化都写数据库，数据库会被压垮。

runtime-service 的做法是：
- 启动时，通过 Kubernetes List API 全量拉取一次状态
- 之后通过 Watch API 实时监听变化
- 所有状态存在**内存索引**里

查询时直接从内存读，毫秒级响应。Console 上刷新 Pod 列表，不需要等数据库。

## 一个例子

你在 Console 上看到：

```
Workload: order-service
  期望副本: 10
  Ready: 8
  Updated: 8
  异常: 0

Pods:
  order-service-abc12  Running  节点: node-01
  order-service-def34  Running  节点: node-02
  order-service-ghi56  Pending   节点: — (资源不足)
```

这些信息全部来自 runtime-service 对 Kubernetes 的实时观察。

## API 入口

```
GET     /api/v1/runtime/workloads              # Workload 列表
GET     /api/v1/runtime/workloads/{id}         # Workload 详情
GET     /api/v1/runtime/pods                   # Pod 列表
GET     /api/v1/runtime/pods/{name}/logs       # Pod 日志
POST    /api/v1/runtime/pods/{name}/delete     # 删除 Pod
POST    /api/v1/runtime/workloads/{id}/restart # 重启 Workload
POST    /api/v1/runtime/workloads/{id}/scale   # 调整副本数
```
