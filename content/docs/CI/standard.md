# 企业云原生平台标准 CI 流程

## 1. 目标

本标准 CI 流程旨在实现：

- 自动化构建、测试、发布流程  
- 镜像和构建产物安全可追溯  
- 与云原生平台安全策略和 Observability 集成  
- 支持多项目、多环境的复用  
- 确保企业级安全规范落地

---

## 2. 流程概览

代码提交 → 代码扫描 → 单元/集成测试 → 构建镜像 → SBOM 生成 → 镜像签名 → 漏洞扫描 → Artifact 发布 → 通知 & 指标

---

## 3. 流程阶段与功能

| 阶段 | 功能描述 | 实现工具 / Tekton Task | 核心规范 |
| ---- | -------- | -------------------- | -------- |
| 源码管理 | 拉取代码，支持分支/commit/tag | Tekton `git-clone` Task | 可追溯，每次构建对应唯一 commit |
| 代码扫描 | 静态分析、SAST | SonarQube / CodeQL | 阻止不合规代码提交 |
| 单元/集成测试 | 执行测试并生成报告 | Tekton Test Task | 生成可追踪测试报告 |
| 构建镜像 | 构建容器镜像 | Buildah / Kaniko | 不允许手工 push，镜像不可变 |
| SBOM 生成 | 软件组成清单生成 | Syft / Grype | 用于安全审计与漏洞扫描 |
| 镜像签名 | Cosign 签名 | Tekton Cosign Task | 支持 keyless/OIDC，保证镜像可信 |
| 漏洞扫描 | 镜像安全扫描 | Trivy / Clair | 阻止高危漏洞镜像上线 |
| Artifact 发布 | Push 镜像 / Helm / Chart | Harbor / OCI Registry | 支持 digest 部署，保证不可篡改 |
| 通知 & 指标 | 告警及指标收集 | Slack / DingTalk / Prometheus / Grafana | Pipeline 状态、构建指标上报 |

---

## 4. 参数化设计

- 支持可配置参数：
  - `git-url`, `git-revision`, `image-name`, `image-tag`, `Dockerfile`, `manifest-name`
- 可复用 Pipeline 支持多项目、多分支构建
- 支持 Workspace 共享：
  - 源码、Docker 配置、SSH Key、Secrets

---

## 5. 串联顺序设计

推荐 Pipeline 流程顺序：

`clone → test → build → sbom → sign → scan → push → notify`

- 使用 Tekton `runAfter` 或 DAG 定义依赖关系  
- 每个阶段可独立复用 Task，保证灵活性

---

## 6. 安全策略

- 镜像签名 (Cosign)  
- 镜像来源限制 (白名单 Registry)  
- Artifact 可追溯 (Label / Digest)  
- 构建凭证安全 (OIDC / Tekton Secrets)  
- 与 Kyverno / OPA Gatekeeper 联动

---

## 7. 可观测性设计

- **日志**：Pipeline Step 日志统一收集  
- **指标**：构建时长、失败次数、漏洞数量、测试覆盖率  
- **追踪**：可集成 OpenTelemetry，将 Trace 与 CI/CD 流程关联

---

## 8. 标准 CI 流程示意图

代码提交 → 代码扫描 → 单元/集成测试 → 构建镜像 → SBOM 生成 → 镜像签名 → 漏洞扫描 → Artifact 发布 → 通知 & 指标

---

## 9. 核心思想

1. **可复用**：Pipeline 参数化 + Task 复用  
2. **安全可信**：签名 + SBOM + 漏洞扫描  
3. **可追溯**：Git commit + Image Label + Artifact digest  
4. **自动化**：无需人工操作，通知自动触发