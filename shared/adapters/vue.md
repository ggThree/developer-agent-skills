# Vue 项目 Adapter

## 这是哪种项目

本 Adapter 面向 Vue 3/Vue 2 Web 应用、组件库和基于 Vue 的管理后台。常见组合包括 TypeScript、Vite/Webpack、Vue Router、Pinia/Vuex、Element Plus、Vant 与服务端渲染框架。

## 如何识别

- `package.json` 依赖包含 `vue`，并能从 lockfile 确定真实版本；
- 存在 `.vue` Single-File Component；
- 存在 `vite.config.*`、`vue.config.*`、`nuxt.config.*` 或 Vue 编译插件；
- 入口使用 `createApp`、Vue Router、Pinia/Vuex；
- CI 或 scripts 包含 Vue typecheck、test 或 build 命令。

不要只根据目录名判断 Vue 版本；应查看 `package.json`、lockfile 和实际 API。

## 应该检查什么

### 响应式状态

- `ref`、`reactive`、`computed` 的所有权和解包位置，解构是否丢失响应性。
- `watch`/`watchEffect` 的 source、依赖、deep、immediate、flush 与 cleanup。
- props 单向数据流、emits 声明和 `v-model` 参数是否匹配。
- Pinia/Vuex store 是否跨用户、路由或 SSR request 泄漏状态。
- keep-alive 下 `onActivated`/`onDeactivated` 与普通 mount/unmount 的差异。

### 组件与模板

- `v-if`/`v-show` 是否符合销毁或保留状态需求。
- `v-for` key 稳定，条件渲染、slot 与 Teleport 的生命周期正确。
- 表单校验、禁用、loading、重复提交与失败恢复完整。
- 模板中不执行昂贵计算、不直接注入不可信 HTML。
- 组件库 API 以已锁定版本为准，不按最新文档猜测。

### 路由、缓存与异步

- Router guard 的返回、重定向、权限与循环导航。
- route params/query 的类型、缺失值、编码与返回页面缓存。
- 请求取消、竞态、错误 fallback 与卸载后的状态写入。
- SSR 项目检查 hydration、浏览器专属 API 与每请求状态隔离。

### TypeScript 与构建

- props、emits、template refs、API DTO 和 store 类型一致。
- `tsconfig`、alias、环境变量前缀和生产构建模式。
- `package.json` 与实际 lockfile 同步，Node 和包管理器版本遵循仓库配置。

通用前端规则见 [`../rules/frontend-review.md`](../rules/frontend-review.md)。

## 应该忽略什么

- 不审查 `dist`、coverage、缓存或自动生成类型，除非仓库明确提交它们或生成逻辑变化。
- 不把 Options API 自动视为需要迁移，也不要求把稳定组件改写为 Composition API。
- 不无依据替换 Pinia/Vuex、Router、UI 组件库或构建器。
- 不因个人偏好调整 template/style 排序或全仓库格式化。
- 不把 H5 DOM 结论直接套用到 uni-app 小程序；多端项目另加载 [`uniapp.md`](uniapp.md)。
- 不把 TypeScript 类型通过等同于后端响应在运行时可靠。

## 高风险是什么

- 路由/按钮只在前端做权限判断，服务端未授权；
- 登录 token、用户 store 或 SSR state 跨账号泄漏；
- 请求拦截器、refresh token、支付或全局错误处理变化；
- lockfile、构建环境变量、public path 或生产 proxy 意外变化；
- `v-html` 等路径注入不可信内容；
- keep-alive/异步竞态导致旧用户数据或旧页面状态覆盖新状态。

这些变化通常按 [`../risk/high.md`](../risk/high.md) 评估。

## 最小验证

1. 从 `package.json` 和 lockfile 选择唯一包管理器。
2. 执行已有 typecheck、lint、目标测试和 production build。
3. 回归正常、空数据、失败、超时、重复点击、路由返回与权限失效。
4. 使用 Network 核对真实 request/response；SSR 项目同时验证首屏与 hydration。
5. 对受支持浏览器和移动端尺寸执行最小兼容检查。
