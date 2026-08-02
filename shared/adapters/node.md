# Node.js 项目 Adapter

## 这是哪种项目

本 Adapter 面向使用 Node.js 运行时的 CLI、API 服务、构建工具和前端工程基础设施。它覆盖 JavaScript/TypeScript、npm/pnpm/Yarn、CommonJS/ESM，以及 Express、Fastify、NestJS 等服务端框架的通用边界。

## 如何识别

- 存在 `package.json`，scripts 或入口由 Node 执行；
- 存在 `package-lock.json`、`pnpm-lock.yaml`、`yarn.lock` 或包管理器声明；
- `engines`、`.nvmrc`、`.node-version`、Volta 或 CI 固定 Node 版本；
- 源码使用 Node built-in modules、CommonJS 或 ESM；
- 服务端框架、中间件、CLI bin 或构建配置以 Node 为运行时。

前端项目也常使用 Node 构建，但运行时风险应由对应 [`vue.md`](vue.md) 或 [`react.md`](react.md) 叠加判断。

## 应该检查什么

### 运行时与模块系统

- Node 版本、`type`、exports/imports、CJS/ESM interop 与文件扩展名。
- 环境变量读取、默认值、启动参数和不同环境的配置覆盖。
- async Promise rejection、EventEmitter error、process signal 与 graceful shutdown。
- Timer、stream、socket、child process 和文件句柄是否释放。
- path、URL、编码、大小写和 macOS/Linux 差异。

### 依赖与供应链

- `package.json` 与唯一 lockfile 同步，包管理器和版本由 `packageManager`/CI 确定。
- lifecycle script、postinstall、binary download 与 native addon 的平台影响。
- 依赖升级范围、transitive change、license、安全公告和回滚方式。
- 不自动重建 lockfile，不混用 npm/pnpm/Yarn。
- 生产 dependencies 与 devDependencies 分类符合部署方式。

### 服务端行为

- middleware 顺序、认证、授权、输入验证、错误处理和响应终止。
- 请求体、上传、并发、队列和内存有上限；防止 event loop 被同步重任务阻塞。
- timeout、retry、幂等、数据库事务和外部副作用。
- 日志 redaction、trace ID、健康检查与进程退出码。
- SQL/NoSQL、模板、shell 和路径输入防注入。

### TypeScript 与测试

- `tsconfig` module/moduleResolution/target 与运行时匹配。
- 类型声明不掩盖外部 JSON；边界需要运行时验证。
- 测试不依赖残留端口、全局时间、固定 sleep 或共享数据库状态。
- build 输出与实际执行入口一致，source map 不泄露生产源码或秘密。

后端项目同时遵循 [`../rules/backend-review.md`](../rules/backend-review.md)，前端工具链遵循 [`../rules/frontend-review.md`](../rules/frontend-review.md)。

## 应该忽略什么

- 不审查 `node_modules`、coverage、cache 和 build 产物，除非仓库明确版本化或生成行为变化。
- 不因存在另一个 lockfile 就自动删除；先确认项目是否为多包管理器迁移或 monorepo 边界。
- 不默认升级 Node、包管理器、依赖或切换 CJS/ESM。
- 不把 lint 风格偏好当作运行缺陷，也不执行无关全仓库格式化。
- 不用 TypeScript 编译成功代替运行时输入、数据库和网络验证。
- 不把开发服务器配置直接视为生产服务器行为。

## 高风险是什么

- lockfile 大幅变化、lifecycle script 或未知来源二进制进入依赖链；
- 认证中间件顺序错误、对象级越权、敏感日志或不安全动态执行；
- child process/shell 拼接不可信输入，上传/请求体/队列没有上限；
- CJS/ESM 或 Node 大版本切换导致生产入口不可加载；
- retry、消息消费或支付回调导致重复副作用；
- 生产环境变量、secret、source map 或 debug endpoint 暴露。

使用 [`../risk/high.md`](../risk/high.md) 与 [`../risk/critical.md`](../risk/critical.md) 定级。

## 最小验证

1. 从仓库配置确定 Node 与包管理器版本，不使用全局默认猜测。
2. 使用 frozen/immutable lockfile 安装策略或既有 CI 环境，避免隐式改写依赖。
3. 执行目标 lint、typecheck、test 与 production build/start smoke test。
4. 服务端验证无权限、非法输入、超时、重复请求、关闭信号和资源上限。
5. macOS 开发通过后，对 Linux 部署目标核对路径大小写、native addon 与容器运行时。
