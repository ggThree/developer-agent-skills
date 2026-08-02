# 前端代码审查规则

本规则覆盖 Vue、React、TypeScript、uni-app、H5 与常见前端构建链。先按项目选择 [`../adapters/vue.md`](../adapters/vue.md)、[`../adapters/react.md`](../adapters/react.md)、[`../adapters/uniapp.md`](../adapters/uniapp.md) 或 [`../adapters/node.md`](../adapters/node.md)。

## 1. 状态与数据流

- 明确 props、local state、store、route、cache 和服务端数据各自的 source of truth。
- 检查派生状态是否重复存储，watch/effect/computed 的依赖是否完整且稳定。
- 异步请求开始、成功、失败、取消和组件卸载路径都要恢复 loading 与交互状态。
- 防止旧请求覆盖新请求、重复提交、快速切路由后更新已卸载组件。
- 列表 key 必须稳定且与业务实体对应，不使用会随排序变化的 index 作为可编辑列表 key。

## 2. TypeScript 与接口契约

- 比较实际请求参数、后端字段、类型、可空性、枚举、日期格式和分页结构。
- 不使用 `as unknown as`、宽泛 `any` 或非空断言掩盖契约不一致。
- 类型收窄必须有运行时依据；外部数据进入应用边界时需要验证或安全 fallback。
- 新旧接口兼容应明确生效范围与移除条件，不能静默吞掉未知状态。

## 3. Vue 专项

- `ref`、`reactive`、`computed` 与 `watch` 的语义是否正确，解构是否破坏响应性。
- `watch` 的 source、deep、immediate 与清理逻辑是否符合预期。
- `v-if` 与 `v-show` 是否匹配生命周期需求；表单组件的 `v-model` 参数和 emits 是否一致。
- `onMounted`、`onUnmounted`、`onActivated`、`onDeactivated` 对缓存页面行为是否完整。
- Pinia store 是否被跨用户或跨页面意外复用。

## 4. React 专项

- `useEffect`/`useMemo`/`useCallback` 依赖是否准确，是否存在 stale closure 或无意义的 memoization。
- 受控与非受控表单是否切换，state 更新是否基于旧值安全执行。
- Context 或全局 store 的订阅范围是否导致大面积重渲染。
- Suspense、Error Boundary、并发渲染与 Strict Mode 重复调用下是否保持幂等。
- 服务端渲染项目检查 hydration、一致时区和浏览器专属 API 的执行位置。

## 5. uni-app 与多端

- 使用条件编译时，各端分支必须语法闭合且有对应验证。
- 核对页面生命周期、tabBar 返回、页面栈、缓存和小程序分包。
- 权限流程分为授权状态、能力调用与结果解析，不把某一阶段失败误判为另一阶段。
- 支付、登录、分享、定位和订阅消息必须核对平台 AppID、用户标识、环境与服务端上下文。
- 不假设 H5、微信小程序、App 的 DOM、网络、文件路径和权限行为相同。

## 6. UI、可访问性与兼容性

- 小屏、横屏、缩放、键盘、安全区、长文本和国际化文本；
- 键盘操作、焦点顺序、语义标签、颜色对比和 reduced motion；
- 移动端 touch/click 重复触发、300ms 行为、滚动穿透和 fixed 定位；
- 资源宽高、懒加载和布局偏移；
- 浏览器兼容应以项目 browserslist/运行目标为准。

## 7. 性能与资源

- 避免在 render/template 中执行高复杂度计算或创建不稳定对象；
- 大列表使用分页、虚拟化或增量渲染，并验证滚动状态；
- 请求、Timer、EventListener、Observer 与订阅在卸载时清理；
- 检查 bundle 体积、重复依赖、source map 暴露和生产调试代码；
- 性能结论需要 profile、指标或可复现对比，不以直觉定性。

## 8. 安全

- 防止 XSS、开放重定向、CSRF、原型污染、路径拼接和不可信 HTML 注入；
- token 的存储、刷新、退出清理与多标签页同步符合威胁模型；
- 权限控制必须由服务端最终执行，前端隐藏按钮不是授权；
- 日志、埋点和错误弹窗不输出敏感信息。

## 9. 最小验证

按仓库脚本选择 typecheck、lint、目标测试和 build，随后对变化入口执行手工回归。API 问题还需记录浏览器 Network 的 URL、method、payload、status 与 response；不得只根据 UI 提示猜测服务端原因。

## 10. 高风险信号

认证、支付、权限路由、全局状态持久化、请求拦截器、构建配置、依赖锁文件、多端条件编译和生产环境变量变化，至少按 [`../risk/high.md`](../risk/high.md) 评估。
