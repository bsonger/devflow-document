---
title: "部署步骤"
weight: 81
---

# 部署步骤

把 DevFlow 部署到自己的 Kubernetes 集群，总共需要 11 步。

> 如果你只是想**体验** DevFlow，建议先用 Docker Compose 或 Kind 搭一个最小环境，不用一上来就生产级部署。

---

## 先看这页怎么用

这页有两种读法：

1. **体验路径**：先看“部署前检查表”，再直接跳到每一步里的安装命令，最后执行“验证端到端流程”
2. **生产路径**：按顺序完成全部 12 步，并保留可观测性、权限和仓库配置

如果你只想验证 **Rolling** 发布，可以跳过 Argo Rollouts；如果你要验证 **Canary**，还必须安装 Istio。

---

## 部署前检查表

在动手之前，至少确认下面这些输入已经准备好：

| 检查项 | 为什么需要 |
|------|-----------|
| Kubernetes 集群（1.30+） | DevFlow 的运行底座 |
| 至少 3 个 Worker 节点 | 给平台服务、数据库和周边组件留资源 |
| 一个 OCI Registry | 同时存镜像和部署包 |
| 一个对外访问域名 | 暴露 DevFlow Console / API |
| 一个 PostgreSQL 实例或安装方案 | meta/config/network/release 四个服务要落库 |
| 一个可访问的 Git 仓库示例应用 | 用来验证端到端发布 |

还要想清楚几个决策：

- 我的集群有几个 Worker 节点？DevFlow itself 需要跑 5 个服务 + PostgreSQL + Tekton + Istio，资源不够会很痛苦。
- 我需要 Canary 和 Blue-Green 吗？如果只需要 Rolling，可以跳过 Argo Rollouts 和 Istio 的部分步骤。
- 我的镜像仓库准备好了吗？DevFlow 需要同时存镜像和部署包（OCI artifact）。

想清楚这些问题，部署过程会顺畅很多。

---

## 前置条件

在开始之前，你需要有一个 Kubernetes 集群（v1.30+），至少 3 个 Worker 节点。

---

## 第 1 步：部署 Istio

Istio 是流量治理的基础设施，Canary 和 Blue-Green 发布都依赖它。

> 💡 **为什么先装 Istio？**
> 
> 想象一下，你的应用是一栋公寓楼，Istio 就是楼里的智能电梯系统。没有它，每个住户（Pod）只能走楼梯串门，又慢又乱。有了 Istio，流量想去哪一层、坐哪部电梯，全部智能调度。Canary 发布就是靠这个电梯系统实现的：先让 10% 的住户坐新电梯试试，没问题再全员换。

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

