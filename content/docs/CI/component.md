
---
title: "Components"
---

#持续集成（CI）

| 组件               | 云原生领域 | 解决的问题                     | 架构定位    | 是否必选 | 可替代方案                            |
|------------------|-------|---------------------------|---------|------|----------------------------------|
| Tekton Pipelines | CI    | 声明式、K8s 原生 CI 执行          | CI 执行引擎 | ❌    | GitLab CI、Jenkins、GitHub Actions |
| Tekton Triggers  | CI    | Git / Webhook 触发 Pipeline | CI 事件入口 | ❌    | GitLab Webhook、Argo Events       |
| Tekton Dashboard | CI    | CI 可视化                    | CI UI   | ❌    | Jenkins UI、GitLab UI             |
| Buildah          | 镜像构建  | 无需 Docker Daemon 构建镜像     | 构建工具    | ❌    | Docker、Kaniko                    |
