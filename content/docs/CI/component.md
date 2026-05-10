---
title: "CI 组件矩阵"
weight: 53
---

# 🧰 CI 用到哪些工具

<span class="df-badge">Pipeline</span> <span class="df-badge">Security</span> <span class="df-badge">{{< brand-icon name="zot" alt="Zot" >}} OCI Registry</span>

DevFlow 的 CI 流水线依赖以下工具，每个负责一个具体环节。

---

## 🧱 核心工具

### Tekton Pipelines — 流水线引擎

CI 的"骨架"。定义流水线的结构：有哪些步骤、按什么顺序执行、步骤之间怎么共享数据。

### Tekton Triggers — 触发器

接收 release-service 的 HTTP 请求，自动创建流水线执行实例。相当于 CI 的"入口门卫"。

### 🏗️ Buildah — 镜像构建

在容器里构建容器镜像，不需要 Docker Daemon。支持多阶段构建，可以做出很小的最终镜像。

---

## 🔐 安全工具

### 📜 Syft — SBOM 生成

分析镜像里装了什么软件、什么版本，生成"软件物料清单"。出了问题可以追溯：「这个漏洞影响我们吗？影响哪些服务？」

### ✍️ Cosign — 镜像签名

给镜像做数字签名，防止镜像被替换或篡改。就像给快递包裹贴防伪标签。

### 🛡️ Trivy — 漏洞扫描

扫描镜像里的已知安全漏洞。发现高危漏洞会直接阻断构建，不让有问题的镜像进入部署环节。

---

## 🧰 工具清单

| 工具 | 用途 | 是否必须 |
|------|------|---------|
| {{< brand-icon name="tekton" alt="Tekton" >}} Tekton Pipelines | 流水线编排 | ✅ |
| {{< brand-icon name="tekton" alt="Tekton" >}} Tekton Triggers | 事件触发 | ✅ |
| Buildah | 镜像构建 | ✅ |
| Syft | SBOM 生成 | ✅ |
| Cosign | 镜像签名 | ✅ |
| Trivy | 漏洞扫描 | ✅ |
| {{< brand-icon name="opentelemetry" alt="OpenTelemetry" >}} OpenTelemetry | 链路追踪 | ✅ |
| {{< brand-icon name="tekton" alt="Tekton Dashboard" >}} Tekton Dashboard | 流水线可视化 | ❌（可选）|

---

## 🏭 流水线示意图

```
{{< brand-icon name="tekton" alt="Tekton" >}} Tekton Trigger 接收请求
        ↓
创建 PipelineRun
        ↓
┌─────────────────────────────────────────────┐
│  拉代码 → 扫描 → 测试 → 构建 → SBOM → 签名 → 再扫  │
└─────────────────────────────────────────────┘
        ↓
推送镜像到 {{< brand-icon name="zot" alt="Zot" >}} OCI Registry（Zot）
        ↓
回调 release-service
```
