---
title: "Application"
---

# 🧩 Application 模型

> 定义来源：`devflow-common/model/application.go`

## 字段列表

| 字段 | 类型 | 必须 | 说明 |
|------|------|----|------|
| id | ObjectID | 系统 | BaseModel.ID（系统生成） |
| created_at | time | 系统 | BaseModel.CreatedAt（系统生成） |
| updated_at | time | 系统 | BaseModel.UpdatedAt（系统生成） |
| deleted_at | *time | 系统 | BaseModel.DeletedAt |
| name | string | 是  | 应用名称 |
| project_name | string | 是  | 项目/命名空间名称 |
| repo_url | string | 是  | Git 仓库地址 |
| active_manifest_name | string | 是  | 当前激活的 Manifest 名称 |
| active_manifest_id | *ObjectID | 是  | 当前激活的 Manifest ID |
| replica | *int32 | 是  | 副本数 |
| type | ReleaseType | 是  | 发布类型（normal/canary/blue-green） |
| config_maps | []*ConfigMap | 否  | 挂载的 ConfigMap 列表 |
| service | Service | 否  | Service 配置 |
| internet | Internet | 是  | 网络暴露类型（internal/external） |
| envs | map[string][]EnvVar | 否  | 环境变量（分组） |
| status | string | 是  | 当前状态（Running/Failed/Degraded） |

## 关联类型

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

