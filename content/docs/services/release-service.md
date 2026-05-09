---
title: "release-service"
weight: 34
---

# release-service

**发布经理** — 发布全流程的编排者。从你在 Console 上点"发布"按钮，到应用真正跑在 Kubernetes 上，全是 release-service 在操心。

---

## 它是做什么的

release-service 管理四样东西：

### Manifest — 构建前快照

发布开始时，release-service 先把当前应用的完整状态"拍一张照片"保存下来：

- 代码版本（git revision + commit hash）
- 构建出来的镜像
- 基础配置（WorkloadConfig）
- 网络拓扑（Service）

这张照片一旦拍下就**不能再改**。它记录了"这个应用在构建时刻长什么样"。

### Release — 部署前快照

构建成功后，release-service 再拍第二张照片：

- 关联的 Manifest（哪次构建）
- 目标环境（发到哪）
- 环境配置（AppConfig）
- 网络规则（Route）
- 发布策略（Rolling / Canary / Blue-Green）

这张照片也**不能再改**。它记录了"这次发布的完整上下文"。

### Intent — 发布意图

记录"谁、为什么、什么时候"发起的发布：

```
发布人: 张三
原因: 修复支付回调超时问题
时间: 2026-01-15 14:30
```

用于审计和追溯。

### Image — 镜像信息

记录构建产物的元数据：

- 镜像 digest（唯一标识）
- SBOM（软件成分清单）
- 签名信息

---

## 一次发布的完整旅程

你在 Console 上点了"发布 order-service 到生产环境"，接下来 release-service 会：

### 第一步：收集信息

release-service 先去找其他服务打听情况：

> "meta-service，order-service 的代码仓库在哪？生产环境在哪个集群？"  
> "config-service，order-service 的基础配置是什么？生产环境的特殊配置是什么？"  
> "network-service，order-service 暴露了哪些端口？生产环境的域名是什么？"

### 第二步：冻结 Manifest

把收集到的信息打包成第一份快照（Manifest）。

这时候镜像还没构建，Manifest 里只记录了代码版本和配置。等构建完成后，再把镜像地址补进去。

### 第三步：触发构建

release-service 通知 Tekton："去构建 order-service 的 a1b2c3d4 版本"。

Tekton 开始跑流水线：拉代码 → 跑测试 → 扫漏洞 → 构建镜像 → 推送到镜像仓库。

### 第四步：冻结 Release

构建成功后，release-service 创建第二份快照（Release）：

```
关联的 Manifest: m-001（order-service @ a1b2c3d4）
目标环境: production
环境配置: DB_HOST=prod-db, LOG_LEVEL=warn...
发布策略: Canary
```

### 第五步：渲染部署包

release-service 把所有配置叠加在一起，生成最终的 Kubernetes 配置：

```
WorkloadConfig（3 副本、1Gi 内存）
+ AppConfig（生产数据库地址）
+ Service（暴露 80 端口）
+ Route（order.example.com）
= 完整的 K8s manifest
```

不同的发布策略会生成不同的资源：

| 策略 | 生成的资源 |
|------|-----------|
| Rolling | Deployment + Service |
| Canary | Rollout + VirtualService + DestinationRule |
| Blue-Green | Rollout + Active Service + Preview Service |

### 第六步：推送并部署

把渲染好的包推送到 OCI Registry，然后通知 Argo CD："去部署这个包到生产集群"。

### 第七步：等反馈

runtime-service 盯着 Kubernetes，实时把发布进度回写给 release-service：

> "新版本 3/10 个 Pod 已经 Ready"  
> "Canary 10% 流量切换完成"

你在 Console 上看到的进度条，数据来源就是这里。

---

## 三种发布策略

release-service 支持三种发布策略，在 Release 创建时确定：

### Rolling — 滚动更新

最简单的方式：一个一个替换旧版本 Pod。

适合：内部工具、低优先级服务、资源敏感的场景。

### Canary — 灰度发布

先给 10% 用户用新版本，观察 5 分钟。没问题就扩大到 30%、50%、100%。

适合：核心 API、用户-facing 的服务、需要风险控制。

每个灰度阶段都会自动检查指标（错误率、延迟），不达标就自动回滚。

### Blue-Green — 蓝绿部署

先部署一套完整的新版本（Green），在 Preview 环境里验证。没问题就一键切换流量，瞬时完成。

适合：金融核心、必须零停机的业务、数据库 schema 变更。

---

## 为什么这样设计

### 快照 = 可追溯

传统发布最大的痛点是"不知道当时到底发了什么"。配置可能被中途改过，镜像 tag 可能记不清。

DevFlow 的解决方案是：**发布前先冻结两份不可变快照**。出了问题，你总能精确知道当时的状态。

### 异步 = 不卡主流程

构建可能要 10 分钟，部署可能要 5 分钟。release-service 不会傻等，而是：

1. 触发构建后立刻返回 Release ID
2. 构建完成后自动继续下一步
3. 每个阶段的状态都写到 Release 记录里

你可以随时查询进度，不用守着屏幕等。

### 状态机 = 可预期

Release 有明确的状态流转：

```
Pending → Rendering → Publishing → Deploying → Running → Completed
                                                      ↘ Failed
```

每个状态都有明确的含义，不会模棱两可。
