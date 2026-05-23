---
title: "发布生命周期"
weight: 23
---

# 🧭 发布生命周期

<span class="df-badge">🧩 release-service</span> <span class="df-badge">{{< brand-icon name="tekton" alt="Tekton" >}} Tekton</span> <span class="df-badge">📦 OCI Registry</span> <span class="df-badge">{{< brand-icon name="argocd" alt="Argo CD" >}} Argo CD</span> <span class="df-badge">👀 runtime-service</span>

DevFlow 的发布，本质上是一条“先冻结并上传 OCI，再从 OCI 执行发布”的流水线。
它不是一串临时操作，而是一套可追踪、可取消、可回滚的生命周期。

这篇文档按原理来讲：先看整条链路怎么分层，再看每一层失败、取消和回滚该怎么处理。

---

## 一句话理解

一次发布会经历 2 个大层：

1. `Freeze to OCI`
2. `Deploy from OCI`

核心原则只有三个：

- **快照不可变**: `Manifest` 和 `Release` 都是冻结点，创建后不应随意改写
- **责任分离**: `release-service` 先负责冻结与上传，再负责从 OCI 驱动发布，`runtime-service` 负责观察事实，Argo CD 负责集群执行
- **结果优先于意图**: 取消只是一个意图，真正的结果要看当前阶段是否已经进入不可逆动作

---

## 整体结构

```mermaid
graph LR
    A["Freeze to OCI"] --> B["Deploy from OCI"]
    B --> C["runtime-service 观察"]
    C --> D["完成 / 失败 / 取消 / 回滚"]
```

这条链路里，冻结和发布不再混在一个入口里，失败和取消语义会更干净。

---

## 1. Freeze to OCI

这一层做的是“把将要发布的东西固定下来”。

输入通常来自：

- `meta-service`：应用、环境、集群
- `config-service`：工作负载配置、应用配置
- `network-service`：Service、Route
- 代码仓库和版本信息

这一层的输出是：

- `Manifest`
- 冻结后的镜像/Bundle 事实
- 不可变 OCI artifact

### 失败怎么处理

- 元数据缺失: 直接失败，不进入后续阶段
- 配置不一致: 返回错误，让用户先修复配置
- 目标环境不存在: 停止本次发布
- 任何 freeze 失败都不应该触发集群发布

### 取消怎么处理

- 这一层最容易取消
- 取消后只需要停止继续冻结和上传
- 可以保留 Manifest 作为证据，但不应该进入发布执行

### 回滚怎么处理

- 这一层通常不需要回滚
- 因为还没有进入真实集群动作

---

## 2. Deploy from OCI

这一层从已经冻结好的 OCI artifact 开始，负责真正发布。

这一层会：

- 创建 `Release`
- 渲染部署上下文
- 创建 Argo CD Application
- 让 `runtime-service` 观察执行结果

输入通常包括：

- OCI artifact
- 目标环境
- 发布策略
- runtime / release 观察与回写链路

### 失败怎么处理

- Argo handoff 失败: 保留 OCI 产物，标记发布失败
- 集群同步失败: 进入失败或回滚
- runtime 回写失败: 继续保留发布事实，等待重试或补偿

### 取消怎么处理

- 如果还没进入集群执行，取消可以直接停掉
- 如果已经进入部署或切流，取消要按回滚语义处理
- 取消不等于删除 OCI 产物

### 回滚怎么处理

- 如果已经影响集群，就要回到上一个稳定 OCI artifact 对应的 Release
- 回滚不删除冻结事实，只恢复运行态

---

## 3. runtime-service 观察真实状态

这一步开始，系统不再只看“想要什么”，而是看“集群现在到底是什么”。

`runtime-service` 会观察：

- workload 是否 Ready
- Pod 是否健康
- rollout 是否推进
- release 状态是否需要回写

### 失败怎么处理

- 观察不到目标: 说明 identity 或 label 链路有问题
- 状态无法判断: 说明不能盲目推进
- 回写失败: 说明 release 侧同步出了问题

### 取消怎么处理

- 观察阶段的取消不是“立刻结束”
- 它通常意味着停止继续推进，并等待当前真实状态收敛
- 如果已经切流，取消要上升为回滚语义

### 回滚怎么处理

- 如果集群已经开始实际替换资源，回滚是正确的失败处理方式
- 回滚不是删除记录，而是把运行态恢复到上一个可用快照

---

## 4. 完成、失败、取消、回滚

### 完成

当渲染、发布、handoff、观察都成功，发布才算完成。

### 失败

失败分三类：

- 冻结前失败: 直接终止
- Handoff 前失败: 保留快照，等待修复或重试
- 集群执行中失败: 进入回滚或失败终态

### 取消

取消是主动意图，不等于回滚。

- 早期阶段: 可以直接停止
- 中期阶段: 需要标记取消并停止后续推进
- 后期阶段: 往往必须回滚

### 回滚

回滚只在“已经影响真实运行”之后才有意义。

回滚通常会：

- 回到上一个稳定 `Release`
- 保留当前失败/取消证据
- 不抹掉本次发布痕迹

### 一眼看懂差异

| 结果 | 发生了什么 | 还能继续吗 | 需要保留什么 |
|---|---|---|---|
| 完成 | OCI 已冻结并成功发布，集群已收敛 | 不需要 | 最终发布记录 |
| 失败 | Freeze 或 Deploy 任何一侧失败 | 取决于失败层级 | 冻结元数据、OCI 证据、状态、错误证据 |
| 取消 | 用户主动停止继续推进 | Freeze 阶段可以，Deploy 阶段通常不行 | 当前阶段、取消时间、证据 |
| 回滚 | 系统把已生效的变更收回 | 结束后重新开始新版本发布 | 失败版本和回滚证据 |

---

## 状态理解

可以把发布状态理解成四类：

| 类别 | 含义 |
|---|---|
| Pending | 还在准备或等待执行 |
| Running | 已进入执行或观察中 |
| Failed | 发生不可忽略的错误 |
| Canceled / RolledBack | 发布被主动中止或安全恢复 |

关键点是：

- `Canceled` 不是 `Succeeded`
- `Failed` 不一定立刻等于 `RolledBack`
- `RolledBack` 说明系统已经把发布影响收回去了

---

## 为什么要这样设计

因为发布的风险分布不均匀。

- 越早阶段越容易取消
- 越靠后阶段越需要回滚语义
- 只保留“成功/失败”太粗糙，不能准确反映真实过程

所以 DevFlow 把发布拆成“冻结、渲染、发布、handoff、观察、收尾”几层，让每一层都能独立失败、独立取消、独立回滚。

---

## 相关文档

- [CD 总览](../CD/)
- [Rolling 发布](../CD/rolling/)
- [Canary 发布](../CD/canary/)
- [Blue-Green 发布](../CD/blue-green/)
- [release-service](../services/release-service.md)
- [runtime-service](../services/runtime-service.md)
