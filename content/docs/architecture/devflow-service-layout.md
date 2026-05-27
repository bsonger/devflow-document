---
title: "devflow-service 目录结构"
weight: 24
---

# 🗂️ devflow-service 目录结构

这篇文档专门回答一个很实际的问题：

> 打开 `devflow-service` 仓库后，每一个目录到底是干什么的？

这里描述的是当前仓库的真实结构，不是未来规划图，也不是已经废弃的旧 layout。

---

## 一句话先看懂

`devflow-service` 是一个 Go monorepo，核心结构可以先记成这 4 层：

1. `cmd/` 放可运行服务入口
2. `internal/` 放业务实现
3. `api/` 放对外契约
4. `docs/` 放当前实现文档和规则

如果你第一次进仓库，优先看：

1. `AGENTS.md`
2. `README.md`
3. `cmd/`
4. `internal/`
5. `docs/system/`

---

## 顶层目录总览

当前仓库根目录主要包含这些内容：

```text
devflow-service/
├── AGENTS.md
├── Dockerfile
├── Makefile
├── README.md
├── api/
├── bin/
├── cmd/
├── docker/
├── docs/
├── gateway/
├── internal/
├── scripts/
├── test/
├── go.mod
└── go.sum
```

下面按目录逐个介绍。

---

## 根目录文件

### `AGENTS.md`

这是仓库的启动契约文档。

它定义了：

- 进入仓库后优先读哪些文档
- 当前仓库的权威来源顺序
- 哪些名字是当前事实，哪些只是未来边界名词
- 修改 API、目录结构、迁移边界时的约束

如果是 AI Agent 或第一次接手这个仓库的工程师，先读它最省时间。

### `README.md`

这是给工程师的最短入口说明。

主要介绍：

- 当前仓库承载哪些服务
- 资源关系怎么理解
- 仓库结构怎么分层
- 常用开发与验证命令有哪些

### `Makefile`

统一收敛常用开发命令和验证命令。

例如：

- 构建服务
- 运行服务
- 格式检查
- OpenAPI 校验

### `Dockerfile`

仓库当前生效的根级打包契约。

它描述整体镜像构建方式，但不会替代每个业务目录的职责边界。

### `go.mod` / `go.sum`

Go monorepo 的模块根。

这两个文件说明当前仓库使用的是单根模块方式，而不是多模块或 `go.work` 布局。

---

## `api/`

`api/` 放的是契约面，不是业务实现。

当前子目录：

- `api/openapi/`
- `api/proto/`

### `api/openapi/`

这里存放服务的 OpenAPI 契约文件。

当前重点包括：

- 各服务自己的 OpenAPI 文件
- 聚合视图 `devflow.yaml`

什么时候要改这里：

- 新增或修改 HTTP 路由
- 修改请求体、响应体、分页格式、错误格式
- 修改资源字段或枚举

简单说，只要接口对外行为变了，这里就应该同步更新。

### `api/proto/`

这是为协议定义预留的目录。

当前它属于契约层的一部分，用来承接 protobuf 等非 HTTP 契约，而不是运行时代码。

---

## `bin/`

`bin/` 是本地构建产物目录。

这里不是源码目录，而是生成目录，用来放：

- `meta-service`
- `config-service`
- `network-service`
- `release-service`
- `runtime-service`

本地 `go build` 生成的二进制应该放在这里，而不应该散落到仓库根目录。

---

## `cmd/`

`cmd/` 放可运行进程的入口，每个服务一个目录。

当前有 5 个服务入口：

- `cmd/meta-service/`
- `cmd/config-service/`
- `cmd/network-service/`
- `cmd/release-service/`
- `cmd/runtime-service/`

每个入口目录通常只做 4 件事：

1. 读取配置
2. 初始化日志、数据库、Tracing 等基础设施
3. 组装模块
4. 启动 HTTP 服务或运行时循环

`cmd/` 不应该堆业务逻辑、SQL 或复杂发布编排。

---

## `docker/`

`docker/` 用来放 Docker 相关辅助内容。

它的职责更偏向镜像构建或容器运行辅助材料，不是业务代码区，也不是部署资源主目录。

