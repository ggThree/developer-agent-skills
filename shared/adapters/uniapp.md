# uni-app 项目 Adapter

## 这是哪种项目

本 Adapter 面向使用 uni-app 构建的微信/支付宝等小程序、H5 和 App 多端项目，覆盖 Vue 2/Vue 3 语法、条件编译、页面生命周期、平台 API 与原生插件集成。

## 如何识别

- 存在 `pages.json`、`manifest.json`、`uni.scss` 或 `App.vue`；
- `package.json` 包含 `@dcloudio/*` 依赖，或项目采用 HBuilderX 结构；
- 代码使用 `uni.*` API、`#ifdef`/`#ifndef` 条件编译和小程序组件配置；
- 存在 `wxcomponents`、`nativeplugins`、分包或平台特定目录；
- 构建脚本包含 `mp-weixin`、`h5`、`app-plus` 等 target。

不要把普通 Vue 项目误判为 uni-app；至少需要平台配置或 `uni.*` 运行证据。

## 应该检查什么

### 页面与多端生命周期

- `onLoad`、`onShow`、`onHide`、`onUnload` 与 Vue lifecycle 的调用次数和数据刷新边界。
- 页面栈、tabBar、navigateTo/redirectTo/reLaunch、返回缓存和分包路径。
- 条件编译块在每个目标端语法闭合，公共逻辑不会只存在于某一分支。
- nvue、WebView、原生插件与普通 Vue 页面能力差异。

### 平台能力

- 登录流程区分平台 code、服务端换取身份、业务会话与过期刷新。
- 支付核对 AppID、openid/用户标识、merchant、订单、prepay 与 callback 是否属于同一环境。
- 定位分为授权、坐标获取和逆地理编码，分别保留错误证据。
- 相机、相册、剪贴板、订阅消息、分享和文件权限处理拒绝与设置跳转。
- 平台 API 的 success/fail/complete 回调、Promise 封装和版本兼容。

### UI 与状态

- rpx/px、安全区、状态栏、键盘、横竖屏、长列表与下拉刷新。
- 表单 focus、v-model、校验、loading、重复点击与失败恢复。
- 页面 onShow 重入是否重复请求，旧请求是否覆盖当前页面或账号数据。
- H5、Mini Program 与 App 的 storage、cookie、网络和文件路径差异。

### 构建与发布

- `manifest.json`、`pages.json`、平台 AppID、权限和环境配置不混用。
- npm/HBuilderX 构建方式、依赖 lockfile、分包大小与静态资源路径。
- 小程序隐私声明、合法域名、request/upload/download/socket 配置。
- 原生插件、证书与云服务配置属于高风险外部状态。

Vue 逻辑同时参考 [`vue.md`](vue.md)，通用检查见 [`../rules/frontend-review.md`](../rules/frontend-review.md)。

## 应该忽略什么

- 不把微信小程序行为推断为支付宝、H5 或 App 的通用行为。
- 不修改平台 AppID、证书、包名、签名、合法域名或生产环境变量，除非明确授权。
- 不因某端无法使用 DOM 就重写公共 Vue 结构；先确认目标平台。
- 不审查 `unpackage` 等构建产物，除非仓库明确版本化或问题发生在产物生成。
- 不默认升级 HBuilderX、DCloud 依赖、原生插件或小程序基础库。
- 不把用户取消授权当作代码错误，也不能吞掉真实权限失败。

## 高风险是什么

- 支付、登录或订阅消息混用不同 AppID、用户标识、商户或环境；
- 在客户端信任支付成功而未核对服务端订单终态；
- 条件编译使安全校验、错误处理或请求签名只在部分端存在；
- 修改签名、证书、原生插件、隐私权限和生产合法域名；
- storage/cache 跨账号残留，导致展示或提交其他用户数据；
- 发布前只验证一个端却宣称多端兼容。

这些问题通常按 [`../risk/high.md`](../risk/high.md) 处理，资金或大范围隐私后果可升级为 [`../risk/critical.md`](../risk/critical.md)。

## 最小验证

1. 明确本次目标端、AppID 和环境，不执行无关端构建。
2. 使用仓库规定方式构建目标端，并检查编译后的条件分支。
3. 在对应开发者工具或设备验证正常、拒绝、超时、返回页面和重复操作。
4. 通过 Network、平台控制台与服务端日志核对请求和最终业务状态。
5. 涉及原生能力时保留真机验证清单和未覆盖边界。
