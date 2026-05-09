---
title: "部署步骤"
weight: 81
---

# 部署步骤

把 DevFlow 部署到自己的 Kubernetes 集群，总共需要 12 步。

---

## 前置条件

在开始之前，你需要有一个 Kubernetes 集群（v1.30+），至少 3 个 Worker 节点。

---

## 第 1 步：部署 Istio

Istio 是流量治理的基础设施，Canary 和 Blue-Green 发布都依赖它。

```bash
istioctl install --set profile=default
```

然后创建一个入口网关，让外部流量能进入 DevFlow：

```yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: devflow-gateway
  namespace: devflow
spec:
  selector:
    istio: ingressgateway
  servers:
    - port:
        number: 80
        name: http
        protocol: HTTP
      hosts:
        - "devflow.bei.com"
```

---

## 第 2 步：部署 Argo CD

Argo CD 负责 GitOps 部署。DevFlow 把部署包推送到仓库后，Argo CD 负责实际同步到集群。

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.2.2/manifests/install.yaml
```

配置 OCI Registry 访问权限，让 Argo CD 能拉取部署包：

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: zot-repo
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
stringData:
  type: oci
  url: registry.example.com
  username: argocd
  password: <password>
```

---

## 第 3 步：部署 Argo Rollouts

Argo Rollouts 扩展了 Kubernetes 的发布能力，支持 Canary 和 Blue-Green。

```bash
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/download/v1.8.0/install.yaml
```

> 如果你只用 Rolling 发布，这步可以跳过。

---

## 第 4 步：部署 PostgreSQL

DevFlow 的 4 个服务（meta、config、network、release）需要 PostgreSQL 存储数据。

```bash
helm install postgresql bitnami/postgresql \
  --namespace devflow \
  --set auth.username=devflow \
  --set auth.password=<password> \
  --set auth.database=devflow \
  --set primary.persistence.size=50Gi
```

---

## 第 5 步：创建 DevFlow 配置

创建一个共享的 ConfigMap，所有 DevFlow 服务都能读到：

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: devflow-config
  namespace: devflow
data:
  database.host: "postgresql.devflow.svc.cluster.local"
  database.port: "5432"
  database.name: "devflow"
  otel.endpoint: "devflow-otel-trace-gateway:4317"
  registry.url: "registry.example.com"
```

---

## 第 6 步：部署 DevFlow 服务

### meta-service

meta-service 是其他服务的依赖，先部署它：

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: meta-service
  namespace: devflow
spec:
  replicas: 2
  selector:
    matchLabels:
      app: meta-service
  template:
    metadata:
      labels:
        app: meta-service
    spec:
      containers:
        - name: meta-service
          image: registry.example.com/devflow/meta-service:latest
          ports:
            - containerPort: 8081
          envFrom:
            - configMapRef:
                name: devflow-config
          env:
            - name: DATABASE_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: postgresql
                  key: password
```

### config-service 和 network-service

按相同模式部署，它们也连 PostgreSQL，读同一个 ConfigMap。

### release-service

release-service 需要额外的配置，告诉它下游服务在哪、Tekton 怎么触发：

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: release-service-config
  namespace: devflow
data:
  meta_service.url: "http://meta-service:8081"
  config_service.url: "http://config-service"
  network_service.url: "http://network-service"
  tekton.event_listener: "http://el-devflow-build.tekton-pipelines.svc.cluster.local"
  argocd.server: "argocd-server.argocd.svc.cluster.local"
```

### runtime-service

runtime-service **不需要数据库**，但需要 K8s 集群的访问权限：

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: runtime-service
  namespace: devflow
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: runtime-service
rules:
  - apiGroups: [""]
    resources: ["pods", "pods/log"]
    verbs: ["get", "list", "watch", "delete"]
  - apiGroups: ["apps"]
    resources: ["deployments", "statefulsets", "daemonsets"]
    verbs: ["get", "list", "watch", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: runtime-service
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: runtime-service
subjects:
  - kind: ServiceAccount
    name: runtime-service
    namespace: devflow
```

> 为什么需要 ClusterRole？因为 runtime-service 要监听整个集群的 Pod 和 Workload 状态，不能只盯着自己的命名空间。

---

## 第 7 步：配置 Ingress

让外部请求能路由到正确的服务：

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: devflow-api
  namespace: devflow
spec:
  hosts:
    - "devflow.bei.com"
  gateways:
    - devflow-gateway
  http:
    - match:
        - uri:
            prefix: /api/v1/meta
      route:
        - destination:
            host: meta-service
            port:
              number: 8081
    - match:
        - uri:
            prefix: /api/v1/release
      route:
        - destination:
            host: release-service
            port:
              number: 8083
```

> config-service 和 network-service 的入口可以按需暴露，Console 通常只直接调用 meta、release、runtime。

---

## 第 8 步：验证部署

```bash
# 看 Pod 是不是都 Running
kubectl get pods -n devflow

# 检查服务健康
 curl https://devflow.bei.com/api/v1/meta/health
 curl https://devflow.bei.com/api/v1/release/health
 curl https://devflow.bei.com/api/v1/runtime/health

# 检查数据库 migration 是否完成
kubectl logs -n devflow deployment/meta-service | grep "migration completed"
```

---

## 第 9 步：部署 Tekton

Tekton 是 CI 引擎，负责构建镜像。

```bash
kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml
kubectl apply -f https://storage.googleapis.com/tekton-releases/triggers/latest/release.yaml
```

配置 EventListener 接收 release-service 的构建触发：

```yaml
apiVersion: triggers.tekton.dev/v1beta1
kind: EventListener
metadata:
  name: devflow-build
  namespace: tekton-pipelines
spec:
  serviceAccountName: tekton-trigger
  triggers:
    - name: devflow-build-trigger
      bindings:
        - ref: devflow-build-binding
      template:
        ref: devflow-build-template
```

---

## 第 10 步：配置监控（可选）

```bash
# Prometheus
helm install prometheus prometheus-community/prometheus \
  --namespace observability

# Grafana
helm install grafana grafana/grafana \
  --namespace observability
```

---

## 第 11 步：验证端到端流程

用 curl 走一遍完整的发布流程：

```bash
# 1. 创建项目
curl -X POST https://devflow.bei.com/api/v1/meta/projects \
  -d '{"name":"demo"}'

# 2. 注册应用
curl -X POST https://devflow.bei.com/api/v1/meta/applications \
  -d '{"name":"hello","repo_url":"github.com/example/hello","type":"Rolling"}'

# 3. 创建环境
curl -X POST https://devflow.bei.com/api/v1/meta/environments \
  -d '{"name":"test","cluster_id":"cluster-001","namespace":"test"}'

# 4. 发起发布
curl -X POST https://devflow.bei.com/api/v1/release/releases \
  -d '{"manifest_id":"m-001","environment_id":"env-001","strategy":"Rolling"}'

# 5. 查看状态
curl https://devflow.bei.com/api/v1/release/releases/rel-001
```

如果 Release 状态从 Pending → Running → Completed，说明部署成功。
