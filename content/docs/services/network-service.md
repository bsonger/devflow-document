---
title: "network-service"
weight: 33
---

# network-service

**网络工程师** — 管理应用的网络拓扑和外部访问入口。

## 它是做什么的

network-service 管理两层网络定义：

### Service — 应用级网络拓扑

定义应用**暴露哪些端口**、用什么协议：

```yaml
name: order-service
ports:
  - port: 80
    target_port: 8080
    protocol: HTTP
  - port: 9090
    target_port: 9090
    protocol: GRPC
```

这告诉 Kubernetes："order-service 有两个端口，一个是 HTTP，一个是 GRPC"。

### Route — 环境级入口规则

定义**外部流量怎么进来**：

```yaml
host: "order.example.com"
path: "/api/v1"
service_name: "order-service"
service_port: 80
tls:
  enabled: true
```

这告诉 Istio："凡是访问 order.example.com/api/v1 的请求，都转发到 order-service 的 80 端口"。

## 一个例子

**order-service 的应用级网络拓扑（Service）：**

```yaml
name: order-service
ports:
  - port: 80
    target_port: 8080
    protocol: HTTP
```

**order-service 在生产环境的入口（Route）：**

```yaml
host: "order.example.com"
path: "/"
service_name: "order-service"
service_port: 80
tls:
  enabled: true
  secret_name: "order-tls"
```

**order-service 在测试环境的入口（Route）：**

```yaml
host: "order-test.example.com"
path: "/"
service_name: "order-service"
service_port: 80
tls:
  enabled: false
```

同一个应用，测试环境用测试域名且不用 HTTPS，生产环境用正式域名且启用 HTTPS。

## 为什么分层

和配置管理的思路一样：
- **Service** 是应用的固有属性（我暴露了哪些端口），不随环境变化
- **Route** 是环境相关的（这个环境用什么域名、什么证书），随环境变化

分开管理，职责清晰，不会搞混。

## 与 CI/CD 的关系

在 Canary 和 Blue-Green 发布中，network-service 定义的网络规则是流量控制的基础：

- Canary 通过 Istio VirtualService 按权重切流量
- Blue-Green 通过 Service Selector 瞬时切换

这些流量控制规则，都基于 network-service 定义的 Service 和 Route 来生成。

## API 入口

```
GET/POST/PUT/DELETE  /api/v1/network/services
GET/POST/PUT/DELETE  /api/v1/network/routes
```
