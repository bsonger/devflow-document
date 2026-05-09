---
title: "公共 Attributes"
weight: 72
---

# 公共 Attributes

DevFlow 的所有服务使用统一的标签（Attributes），这样 Metrics、Logs、Traces 才能互相关联。

---

## 为什么要统一

假设 meta-service 的一个请求出错了：

- Metrics 里记录了这个接口的延迟
- Logs 里记录了错误详情
- Traces 里记录了整个调用链路

如果三个系统用的标签名字不一样，你就没法把它们串起来。统一标签后，通过 `trace_id` 就能从 Metrics 跳到 Trace，再跳到 Log。

---

## 常用标签

### 服务身份

| 标签 | 例子 | 说明 |
|------|------|------|
| service.name | meta-service | 哪个服务 |
| service.version | 1.0.0 | 什么版本 |
| deployment.environment | production | 什么环境 |

### K8s 位置

| 标签 | 例子 | 说明 |
|------|------|------|
| k8s.cluster.name | prod-beijing | 哪个集群 |
| k8s.namespace.name | devflow | 哪个命名空间 |
| k8s.pod.name | meta-service-abc12 | 哪个 Pod |

### 请求信息

| 标签 | 例子 | 说明 |
|------|------|------|
| http.method | GET | HTTP 方法 |
| http.route | /api/v1/meta/projects | 请求路径 |
| http.status_code | 200 | 响应状态码 |

---

## 命名规则

- 全部 **小写**
- 层级用 **点号** 分隔：`service.name`、`k8s.pod.name`
- 不要用驼峰：`serviceName` ❌

---

## 来源

这些标签通过环境变量注入到服务中：

```yaml
env:
  - name: OTEL_SERVICE_NAME
    value: "meta-service"
  - name: OTEL_RESOURCE_ATTRIBUTES
    value: "service.version=1.0.0,deployment.environment=production"
```
