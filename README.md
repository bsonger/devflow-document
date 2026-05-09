# DevFlow 文档站点

DevFlow 官方文档站点，使用 [Hugo](https://gohugo.io/) + [hugo-book](https://github.com/alex-shpak/hugo-book) 主题构建。

## 文档内容

本文档站介绍 [devflow-service](https://github.com/bsonger/devflow-service) 云原生应用交付平台，涵盖：

- **平台概览** — DevFlow 定位、核心能力、技术栈
- **架构设计** — 五大微服务、领域模型、发布生命周期
- **服务详解** — meta-service、config-service、network-service、release-service、runtime-service
- **核心概念** — Project、Application、Manifest、Release 等领域概念
- **持续集成** — Tekton Pipeline CI 流程
- **持续交付** — Argo CD + Argo Rollouts 发布策略
- **可观测性** — OpenTelemetry + Prometheus + Grafana
- **部署指南** — Kubernetes 部署步骤

## 本地开发

### 前置要求

- [Hugo Extended](https://gohugo.io/installation/) v0.120+

### 启动开发服务器

```bash
hugo server -D
```

访问 http://localhost:1313 预览文档。

### 构建

```bash
hugo --minify
```

构建产物输出到 `public/` 目录。

## 文档结构

```
content/docs/
├── _index.md              # 文档首页
├── overview/              # 平台概览
├── architecture/          # 架构设计
│   ├── services.md        # 五大微服务
│   ├── domain-model.md    # 领域模型
│   └── lifecycle.md       # 发布生命周期
├── services/              # 服务详解
│   ├── meta-service.md
│   ├── config-service.md
│   ├── network-service.md
│   ├── release-service.md
│   └── runtime-service.md
├── concepts/              # 核心概念
│   ├── project-application.md
│   ├── environment-cluster.md
│   ├── workload-config.md
│   ├── app-config.md
│   ├── service-route.md
│   └── manifest-release.md
├── ci/                    # 持续集成
├── cd/                    # 持续交付
├── observability/         # 可观测性
└── deployment/            # 部署指南
```

## 技术栈

- **构建工具**: Hugo v0.154+
- **主题**: hugo-book
- **语言**: 中文
- **图表**: Mermaid
