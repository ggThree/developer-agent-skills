# React 项目 Adapter

## 这是哪种项目

本 Adapter 面向 React Web 应用、组件库、React Native 共享逻辑与基于 React 的 SSR/SSG 应用。常见组合包括 TypeScript、Vite/Webpack、Next.js、React Router、Redux/Zustand 和 React Query。

## 如何识别

- `package.json` 依赖包含 `react` 与 `react-dom`，或 React Native 运行时；
- 源文件包含 JSX/TSX；
- 存在 `vite.config.*`、`next.config.*`、Webpack 配置或 React 插件；
- 入口使用 `createRoot`、hydrate、Next.js route 或 React Native AppRegistry；
- 测试使用 React Testing Library、Jest/Vitest 或端到端框架。

通过 lockfile 确认真正 React 版本和相关 Router/框架版本，不能从语法推测版本。

## 应该检查什么

### 状态与渲染

- state、props、context、server state 和 URL state 的 source of truth。
- state 更新是否安全使用旧值，派生值是否被重复存储。
- 列表 key 是否稳定；conditional render 是否保留或重置正确状态。
- Context/store selector 的订阅范围和不必要重渲染。
- Error Boundary、Suspense 与 loading/empty/error/success 状态完整。

### Hooks 与并发

- `useEffect` 依赖、cleanup、竞态和 stale closure。
- `useMemo`/`useCallback` 是否有正确依赖和真实收益，而非掩盖状态问题。
- Strict Mode 重复执行、并发渲染和 transition 下副作用是否幂等。
- 请求取消、旧响应覆盖、组件卸载后更新与重复提交。
- custom hook 是否保持调用顺序并清楚表达所有权。

### 路由与 SSR

- route params/query、权限 guard、返回状态和 404/error route。
- Next.js/SSR 中 Server/Client Component 边界、序列化 props、cache 与每请求隔离。
- hydration 时区、随机数、浏览器 API 和初始数据是否一致。
- server action/API route 仍需独立执行认证、授权和输入验证。

### TypeScript、表单与 API

- Component props、event、ref、API DTO 和 discriminated union 类型。
- 受控/非受控表单不能意外切换；校验、提交与错误映射保持一致。
- 外部 JSON 有运行时校验或安全收窄，不能仅依赖 compile-time 类型。
- API cache key、invalidate、optimistic update 与 rollback 语义正确。

通用规则见 [`../rules/frontend-review.md`](../rules/frontend-review.md)。

## 应该忽略什么

- 不把所有 inline function 或未使用 memo 自动判为性能缺陷；先提供 profile 或渲染证据。
- 不因偏好在 Context、Redux、Zustand、React Query 之间迁移。
- 不要求把 class component 全量改写成 function component。
- 不审查 build、coverage、生成 route/type 文件，除非其来源或提交策略发生变化。
- 不把 development Strict Mode 的重复日志直接当作 production 重复请求，需追踪副作用路径。
- React Native 平台行为不按浏览器 DOM 推断；涉及原生 target 时加载对应平台规则。

## 高风险是什么

- auth/permission 只依赖客户端路由或按钮可见性；
- SSR cache、singleton store 或错误复用导致跨用户数据泄漏；
- refresh token、全局请求拦截器、支付、optimistic write 回滚变化；
- effect 竞态导致旧数据覆盖、重复写入或无限请求；
- hydration 差异使关键表单或购买流程不可用；
- 构建配置、环境变量、lockfile 或 source map 暴露生产信息。

按影响使用 [`../risk/high.md`](../risk/high.md) 或 [`../risk/critical.md`](../risk/critical.md)。

## 最小验证

- 根据 `package.json` 执行现有 typecheck、lint、目标测试和生产构建。
- 用 React Testing Library 验证用户行为，不只断言内部 state。
- 回归正常、失败、重复提交、快速切换、卸载与权限失效。
- SSR/SSG 检查服务端输出、hydration 与客户端导航三条路径。
- 性能问题用 Profiler 或项目指标验证 before/after。
