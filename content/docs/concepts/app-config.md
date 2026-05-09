---
title: "AppConfig"
weight: 44
---

# AppConfig

**AppConfig** 是环境级配置，解决"同一套应用在不同环境跑不同配置"的问题。

## 它回答什么问题

> order-service 在测试环境连哪个数据库？在生产环境连哪个数据库？

## 包含什么

### ConfigData — 键值对

最简单的形式：

```yaml
config_data:
  DB_HOST: "postgres-test.internal"
  LOG_LEVEL: "debug"
  FEATURE_FLAG_NEW_UI: "true"
```

### ConfigMaps — 配置文件

适合需要挂载成文件的场景：

```yaml
config_maps:
  - name: "app-config"
    data:
      database.yml: |
        host: postgres-test.internal
        port: 5432
        pool_size: 10
```

### Secrets — 敏感信息

密码、Token 等敏感数据：

```yaml
secrets:
  - name: "db-credentials"
    data:
      username: "<加密存储>"
      password: "<加密存储>"
```

---

## 实际例子

同一个应用，不同环境：

**测试环境的 AppConfig：**

```yaml
config_data:
  DB_HOST: "postgres-test.internal"
  LOG_LEVEL: "debug"
  CACHE_TTL: "60"
```

**生产环境的 AppConfig：**

```yaml
config_data:
  DB_HOST: "postgres-prod.internal"
  LOG_LEVEL: "warn"
  CACHE_TTL: "300"
```

发布时，DevFlow 自动把 AppConfig 叠加到 WorkloadConfig 上，生成最终的 K8s 配置。

---

## 叠加规则

```
最终环境变量 = WorkloadConfig.envs（基线）
             + AppConfig.config_data（覆盖基线同名 key）
```

如果基线和环境差异有同名 key，**环境差异优先**。

---

## 和 WorkloadConfig 的区别

| | WorkloadConfig | AppConfig |
|--|---------------|-----------|
| 属于 | Application | ApplicationEnvironment |
| 用途 | 运行时基线 | 环境差异 |
| 随环境变化 | 否 | 是 |
| 例子 | 副本数、资源限制 | 数据库地址、日志级别 |

---

## 安全

AppConfig 中的 Secret 遵循：
- 数据库中**加密存储**
- 只有 release-service 在渲染 Bundle 时解密
- 所有访问记录到审计日志