如果你在排查镜像打包、基础镜像、构建上下文之类的问题，通常会顺着这里看。

---

## `docs/`

`docs/` 是 `devflow-service` 仓库里的实现文档和规则中心。

当前主要子目录包括：

- `docs/api/`
- `docs/architecture/`
- `docs/archive/`
- `docs/generated/`
- `docs/guides/`
- `docs/index/`
- `docs/observability/`
- `docs/policies/`
- `docs/resources/`
- `docs/services/`
- `docs/superpowers/`
- `docs/system/`

### `docs/api/`

介绍 API 的统一规则、契约说明和接口组织方式。

适合在这些场景阅读：

- 改 handler
- 改 DTO
- 改分页
- 改错误格式
- 改 request-id 或 auth 中间件

### `docs/architecture/`

放系统架构、关系图和整体设计说明。

它帮助你理解大图景，例如：

- 5 个服务怎么协作
- 发布生命周期怎么流转
- 领域模型怎么组织

### `docs/archive/`

历史材料归档区。

这里的内容可以帮助理解演进背景，但不能直接当作当前实现事实。

### `docs/generated/`

自动生成或汇总型文档产物目录。

如果某些内容是脚本或工具生成的，一般会收在这里，而不是手写在核心说明文档中。

### `docs/guides/`

给开发者和维护者的操作指南。

例如：

- 本地开发流程
- 验证顺序
- 改动提交流程
- 某些专项操作手册

### `docs/index/`

文档导航入口。

如果你要重整文档结构、补索引、优化阅读路径，这里通常是起点之一。

### `docs/observability/`

记录日志、指标、Tracing、运行可观测性相关文档。

适合在这些场景查阅：

- 补 metrics
- 看 trace 设计
- 排查发布状态回写链路
- 明确日志规范

### `docs/policies/`

长期约束和工程规则目录。

这是非常重要的一层，典型内容包括：

- Go monorepo 目录规范
- Docker 基线
- API contract policy
- 验证规则

如果你要改目录结构、抽象层次、依赖方向，这里比一般说明文档优先级更高。

### `docs/resources/`

按资源讲业务模型和行为约束。

例如某些资源的：

- 字段含义
- 生命周期
- 关系边界
- API 暴露方式

### `docs/services/`

按服务介绍职责边界和实现要点。

如果你想快速知道 `release-service` 或 `runtime-service` 该负责什么，不该负责什么，这里很有用。

### `docs/superpowers/`

这个目录承接历史规划、执行计划和部分 AI/工程协作资料。

当前子目录里可以看到：

- `docs/superpowers/plans/`
- `docs/superpowers/specs/`

它更偏设计过程沉淀，不是当前事实的最高权威来源。

### `docs/system/`

这里是当前系统实现事实的重要来源。

通常会包括：

- 当前架构说明
- 恢复指南
- 领域模型
- 流程说明
- 数据与运行时基线

如果要判断“现在系统到底是怎么工作的”，这一层通常最值得先看。

---

## `gateway/`

`gateway/` 当前不是业务主实现区。

从现在仓库内容看，这里主要保留了说明文档，用来表达网关层相关背景或约束，不是主要的运行时代码目录。

---

## `internal/`

`internal/` 是整个仓库最核心的业务实现区。

这里按业务域拆分，而不是按“控制器/模型/仓储”这种横切方式混放。

当前主要子目录包括：

- `internal/app/`
- `internal/appconfig/`
- `internal/application/`
- `internal/applicationenv/`
- `internal/cluster/`
- `internal/configservice/`
- `internal/environment/`
- `internal/intent/`
- `internal/manifest/`
- `internal/networkservice/`
- `internal/platform/`
- `internal/project/`
- `internal/release/`
- `internal/route/`
- `internal/runtime/`
- `internal/service/`
- `internal/shared/`
- `internal/workloadconfig/`

下面逐个看。

### `internal/app/`

这是应用级装配层的一部分。

当前可见内容主要是路由汇总与应用入口拼装，例如统一注册 HTTP router。

它的作用更像“把各个 domain module 接起来”，而不是定义某个业务资源。

### `internal/appconfig/`

负责 `AppConfig` 资源的实现。

