# 🔄 Devflow Controller 监听 CD 与状态回写流程

Devflow Controller 的核心职责是 **监听 Argo CD Application 与 Argo Rollouts Rollout 的状态变化**，并将发布进度与结果回写到 Mongo（`steps` 与 `job status`），形成闭环可观测的发布流水线。

---

## 🧩 1. 监听对象

1. **Argo CD Application**
   - 用于确认配置是否已下发（同步状态）
   - 用于确认应用健康状态（健康度）
2. **Argo Rollouts Rollout**
   - 用于跟踪灰度阶段、流量权重与暂停/校验
   - 用于判断发布是否成功、失败或回滚

---

## 🧾 2. 回写数据结构（Mongo）

- **steps**：记录每个灰度阶段的执行进度与校验结果
  - 例如：Applied / 10% / Verify / 30% / Verify / 50% / Verify / 100%
- **job status**：记录整个发布任务的全局状态
  - 例如：Running / Succeeded / Failed

---

## 🗺️ 3. 典型监听与回写流程（Canary）

1. **创建发布任务**
   - Devflow Console 触发 Job
   - 生成 Argo CD Application
   - Controller 监听到 Application 已同步 → `steps=Applied`
2. **下发 Rollout**
   - Rollout 资源创建
   - Controller 监听 Rollout 进入发布阶段 → `job status=Running`
3. **按阶段推进**
   - 10% → Verify → 30% → Verify → 50% → Verify → 100%
   - Controller 在每个阶段更新 `steps`：
     - 进入阶段：标记为 Running
     - 验证通过：标记为 Succeeded
     - 验证失败：标记为 Failed，并更新 `job status=Failed`
4. **发布完成**
   - Rollout 进入完成状态
   - Controller 更新 `steps=100%`，并设置 `job status=Succeeded`

---

## 🧭 4. 状态映射建议（简化版）

| 监听对象 | 关键状态 | steps 更新 | job status 更新 |
|---------|----------|-----------|----------------|
| Application | Synced / Healthy | Applied | Running |
| Rollout | Progressing / Paused | 对应阶段 Running | Running |
| Rollout | Analysis 成功 | 对应 Verify Succeeded | Running |
| Rollout | Degraded / Analysis 失败 | 对应 Verify Failed | Failed |
| Rollout | Completed | 100% Succeeded | Succeeded |

---

## 🔁 5. 异常与回滚

- 如果 Rollout 进入 **Degraded** 或 Analysis 失败：
  - Controller 立即回写 `steps=Failed`
  - 更新 `job status=Failed`
  - Rollout 侧可自动回滚（由策略或人工决定）

---

## ✅ 6. 关键点总结

## 📥📤 7. 输入 / 输出（简要）

**输入**：Argo CD Application、Argo Rollouts Rollout、指标与 Analysis 结果  
**输出**：Mongo `steps`、`job status`、发布进度与结果回写  

- Application 保证 **配置已下发**
- Rollout 体现 **发布过程与流量进度**
- Controller 负责 **监听 + 归一化状态 + 回写 Mongo**
- `steps` 精细化记录阶段；`job status` 表示全局结果
