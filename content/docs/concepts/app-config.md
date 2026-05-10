---
title: "AppConfig"
weight: 44
---

# 🌱 AppConfig

**AppConfig** 是环境级配置记录，解决“同一套应用在不同环境挂载不同配置内容”的问题。

## 它回答什么问题

> order-service 在测试环境连哪个数据库？在生产环境连哪个数据库？

---

## 为什么需要它

想象一下，你没有 AppConfig，所有环境的配置都写在同一份文件里：

```yaml
# 测试环境配置
database: postgres-test.internal
log_level: debug

# 生产环境配置
database: postgres-prod.internal
log_level: warn
```

某天你改测试环境的数据库地址，不小心把生产环境的也改了。发布时没发现，结果生产环境连到了测试数据库，用户数据全丢了。

AppConfig 就是来解决这个问题的：
- 每个环境独立管理自己的配置
- 发布时自动叠加到基线配置上
- 测试环境的改动永远不会影响生产环境

---

## 当前实现里包含什么

当前 `devflow-service` 里的 `AppConfig` 主要记录：

- `application_id`
- `environment_id`
- `mount_path`
- `latest_revision_no`
- `latest_revision_id`
- `files`
- `source_directory`
- `source_commit`

它的配置内容不是通过页面上随手写一段 `config_data` 保存，而是通过**固定配置仓库同步**进入当前记录。

---

## 实际例子

同一个应用，不同环境：

**测试环境的 AppConfig 记录：**

```yaml
application_id: order-service
environment_id: test
mount_path: /etc/config
source_directory: ecommerce/order-service/test
files:
  - name: application.yaml
  - name: feature-flags.yaml
```

**生产环境的 AppConfig 记录：**

```yaml
application_id: order-service
environment_id: prod
mount_path: /etc/config
source_directory: ecommerce/order-service/prod
files:
  - name: application.yaml
  - name: feature-flags.yaml
```

发布时，DevFlow 读取这些同步过的文件，再和 WorkloadConfig 一起进入 release render。

---

## 当前实现里的心智模型

```
WorkloadConfig = 应用级运行基线
AppConfig = 环境级配置文件来源
Release render = 把两者翻译成最终部署内容
```

也就是说：

- `AppConfig` 不是最终 ConfigMap
- `AppConfig` 也不是自由结构的键值数据库
- `AppConfig` 更像“当前环境配置文件挂载与同步状态的资源记录”

---

## 和 WorkloadConfig 的区别

| | WorkloadConfig | AppConfig |
|--|---------------|-----------|
| 属于 | Application | ApplicationEnvironment |
| 用途 | 运行时基线 | 环境级配置来源记录 |
| 随环境变化 | 否 | 是 |
| 例子 | 副本数、资源规格 | mount_path、同步文件、source_directory |

---

## 安全

当前实现里，配置来源受固定配置仓库和同步流程约束。用户主要维护的是挂载位置和环境归属，而不是直接在 API 中提交一整套自由格式 secrets/config_data。
