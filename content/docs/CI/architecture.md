---
title: "CI Architecture"
---

# 🏗️ CI 架构图（Architecture）

下面是 CI 核心链路与平台依赖的整体关系图。

## 🗺️ Mermaid 版

```mermaid
flowchart LR
  Devflow --> Pipeline[Tekton Pipeline]

  subgraph Build[Test & Build]
    SAST[SAST / Secret Scan] --> Unit[Unit / Integration Test]
    Unit --> BuildImg[Build Image]
    BuildImg --> SBOM[Generate SBOM]
    SBOM --> Sign[Cosign Sign]
    Sign --> Scan[Image Scan]
  end

  Pipeline --> Build
  Scan --> Registry[Artifact Registry]
  Registry --> Notify[Notify / Metrics]
  Pipeline --> OTel[Logs / Metrics / Trace]

  Pipeline --> PR[PipelineRun]
  PR --> TR[TaskRun]
  PR -. watch .-> Ctrl[Devflow Controller]
  TR -. watch .-> Ctrl

  OTel --> Grafana[Grafana]
  OTel --> Loki[Loki]
  OTel --> Tempo[Tempo]
```

## ✅ 关键说明

- **触发**：Devflow Console / Job 触发 Pipeline 执行
- **监听**：Devflow Controller 同时监听 PipelineRun 与 TaskRun 状态
- **安全**：SAST / SBOM / 签名 / 扫描构成供应链安全闭环
- **制品**：镜像推送到 Registry，支持 digest 可追溯
- **反馈**：构建结果通过通知 + 观测系统快速反馈
