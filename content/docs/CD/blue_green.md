# 云原生 Blue/Green 发布实战：Argo CD + Argo Rollouts

Blue/Green 发布是一种低风险的发布策略，通过维护两套环境（Blue 和 Green），在新版本发布时切换流量到新环境，实现平滑切换和快速回滚。

---

## 1. 技术栈说明

| 组件 | 作用 | 说明 |
|------|------|------|
| **Argo CD** | GitOps CD 平台 | 自动同步 Kubernetes 资源与 Git 仓库，实现声明式部署 |
| **Argo Rollouts** | 发布控制器 | 提供 Blue/Green、Canary 等高级发布策略，并支持指标分析与自动回滚 |
| **Service / Ingress** | 流量控制 | Kubernetes Service 或 Ingress 实现流量切换 |
| **Prometheus / Metrics** | 指标监控 | 可用于自动判断新版本健康并触发切换 |

---

## 2. 基本原理

1. **Blue/Green 环境**：
   - **Blue**：当前生产环境版本
   - **Green**：新版本环境，准备上线
2. **流量切换**：
   - Service 指向 Blue 环境
   - Rollout 创建 Green Pod 后，通过 Service 将流量切换到 Green
3. **回滚**：
   - 如果 Green 出现问题，Service 可以快速切回 Blue
4. **Argo CD**：
   - GitOps 同步 Blue/Green Rollout 的 Manifest，实现自动化部署和版本管理

---

## 3. Rollout 配置示例

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: my-app
  namespace: production
spec:
  replicas: 5
  strategy:
    blueGreen:
      activeService: my-app-active
      previewService: my-app-preview
      autoPromotionEnabled: false # 手动切换流量
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
      - name: my-app
        image: registry.example.com/my-app:v2