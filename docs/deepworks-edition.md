# DeepWorks 版本说明

本文档说明 `deepworks` 分支及 `-tags deepworks` 构建标签的实际作用、体积构成与构建方式。

## `-tags deepworks` 改变了什么

- **窗口、面板与版本号标识**：`internal/edition` 在 `deepworks` 标签下将发行名称设为 `DeepWorks Bridge`（短名 `DeepWorks`、ID `com.yetone.deepworks-bridge`），并在版本号后附加 `-dw`。`internal/cli/main.go` 把它接进 `--version` 与 `gateway.Version`；`internal/gui` 用它作为主窗口与面板的标题，并在服务页面时替换 `<title>`（默认构建分支不进入这段替换，所以 magpie 版一个字节都不变）。磁盘上的路径、配置目录、环境变量、日志前缀仍然叫 magpie，两个构建共用同一份数据。
- **内置 DeepWorks 插件**：本发行版存在的核心目的，是随二进制内嵌 `internal/plugin/builtin/deepworks`（`@magpie-community/opencode-deepworks-auth`）并在启动时自动写入插件目录，读取本地 DeepWorks 运行时目录与密钥以接入 DeepFoundry 模型。

## 它**不会**做什么

- **不会裁剪任何功能**：不会移除任何内置 Provider、Agent 适配、本地网关、工具路由或桌面 GUI 界面。
- **无法靠 build tag 瘦身**：`magpie` 主体并未按功能模块拆分为独立子包，Go 的 `//go:build` 标签无法凭空剥离彼此耦合的单体代码；若在分支里直接删除业务代码，分支将与上游 `main` 冲突加剧而无法持续合并更新。

## 二进制体积实际来自哪里

- `site/`（约 65 MB）是官网静态站点源码，**从来不会被编译进二进制**。
- `internal/gui/assets/`（约 11 MB）通过 `go:embed` 完整嵌入二进制，DeepWorks 版同样保留。
- 真正缩减产物体积的是 `-trimpath -ldflags "-s -w ..."`（去除符号表、DWARF 调试信息与构建路径），通常可减少 **25%–40%** 体积；`-tags deepworks` 本身几乎不影响体积。

## 构建、安装与切回 `main`

- **对比构建（生成 `dist/magpie-dw` 与 `dist/magpie-full`）**：
  ```bash
  ./scripts/build-deepworks.sh        # 或 make deepworks
  ./scripts/build-deepworks.sh clean  # 删除 dist/ 目录
  ```
- **安装 DeepWorks 版**：可将 `dist/magpie-dw` 复制到 `PATH` 目录，或使用 `go install`：
  ```bash
  /Users/july/.local/go/bin/go install -tags deepworks -trimpath \
    -ldflags "-s -w -X main.version=$(git describe --tags --always --dirty)" .
  ```
- **切回默认上游版本（`main`）**：
  ```bash
  git checkout main && make build   # 或 make install
  ```

## 版本对比

| 对比项 | 默认版（`magpie`） | DeepWorks 版（`-tags deepworks`） |
| --- | --- | --- |
| 发行名称 | `magpie` | `DeepWorks Bridge`（短名 `DeepWorks`） |
| 版本号后缀 | 无 | `-dw` |
| 默认插件 | 上游 `main` 不含 DeepWorks 插件 | 内置 DeepWorks 插件（自动接入 DeepFoundry） |
| 其余功能（Provider / Agent / GUI） | 完整包含 | 与默认版完全一致，无任何删减 |
| 产物体积（同 `-s -w -trimpath`） | 基准大小 | 与同源码默认构建几乎相同 |