这是环境维度的配置差异层，通常会有：

- `domain/` 定义领域模型
- `repository/` 处理存储
- `service/` 编排业务逻辑
- `transport/` 暴露接口

### `internal/application/`

负责 `Application` 资源。

这是应用元数据边界的核心目录之一，承载应用本身的领域定义和 CRUD 逻辑。

### `internal/applicationenv/`

负责 `ApplicationEnvironment` 资源。

它表达的是：

> 哪个应用绑定到哪个环境

这是很多环境级能力的关系入口。

### `internal/cluster/`

负责 `Cluster` 资源。

它描述环境最终运行在哪个 Kubernetes 集群，以及和集群元信息相关的逻辑。

### `internal/configservice/`

这是 `config-service` 进程级的聚合接入层之一。

当前主要可见的是 transport router，用来把配置相关 domain 接到 `config-service` 的 HTTP 服务中。

它不取代 `appconfig/` 或 `workloadconfig/` 这些具体业务目录，而更偏服务级装配。

### `internal/environment/`

负责 `Environment` 资源。

这里定义环境本身的领域对象与读写逻辑，例如 staging、production 这类环境实体。

### `internal/intent/`

负责发布意图 `Intent` 相关实现。

这个目录和发布控制面相关，表达“用户想执行什么动作”以及该动作进入系统后的持久化与处理逻辑。

### `internal/manifest/`

负责 `Manifest` 资源。

`Manifest` 是构建前冻结点，所以这里通常围绕这些能力展开：

- 保存构建快照
- 固化 workload、service、image 等构建输入
- 提供查询与列表能力

### `internal/networkservice/`

这是 `network-service` 进程级聚合接入层之一。

当前主要承担 network 相关 HTTP router 装配，把 `service/`、`route/` 等资源能力接到服务入口。

### `internal/platform/`

这是基础设施层，不属于某个单独业务域。

当前子目录包括：

- `internal/platform/config/`
- `internal/platform/configrepo/`
- `internal/platform/db/`
- `internal/platform/dbsql/`
- `internal/platform/httpx/`
- `internal/platform/k8s/`
- `internal/platform/logger/`
- `internal/platform/observer/`
- `internal/platform/oci/`
- `internal/platform/otel/`
- `internal/platform/routercore/`
- `internal/platform/runtime/`

它们分别大致承担这些职责：

- `config/`：读取和组织进程配置
- `configrepo/`：和配置仓库交互的基础设施能力
- `db/`：数据库基础封装
- `dbsql/`：SQL 辅助能力
- `httpx/`：HTTP 基础能力
- `k8s/`：Kubernetes 访问与封装
- `logger/`：日志初始化与适配
- `observer/`：观察与事件处理公共能力
- `oci/`：OCI registry 相关基础能力
- `otel/`：Tracing、Metrics、OTel 集成
- `routercore/`：路由装配公共能力
- `runtime/`：运行时基础封装

这层的核心原则是：

> 可以通用，但不能带业务语义。

### `internal/project/`

负责 `Project` 资源。

这是最上层组织维度的元数据目录，用来承接项目级信息与相关接口。

### `internal/release/`

这是发布域最复杂的目录之一，负责 `Release` 以及发布状态机相关逻辑。

当前子目录包括：

- `internal/release/config/`
- `internal/release/control/`
- `internal/release/domain/`
- `internal/release/repository/`
- `internal/release/runtime/`
- `internal/release/service/`
- `internal/release/strategy/`
- `internal/release/support/`
- `internal/release/transport/`

可以这样理解：

- `config/`：发布域自身配置
- `control/`：发布控制状态机、超时、失败处理、控制决策
- `domain/`：发布领域模型与规则
- `repository/`：发布相关存储
- `runtime/`：发布执行时的运行支撑
- `service/`：发布主流程编排
- `strategy/`：Rolling、Canary、Blue-Green 等策略相关实现
- `support/`：发布域内部使用的支撑模型
- `transport/`：HTTP 等接口适配

如果你在排查“发布为什么没有进入下一步”“取消后怎么收尾”“失败后怎么回滚”，大概率会先落到这里。

### `internal/route/`

