# Spring Boot 项目 Adapter

## 这是哪种项目

本 Adapter 面向 Spring Boot/Spring Framework 的 Java 或 Kotlin 服务，包括 MVC/WebFlux API、定时任务、消息消费者、MyBatis/JPA 数据访问与多模块 Maven/Gradle 工程。

## 如何识别

- `pom.xml` 或 `build.gradle*` 引用 Spring Boot plugin/dependencies；
- 存在 `@SpringBootApplication`、`application.yml/properties`；
- 代码使用 `@RestController`、`@Service`、`@Transactional`、Spring Security 等；
- 项目包含 `mvnw`/`gradlew`、Spring profile、Actuator 或 Boot 打包配置；
- 测试使用 `@SpringBootTest`、slice test、MockMvc 或 WebTestClient。

通过 Maven/Gradle 文件和 lock/BOM 确认实际 Spring Boot、Java/Kotlin 版本，不按当前最新版本推断 API。

## 应该检查什么

### 调用链与契约

- Controller/Route → Service → Repository/Mapper → Database/外部服务完整链路。
- path、method、content type、DTO validation、错误码和响应字段。
- 前端实际 request 与后端参数名、类型、null、枚举、日期、分页一致。
- OpenAPI/文档、DTO 与实际序列化配置一致。

### Security

- SecurityFilterChain、method security、对象归属和多租户隔离。
- CORS、CSRF、session/token、回调签名与重放防护。
- 管理端、Actuator、文件上传下载、批量导出和错误响应暴露。
- 密钥来自安全配置，日志不输出凭证或完整敏感 payload。

### 事务与持久化

- `@Transactional` 是否通过代理调用，传播、隔离和 rollback 规则正确。
- MyBatis 动态 SQL/JPA query 使用参数绑定；排序、表名和字段白名单。
- 唯一约束、幂等键、乐观锁、并发更新和影响行数检查。
- N+1、全表扫描、无界分页、批量大小与连接池占用。
- migration 向前/向后兼容，应用与 Schema 发布顺序清晰。

### 运行时与集成

- profile、配置默认值、feature flag 与生产环境注入。
- timeout、retry、circuit breaker、线程池、连接池与消息 ack。
- cache key/TTL/失效顺序与事务提交关系。
- Actuator readiness/liveness、graceful shutdown、日志 trace ID 和指标。
- 支付、消息、邮件与第三方调用的幂等、补偿和审计。

完整规则见 [`../rules/backend-review.md`](../rules/backend-review.md)。

## 应该忽略什么

- 不审查 `target`、`build`、生成代码或 IDE 文件，除非其提交本身造成问题。
- 不默认把 MVC 改成 WebFlux、JPA 改成 MyBatis，或进行框架迁移。
- 不无依据升级 Spring Boot、JDK、数据库驱动、BOM 或 Gradle/Maven plugin。
- 不因为单元测试使用内存数据库通过，就宣称生产数据库兼容。
- 不把 Controller 隐藏按钮或前端角色判断视为服务端授权。
- 不把所有长方法当作当前缺陷，优先审查行为风险和目标 Diff。

## 高风险是什么

- 数据库 Schema、批量更新/删除、事务边界或生产 profile 变化；
- 认证授权、租户隔离、支付记账、回调签名和幂等变化；
- API 字段类型/语义变化破坏在用客户端；
- 重试与事务组合造成重复写入，消息 ack 造成丢失或重复消费；
- 依赖/JDK 大版本升级、线程池或连接池无边界；
- 日志泄漏 token、密码、身份证件或支付数据。

按 [`../risk/high.md`](../risk/high.md) 评估；不可恢复数据损害或大范围越权按 [`../risk/critical.md`](../risk/critical.md) 处理。

## 最小验证

1. 使用仓库 wrapper 和目标 module 执行 compile/test，不绕过既有 profile。
2. 运行受影响 Controller、Service 与 Repository 测试。
3. 验证正常、非法输入、无权限、重复请求、并发和依赖超时。
4. 使用与生产一致的数据库类型验证 migration 和关键 SQL 执行计划。
5. 与真实调用方核对 Network/日志中的 request、response 和最终数据状态。
