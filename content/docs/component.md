
---
title: "All Components"
date: 2026-01-04
categories:
  - Cloud Native
  - DevOps
tags:
  - Kubernetes
  - DevOps
  - Observability
---

## 🧭 快速定位

- 平台工程与控制面：DevFlow Controller / DevFlow  
- CI：Tekton 体系  
- CD：Argo CD / Rollouts  
- 观测：Prometheus / Loki / Tempo / Grafana  

## ✅ 最小落地组合（MVP）

- CI：Tekton Pipelines + Buildah  
- CD：Argo CD  
- 观测：Prometheus + Grafana  
- 网络：Cilium（或 Calico）  

## 🏗️ 一、平台与应用层（Platform / Application）

| 组件                 | 云原生领域      | 解决的问题                                           | 架构定位                           | 是否必选    | 可替代方案                         |
|--------------------|------------|-------------------------------------------------|--------------------------------|---------|-------------------------------|
| DevFlow Controller | 平台工程 / 控制面 | 监听并汇总 Tekton CI 与 Argo CD CD 的执行状态，统一编排发布流程与状态机 | 平台控制面（Orchestrator / Operator） | ❌（平台自研） | Spinnaker、Harness、自研 Operator |
| DevFlow            | 应用管理       | 应用 / 发布 / 流程状态管理                                | 平台 API 层                       | ❌       | GitLab API、Backstage Backend  |
| DevFlow Console    | 开发者体验      | 提供统一 Web UI                                     | 平台入口                           | ❌       | Backstage、GitLab UI           |
| Document Service   | 知识管理       | 平台文档与规范沉淀                                       | 辅助服务                           | ❌       | Confluence、Wiki               |

---

## 🧪 二、持续集成（CI）

| 组件               | 云原生领域 | 解决的问题                     | 架构定位    | 是否必选 | 可替代方案                            |
|------------------|-------|---------------------------|---------|------|----------------------------------|
| Tekton Pipelines | CI    | 声明式、K8s 原生 CI 执行          | CI 执行引擎 | ❌    | GitLab CI、Jenkins、GitHub Actions |
| Tekton Triggers  | CI    | Git / Webhook 触发 Pipeline | CI 事件入口 | ❌    | GitLab Webhook、Argo Events       |
| Tekton Dashboard | CI    | CI 可视化                    | CI UI   | ❌    | Jenkins UI、GitLab UI             |
| Buildah          | 镜像构建  | 无需 Docker Daemon 构建镜像     | 构建工具    | ❌    | Docker、Kaniko                    |

---

## 🚀 三、持续交付（CD & 发布）

| 组件                  | 云原生领域       | 解决的问题         | 架构定位              | 是否必选 | 可替代方案             |
|---------------------|-------------|---------------|-------------------|------|-------------------|
| Argo CD             | CD / GitOps | Git 驱动的声明式部署  | CD 控制平面           | ✅    | FluxCD            |
| Argo ApplicationSet | CD          | 多环境 / 多集群应用生成 | CD 扩展能力           | ❌    | Helmfile、自研脚本     |
| Argo Rollouts       | 发布策略        | 灰度 / 蓝绿发布     | 高级 Deployment 控制器 | ❌    | Flagger、Spinnaker |

---

## 🕸️ 四、流量治理与服务网格

| 组件                       | 云原生领域        | 解决的问题         | 架构定位    | 是否必选 | 可替代方案                 |
|--------------------------|--------------|---------------|---------|------|-----------------------|
| Istio                    | Service Mesh | 流量治理、mTLS、可观测 | 服务网格控制面 | ❌    | Linkerd、Consul Mesh   |
| Istio Ingress Gateway    | 流量入口         | 统一流量入口        | 南北向网关   | ❌    | Nginx Ingress、Traefik |
| VirtualService / Gateway | 流量控制         | 路由、权重、故障注入    | 流量规则层   | ❌    | Nginx 配置              |

---

