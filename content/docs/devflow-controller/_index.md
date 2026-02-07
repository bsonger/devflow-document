---
title: "devflow-controller"
weight: 5
# bookFlatSection: false
# bookToc: true
# bookHidden: false
# bookCollapseSection: false
# bookComments: false
# bookSearchExclude: false
bookCollapseSection: true
---

# 🧭 Devflow Controller 概览

Devflow Controller 是平台的 **发布控制中枢**，负责监听 CD 执行状态并回写统一的发布进度与结果。

## 🎯 核心职责

- 监听 Argo CD / Argo Rollouts 状态  
- 归一化发布阶段与结果  
- 将 steps 与 job status 回写 Mongo  

## 🔄 关键链路

Devflow Console → Devflow Job → Argo CD Application / Rollout → Devflow Controller → Mongo

## 🧭 快速导航

- Canary 回写流程：`canary.md`  