负责 `Route` 资源。

这是环境级网络入口定义目录，用来表达某个应用在某个环境下如何被外部访问。

### `internal/runtime/`

这是运行时观察域，负责把 Kubernetes 里的实际运行状态组织成 DevFlow 可查询、可回写、可操作的 runtime model。

当前子目录包括：

- `internal/runtime/bootstrap/`
- `internal/runtime/config/`
- `internal/runtime/domain/`
- `internal/runtime/observer/`
- `internal/runtime/reconcile/`
- `internal/runtime/repository/`
- `internal/runtime/service/`
- `internal/runtime/transport/`
- `internal/runtime/watch/`
- `internal/runtime/writeback/`

可以这样理解：

- `bootstrap/`：运行时初始化与挂载
- `config/`：runtime-service 配置
- `domain/`：运行时领域模型
- `observer/`：从 Kubernetes 观察 workload、pod、rollout
- `reconcile/`：把观测结果整理为内部状态
- `repository/`：内存索引等存储实现
- `service/`：runtime 读写用例编排
- `transport/`：对外暴露 runtime API
- `watch/`：事件源、队列、缓存、watcher
- `writeback/`：把运行时结果回写到 release 等上游链路

### `internal/service/`

负责 `Service` 资源。

这里的 `Service` 指的是网络资源语义上的 service，而不是泛指“服务层”。
它通常和 `route/` 一起构成 network 边界中的核心资源。

### `internal/shared/`

这是小而稳定的共享能力区，不是一个大杂烩目录。

当前子目录包括：

- `internal/shared/downstreamhttp/`
- `internal/shared/errs/`

可以这样理解：

- `downstreamhttp/`：下游 HTTP 调用公共能力
- `errs/`：统一错误表达或错误辅助

这层应该保持克制，不能重新膨胀成 `common/`、`util/`、`base/` 之类的 catch-all 目录。

### `internal/workloadconfig/`

负责 `WorkloadConfig` 资源。

这是应用级运行基线目录，通常承载：

- 副本数
- 资源 requests / limits
- 探针
- 容器运行基线

发布时，`Manifest` 会冻结这里的内容，作为构建和部署输入的一部分。

---

## `scripts/`

`scripts/` 放仓库辅助脚本。

它通常用于：

- 一键验证
- 辅助检查
- 开发流程自动化

当前还能看到 `scripts/.tmp/`，它属于脚本执行过程中的临时工作区，不是主要源码目录。

---

## `test/`

`test/` 放跨目录、偏集成或端到端的验证内容。

当前子目录包括：

- `test/e2e/`
- `test/integration/`
- `test/workloadconfig/`

可以这样理解：

- `e2e/`：端到端验证
- `integration/`：集成测试
- `workloadconfig/`：针对特定资源或能力的专项验证

如果某个测试已经不适合放在单个包内的 `_test.go` 文件里，而是需要更高层级的组合验证，通常会落到这里。

---

## 结合目录看五个可运行服务

如果按“一个服务主要会看哪些目录”来理解，会更直观：

- `meta-service`
  - `cmd/meta-service/`
  - `internal/project/`
  - `internal/application/`
  - `internal/environment/`
  - `internal/cluster/`
  - `internal/applicationenv/`

- `config-service`
  - `cmd/config-service/`
  - `internal/workloadconfig/`
  - `internal/appconfig/`
  - `internal/configservice/`

- `network-service`
  - `cmd/network-service/`
  - `internal/service/`
  - `internal/route/`
  - `internal/networkservice/`

- `release-service`
  - `cmd/release-service/`
  - `internal/manifest/`
  - `internal/intent/`
  - `internal/release/`

- `runtime-service`
  - `cmd/runtime-service/`
  - `internal/runtime/`

---

## 最后记住 4 条判断规则

当你不确定某个改动应该放哪里时，可以先用这 4 条判断：

1. 可运行入口放 `cmd/`
2. 业务资源实现放 `internal/<domain>/`
3. 通用基础设施放 `internal/platform/`
4. 对外契约和说明文档分别放 `api/` 与 `docs/`

如果某段代码开始像“所有目录都能放”，那通常说明抽象已经开始跑偏了。
