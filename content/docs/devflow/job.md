---
title: "Job"
---

# 🧩 Job 模型

> 定义来源：`devflow-common/model/job.go`

## 字段列表

| 字段 | 类型 | 必须 | 说明 |
|------|------|----|------|
| id | ObjectID | 系统 | BaseModel.ID（系统生成） |
| created_at | time | 系统 | BaseModel.CreatedAt（系统生成） |
| updated_at | time | 系统 | BaseModel.UpdatedAt（系统生成） |
| deleted_at | *time | 系统 | BaseModel.DeletedAt |
| application_id | ObjectID | 是  | 关联 Application ID |
| application_name | string | 是  | 关联 Application 名称 |
| project_name | string | 是  | 项目/命名空间名称 |
| manifest_id | ObjectID | 是  | 关联 Manifest ID |
| manifest_name | string | 是  | 关联 Manifest 名称 |
| type | string | 是  | Job 类型（Install/Upgrade/Rollback） |
| env | string | 是  | 运行环境标识（如 prod/staging） |
| status | JobStatus | 是  | 任务状态 |

## JobStatus 枚举

- Pending
- Running
- Succeeded
- Failed
- RollingBack
- RolledBack
- Syncing
- SyncFailed