> 💡 **GitOps 是什么？**
> 
> 传统部署是"人告诉机器怎么做"，GitOps 是"人描述期望状态，机器自己同步"。就像你点外卖：你不用管骑手怎么骑车、怎么等红绿灯，你只需要确认"我要吃宫保鸡丁"，外卖平台会搞定一切。Argo CD 就是那个外卖平台，DevFlow 是点单的人。

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.2.2/manifests/install.yaml
```

配置 {{< brand-icon name="zot" alt="Zot" >}} OCI Registry 访问权限，让 Argo CD 能拉取部署包：

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

> 💡 **可以跳过这步吗？**
> 
> 可以！如果你只需要最简单的 Rolling 发布（一个一个换 Pod），原生 Kubernetes 就够了。但如果你要做 Canary（灰度）或 Blue-Green（蓝绿），就必须装 Argo Rollouts。它就像汽车的自动挡——手动档也能开，但自动挡省心多了。

```bash
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/download/v1.8.0/install.yaml
```

> 如果你只用 Rolling 发布，这步可以跳过。

---

## 第 4 步：部署 PostgreSQL

DevFlow 的 4 个服务（meta、config、network、release）需要 PostgreSQL 存储数据。

> 💡 **为什么选 PostgreSQL？**
> 
> 因为 DevFlow 的数据关系比较复杂：Project 包含 Application，Application 绑定 Environment，Environment 关联 Cluster……这些关系用文档数据库（MongoDB）也能存，但查询起来很别扭。PostgreSQL 的关系模型正好适合这种场景。

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

创建一个共享的 ConfigMap，所有 DevFlow 服务都能读到。

> 💡 **为什么要共享配置？**
> 
> 想象 5 个室友合租一套房，如果每个人记一个不同的 WiFi 密码，迟早有人连不上网。共享 ConfigMap 就像把 WiFi 密码贴在冰箱上——所有人看同一个地方，不会搞混。

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

5 个服务有依赖顺序，就像搭积木：必须先搭地基，再搭柱子，最后搭屋顶。

### meta-service（地基）

meta-service 是其他服务的依赖，先部署它：

> 为什么必须先装 meta-service？因为它管着"户口本信息"——其他服务启动时都要问它："我在哪个项目？应用叫什么名字？"如果 meta-service 没起来，其他服务会像找不到家的孩子一样 panic。

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

### config-service 和 network-service（柱子）

按相同模式部署，它们也连 PostgreSQL，读同一个 ConfigMap。

> config-service 管"每个环境用什么配置"，network-service 管"外部流量怎么进来"。它们是 release-service 的左膀右臂——发布时需要知道配置是什么、网络规则是什么，才能渲染出正确的部署包。

### release-service（总指挥）

release-service 需要额外的配置，告诉它下游服务在哪、Tekton 怎么触发：

> release-service 是整个 DevFlow 的"大脑"。它知道所有服务的地址、知道怎么触发构建、知道怎么通知 Argo CD 部署。如果 meta-service 是户口本，release-service 就是街道办事处——它负责把所有事情串起来。

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

### runtime-service（千里眼）

runtime-service **不需要数据库**，但需要 K8s 集群的访问权限：

> runtime-service 是 DevFlow 的"眼睛"。它不存数据，只是盯着 Kubernetes 看——Pod 起来了没？Workload 健康吗？有新事件吗？Console 上看到的发布进度条，全靠它实时汇报。

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

让外部请求能路由到正确的服务。

> 💡 **Ingress 是做什么的？**
> 
> 想象 DevFlow 是一座写字楼，每个服务是一个办公室。Ingress 就是大堂的接待员——它知道 `/api/v1/meta` 要去 meta-service 办公室，`/api/v1/release` 要去 release-service 办公室。没有接待员，访客（外部请求）会迷路。

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

这时候你应该紧张又期待——就像烤箱里的蛋糕快出炉了，想确认是不是烤好了。

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

> 💡 **Tekton 和 DevFlow 的关系**
> 
> Tekton 是工厂里的流水线工人，DevFlow 是工厂经理。经理下订单（"构建 order-service v2.0"），工人执行具体操作（拉代码、跑测试、打镜像）。经理不需要知道工人怎么拧螺丝，只需要确认订单完成了。

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

监控就像汽车的仪表盘——速度、油量、发动机温度，一眼就能看到。没有仪表盘，你只能在车抛锚后才知道有问题。

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

恭喜！如果你走到这一步，DevFlow 已经跑起来了。现在用 curl 走一遍完整的发布流程，就像新车提车后第一次上路——确认油门、刹车、方向盘都正常。

```bash
export DEVFLOW_BASE_URL="https://devflow.bei.com"
export DEVFLOW_TOKEN="<your-token>"

# 1. 创建项目
curl -X POST "$DEVFLOW_BASE_URL/api/v1/meta/projects" \
  -H "Authorization: Bearer $DEVFLOW_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"demo"}'

# 2. 注册应用
curl -X POST "$DEVFLOW_BASE_URL/api/v1/meta/applications" \
  -H "Authorization: Bearer $DEVFLOW_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"project_id":"proj-001","name":"hello","repo_address":"github.com/example/hello"}'

# 3. 创建环境
curl -X POST "$DEVFLOW_BASE_URL/api/v1/meta/environments" \
  -H "Authorization: Bearer $DEVFLOW_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"test","cluster_id":"cluster-001"}'

# 4. 创建应用和环境绑定
curl -X POST "$DEVFLOW_BASE_URL/api/v1/meta/applications/app-001/environments" \
  -H "Authorization: Bearer $DEVFLOW_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"environment_id":"env-001"}'

# 5. 创建 Manifest
curl -X POST "$DEVFLOW_BASE_URL/api/v1/release/manifests" \
  -H "Authorization: Bearer $DEVFLOW_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"application_id":"app-001","git_revision":"main"}'

# 6. 创建 Release
curl -X POST "$DEVFLOW_BASE_URL/api/v1/release/releases" \
  -H "Authorization: Bearer $DEVFLOW_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"manifest_id":"m-001","environment_id":"env-001","strategy":"rolling"}'

# 7. 查看状态
curl "$DEVFLOW_BASE_URL/api/v1/release/releases/rel-001" \
  -H "Authorization: Bearer $DEVFLOW_TOKEN"
```

如果 Release 状态从 Pending → Running → Completed，说明部署成功。🎉

> 第一次发布失败了？别慌，检查这几个地方：
> - Tekton 的 PipelineRun 是不是成功了？（`kubectl get pipelinerun -n tekton-pipelines`）
> - Argo CD 的 Application 是不是同步了？（Argo CD UI 里看）
> - runtime-service 有没有权限问题？（看 Pod 日志）
