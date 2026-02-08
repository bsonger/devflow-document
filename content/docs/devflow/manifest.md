---
title: "Manifest"
---

# 🧩 Manifest 模型

> 定义来源：`devflow-common/model/manifest.go`

## 字段列表

| 字段 | 类型 | 必须 | 说明 |
|------|------|------|------|
| id | ObjectID | 系统 | BaseModel.ID（系统生成） |
| created_at | time | 系统 | BaseModel.CreatedAt（系统生成） |
| updated_at | time | 系统 | BaseModel.UpdatedAt（系统生成） |
| deleted_at | *time | 否 | BaseModel.DeletedAt |
| application_id | ObjectID | 是 | 关联 Application ID |
| name | string | 是 | Manifest 名称 |
| application_name | string | 是 | 应用名称 |
| branch | string | 是 | Git 分支 |
| git_repo | string | 是 | Git 仓库地址 |
| commit_hash | string | 否 | Git Commit Hash |
| replica | *int32 | 是 | 副本数 |
| digest | string | 否 | 镜像 digest |
| type | ReleaseType | 是 | 发布类型（normal/canary/blue-green） |
| config_maps | []*ConfigMap | 否 | 挂载的 ConfigMap 列表 |
| service | Service | 是 | Service 配置 |
| internet | Internet | 是 | 网络暴露类型（internal/external） |
| envs | map[string][]EnvVar | 否 | 环境变量（分组） |
| pipeline_id | string | 是 | Tekton PipelineRun ID |
| steps | []ManifestStep | 是 | 每个步骤状态 |
| status | ManifestStatus | 是 | Manifest 状态 |

## 关联类型

### ManifestStatus

- Pending
- Running
- Succeeded
- Failed

### ManifestStep

| 字段 | 类型 | 必须 | 说明 |
|------|------|------|------|
| task_name | string | 是 | Task 名称 |
| task_run | string | 否 | TaskRun 名称 |
| status | StepStatus | 是 | Step 状态 |
| start_time | *time.Time | 否 | 开始时间 |
| end_time | *time.Time | 否 | 结束时间 |
| message | string | 否 | 失败/提示信息 |

### StepStatus

- Pending
- Running
- Succeeded
- Failed

### ReleaseType

- normal
- canary
- blue-green

### Internet

- internal
- external

### Service

| 字段 | 类型 | 必须 | 说明 |
|------|------|------|------|
| ports | []Port | 是 | 服务端口列表 |

### Port

| 字段 | 类型 | 必须 | 说明 |
|------|------|------|------|
| name | string | 是 | 端口名称 |
| port | int | 是 | Service 端口 |
| target_port | int | 是 | 目标容器端口 |

### ConfigMap

| 字段 | 类型 | 必须 | 说明 |
|------|------|------|------|
| name | string | 是 | ConfigMap 名称 |
| mount_path | string | 是 | 挂载路径 |
| files_path | map[string]string | 是 | 文件路径映射 |

### EnvVar

| 字段 | 类型 | 必须 | 说明 |
|------|------|------|------|
| name | string | 是 | 环境变量名 |
| value | string | 是 | 环境变量值 |

