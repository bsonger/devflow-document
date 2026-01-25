
---
title: "Components"
---

# 持续集成（CI）组件能力矩阵

## 一、CI 核心编排与触发

| 组件 | 云原生领域 | 解决的问题 | 架构定位 | 是否必选 | 可替代方案 |
|------|------------|------------|----------|----------|------------|
| Tekton Pipelines | CI | 声明式、K8s 原生 CI 编排 | CI 执行与编排引擎 | ✅ | Jenkins、GitHub Actions |
| Tekton Triggers | CI | Git / Webhook 触发 Pipeline | CI 事件入口 | ❌ | Argo Events |
| Tekton Dashboard | CI | Pipeline 执行可视化 | CI UI | ❌ | Jenkins UI、GitLab UI |

---

## 二、源码获取与代码质量

| 组件 | 云原生领域 | 解决的问题 | 架构定位 | 是否必选 | 可替代方案 |
|------|------------|------------|----------|----------|------------|
| Git Clone Task | SCM | 拉取源码、获取 Commit 信息 | Source Stage | ✅ | 内置 Git Script |
| 代码扫描（SAST / Secret） | Security | 代码漏洞、密钥泄漏、危险配置 | Shift-Left Security | ❌ | SonarQube、Semgrep、Gitleaks |
| 代码规范 / Lint | Quality | 代码风格、规范检查 | Quality Gate | ❌ | golangci-lint、eslint |

---

## 三、测试阶段

| 组件 | 云原生领域 | 解决的问题 | 架构定位 | 是否必选 | 可替代方案 |
|------|------------|------------|----------|----------|------------|
| 单元测试 | Testing | 功能正确性验证 | Quality Gate | ❌ | Go test、JUnit |
| 集成测试 | Testing | 多组件联调验证 | Pre-Build Validation | ❌ | Testcontainers |
| 覆盖率统计 | Quality | 测试质量度量 | Quality Metrics | ❌ | Cobertura |

---

## 四、镜像构建与制品管理

| 组件 | 云原生领域 | 解决的问题 | 架构定位 | 是否必选 | 可替代方案 |
|------|------------|------------|----------|----------|------------|
| Buildah | Image Build | 无 Docker Daemon 构建镜像 | 构建引擎 | ✅ | Kaniko、Docker |
| Artifact Registry | Artifact | 镜像 / 构建产物存储 | 制品仓库 | ✅ | Harbor、ECR |
| 镜像 Tag / Digest 管理 | Artifact | 可追溯发布版本 | Artifact Metadata | ✅ | — |

---

## 五、软件供应链安全（Supply Chain Security）

| 组件 | 云原生领域 | 解决的问题 | 架构定位 | 是否必选 | 可替代方案 |
|------|------------|------------|----------|----------|------------|
| SBOM 生成（Syft） | Security | 组件清单、依赖可追溯 | Supply Chain | ❌ | CycloneDX |
| 镜像签名（Cosign） | Security | 镜像可信验证 | Trust & Provenance | ❌ | Notary v2 |
| 漏洞扫描（Trivy） | Security | 镜像漏洞检测 | Runtime / Deploy Gate | ❌ | Grype、Clair |

---

## 六、CI → CD 状态桥接

| 组件 | 云原生领域 | 解决的问题 | 架构定位 | 是否必选 | 可替代方案 |
|------|------------|------------|----------|----------|------------|
| Manifest Patch Task | Platform | 绑定 Commit / Image Digest | CI → CD 状态同步 | ✅ | GitOps Commit |
| Pipeline Result 传递 | CI | 跨 Task 数据共享 | Data Flow | ✅ | — |

---

## 七、通知与可观测性

| 组件 | 云原生领域 | 解决的问题 | 架构定位 | 是否必选 | 可替代方案 |
|------|------------|------------|----------|----------|------------|
| Notify Task | Feedback | CI 结果通知 | Feedback Channel | ❌ | Webhook、Slack |
| CI Metrics（OTel） | Observability | 构建时长、成功率 | CI 可观测性 | ❌ | Prometheus |
| CI Trace（Pipeline / Task） | Observability | 执行链路分析 | Debug / RCA | ❌ | Jaeger |