## 🌐 五、网络（CNI）

| 组件     | 云原生领域 | 解决的问题        | 架构定位   | 是否必选 | 可替代方案          |
|--------|-------|--------------|--------|------|----------------|
| Cilium | 容器网络  | 高性能网络 + 安全策略 | CNI 插件 | ❌    | Calico、Flannel |
| Hubble | 网络可观测 | 可视化网络流量      | 网络观测层  | ❌    | Istio Kiali    |

---

## 👀 六、可观测性（Observability）

### Metrics

| 组件                  | 领域          | 解决的问题             | 定位    | 是否必选 | 替代方案            |
|---------------------|-------------|-------------------|-------|------|-----------------|
| Prometheus          | Metrics     | 指标采集与查询           | 指标引擎  | ✅    | VictoriaMetrics |
| Prometheus Operator | 运维自动化       | Prometheus 生命周期管理 | 控制器   | ❌    | 手动部署            |
| kube-state-metrics  | K8s Metrics | Kubernetes 状态指标   | 指标源   | ✅    | 无               |
| node-exporter       | 主机监控        | Node 资源指标         | 指标采集器 | ✅    | 无               |

### Logs

| 组件            | 领域   | 解决的问题      | 定位       | 是否必选 | 替代方案              |
|---------------|------|------------|----------|------|-------------------|
| Loki          | Logs | 低成本日志存储与查询 | 日志系统     | ❌    | ELK、OpenSearch    |
| Alloy / Agent | Logs | 日志采集       | 采集 Agent | ❌    | Fluent Bit、Vector |

### Tracing

| 组件            | 领域        | 解决的问题  | 定位       | 是否必选 | 替代方案            |
|---------------|-----------|--------|----------|------|-----------------|
| Tempo         | Tracing   | 分布式追踪  | Trace 存储 | ❌    | Jaeger          |
| OpenTelemetry | Telemetry | 统一采集标准 | 采集规范     | ✅    | OpenTracing（过时） |

### Visualization

| 组件      | 领域  | 解决的问题                      | 定位     | 是否必选 | 替代方案   |
|---------|-----|----------------------------|--------|------|--------|
| Grafana | 可视化 | Metrics / Logs / Traces 展示 | 统一观测入口 | ✅    | Kibana |

---

## 🔐 七、身份认证与安全

| 组件           | 云原生领域 | 解决的问题              | 架构定位  | 是否必选 | 可替代方案                 |
|--------------|-------|--------------------|-------|------|-----------------------|
| Dex          | 认证    | OIDC / OAuth2 身份统一 | 认证中心  | ❌    | Keycloak              |
| OAuth2 Proxy | 访问控制  | Web 服务统一鉴权         | 访问代理  | ❌    | Istio Auth、Nginx Auth |
| cert-manager | 证书管理  | 自动签发 / 续期证书        | 证书控制器 | ✅    | Vault PKI             |

---

## 🗄️ 八、数据与存储

| 组件                     | 云原生领域 | 解决的问题             | 架构定位         | 是否必选 | 可替代方案        |
|------------------------|-------|-------------------|--------------|------|--------------|
| MongoDB                | 数据存储  | 平台元数据存储           | 数据库          | ❌    | PostgreSQL   |
| MinIO                  | 对象存储  | 构建产物 / 日志 / Trace | S3 存储        | ❌    | Ceph、云厂商 OSS |
| local-path-provisioner | 存储    | 本地 PV 管理          | StorageClass | ❌    | Longhorn     |

---

## ✅ 九、核心总结

- **Kubernetes** 负责资源调度  
- **Tekton** 负责 CI  
- **Argo CD / Rollouts** 负责 CD 与发布  
- **Istio + Cilium** 负责网络与流量  
- **Prometheus / Loki / Tempo** 负责可观测  
- **DevFlow** 负责把一切「工程化、平台化」

> 这不是组件堆叠，而是一套 **有清晰分层和职责边界的云原生工程体系**
