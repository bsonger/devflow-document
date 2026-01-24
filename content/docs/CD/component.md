
---
title: "Components"
---


## 一、持续交付（CD & 发布）

| 组件                  | 云原生领域       | 解决的问题         | 架构定位              | 是否必选 | 可替代方案             |
|---------------------|-------------|---------------|-------------------|------|-------------------|
| Argo CD             | CD / GitOps | Git 驱动的声明式部署  | CD 控制平面           | ✅    | FluxCD            |
| Argo ApplicationSet | CD          | 多环境 / 多集群应用生成 | CD 扩展能力           | ❌    | Helmfile、自研脚本     |
| Argo Rollouts       | 发布策略        | 灰度 / 蓝绿发布     | 高级 Deployment 控制器 | ❌    | Flagger、Spinnaker |

---

## 二、流量治理与服务网格

| 组件                       | 云原生领域        | 解决的问题         | 架构定位    | 是否必选 | 可替代方案                 |
|--------------------------|--------------|---------------|---------|------|-----------------------|
| Istio                    | Service Mesh | 流量治理、mTLS、可观测 | 服务网格控制面 | ❌    | Linkerd、Consul Mesh   |
| Istio Ingress Gateway    | 流量入口         | 统一流量入口        | 南北向网关   | ❌    | Nginx Ingress、Traefik |
| VirtualService / Gateway | 流量控制         | 路由、权重、故障注入    | 流量规则层   | ❌    | Nginx 配置              |

---