# Restored Claude Code Source

[English](./README_EN.md)

![Preview](preview.png)

本仓库包含 Claude Code 源码树，主要通过 source map 逆向工程重建，缺失模块后续补充。

它不代表原始上游状态。部分文件无法仅从 source map 恢复，因此仓库目前包含兼容性填充或降级实现，以允许项目重新安装和运行。

## 已恢复内容

最近一轮恢复工作在初始 source map 导入基础上恢复了多个关键组件：

- 默认 Bun 脚本现在遵循真实的 CLI 启动路径
- `claude-api` 和 `verify` 的捆绑技能内容已从占位符恢复为可用的参考文档
- Chrome MCP 和 Computer Use MCP 的兼容层现在暴露更真实的工具目录，并返回结构化降级响应而非空占位
- 部分显式占位资源已被替换为可用的规划和权限分类器回退提示

剩余缺口主要集中私有或原生集成部分，这些无法仅从 source map 完全恢复，因此这些区域仍依赖填充或降级行为。

## 为什么存在这个仓库

Source map 本身不包含完整的原始仓库：

- 类型定义文件通常缺失
- 构建时生成的文件可能不存在
- 私有包封装和原生绑定可能无法恢复
- 动态导入和资源文件经常不完整

本仓库的目标是将这些缺口填补到"可用、可运行"水平，形成一个可进一步改进的可行恢复工作空间。

## 如何运行

### 快速开始（推荐）

使用安装脚本**自动配置**环境并启动：

```bash
./install.sh
```

安装完成后，按提示执行 `source ~/.bashrc`，然后使用 `claude` 命令启动。

### 手动安装

要求：

- Bun 1.3.5 或更高版本
- Node.js 24 或更高版本

安装依赖：

```bash
bun install
```

运行恢复后的 CLI：

```bash
bun run dev
```

输出恢复版本：

```bash
bun run version
```
