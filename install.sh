#!/bin/bash

set -e

echo "=== Claude Code 安装脚本 ==="
echo ""

# 检查 GLIBC 版本
echo "检查系统要求..."
GLIBC_VERSION=$(ldd --version 2>/dev/null | head -n1 | grep -oP '\d+\.\d+' | head -n1)
if [ -z "$GLIBC_VERSION" ]; then
    echo "错误: 无法检测 GLIBC 版本"
    exit 1
fi

REQUIRED_VERSION="2.18"
if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$GLIBC_VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]; then
    echo "错误: GLIBC 版本过低 ($GLIBC_VERSION)，需要 $REQUIRED_VERSION 或更高版本"
    echo "Claude Code 依赖 Bun，而 Bun 需要 GLIBC 2.18+"
    echo ""
    echo "=== 升级建议 ==="
    echo ""
    # 检测发行版
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            centos|rhel)
                echo "检测到 $NAME $VERSION_ID"
                echo ""
                echo "请升级到 CentOS/RHEL 8 或更高版本:"
                echo "  1. 备份重要数据"
                echo "  2. 执行系统升级:"
                echo "     sudo dnf update -y"
                echo "     # 或使用 leapp 升级工具迁移到新版本"
                echo "  3. 或考虑迁移到 Rocky Linux/AlmaLinux 8+"
                ;;
            ubuntu)
                echo "检测到 $NAME $VERSION_ID"
                echo ""
                if [ "${VERSION_ID%%.*}" -lt "20" ]; then
                    echo "请升级到 Ubuntu 20.04 LTS 或更高版本:"
                    echo "  1. 备份重要数据"
                    echo "  2. 执行系统升级:"
                    echo "     sudo apt update && sudo apt upgrade -y"
                    echo "     sudo do-release-upgrade"
                    echo "  3. 或直接安装新版本:"
                    echo "     # 查看可用版本"
                    echo "     sudo do-release-upgrade -c"
                fi
                ;;
            debian)
                echo "检测到 $NAME $VERSION_ID"
                echo ""
                echo "请升级到 Debian 10 (buster) 或更高版本:"
                echo "  1. 编辑源列表: sudo nano /etc/apt/sources.list"
                echo "  2. 将版本代号修改为 buster 或更新版本"
                echo "  3. 执行升级:"
                echo "     sudo apt update"
                echo "     sudo apt full-upgrade"
                ;;
            rocky|almalinux)
                echo "检测到 $NAME $VERSION_ID"
                echo ""
                if [ "${VERSION_ID%%.*}" -lt "8" ]; then
                    echo "请升级到 8 或更高版本:"
                    echo "  sudo dnf update -y"
                fi
                ;;
            *)
                echo "检测到操作系统: $PRETTY_NAME"
                echo ""
                echo "请升级到支持 GLIBC 2.18+ 的版本:"
                echo "  - Ubuntu 20.04 LTS 或更高"
                echo "  - CentOS/RHEL/Rocky Linux/AlmaLinux 8 或更高"
                echo "  - Debian 10 (buster) 或更高"
                ;;
        esac
    else
        echo "请升级到支持 GLIBC 2.18+ 的操作系统版本:"
        echo "  - Ubuntu 20.04 LTS 或更高"
        echo "  - CentOS/RHEL/Rocky Linux/AlmaLinux 8 或更高"
        echo "  - Debian 10 (buster) 或更高"
    fi
    echo ""
    echo "注意: GLIBC 是系统核心库，不建议手动编译升级，建议升级操作系统"
    exit 1
fi
echo "GLIBC 版本: $GLIBC_VERSION ✓"
echo ""

# 检查是否在正确的目录
cd "$(dirname "$0")"

# 创建临时下载目录
DOWNLOAD_DIR="$(mktemp -d)"	trap "rm -rf $DOWNLOAD_DIR" EXIT

# 检测系统架构
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)
        NODE_ARCH="linux-x64"
        BUN_ARCH="linux-x64"
        ;;
    aarch64|arm64)
        NODE_ARCH="linux-arm64"
        BUN_ARCH="linux-aarch64"
        ;;
    *)
        echo "错误: 不支持的架构: $ARCH"
        exit 1
        ;;
esac

echo "检测到系统架构: $ARCH"
echo ""

# Node.js 和 Bun 版本
NODE_VERSION="25.1.0"
BUN_VERSION="1.3.11"

# 下载 Node.js
echo "下载 Node.js v${NODE_VERSION} (${NODE_ARCH})..."
NODE_URL="https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-${NODE_ARCH}.tar.xz"
NODE_FILE="$DOWNLOAD_DIR/node.tar.xz"

if command -v curl &> /dev/null; then
    curl -fsSL "$NODE_URL" -o "$NODE_FILE" --progress-bar
elif command -v wget &> /dev/null; then
    wget -O "$NODE_FILE" "$NODE_URL" --progress=bar:force 2>&1 | tail -f -n +6
else
    echo "错误: 需要 curl 或 wget 来下载文件"
    exit 1
fi

if [ ! -f "$NODE_FILE" ]; then
    echo "错误: Node.js 下载失败"
    exit 1
fi
echo "Node.js 下载完成"
echo ""

# 下载 Bun
echo "下载 Bun v${BUN_VERSION} (${BUN_ARCH})..."
BUN_URL="https://github.com/oven-sh/bun/releases/download/bun-v${BUN_VERSION}/bun-${BUN_ARCH}.zip"
BUN_FILE="$DOWNLOAD_DIR/bun.zip"

if command -v curl &> /dev/null; then
    curl -fsSL "$BUN_URL" -o "$BUN_FILE" --progress-bar
elif command -v wget &> /dev/null; then
    wget -O "$BUN_FILE" "$BUN_URL" --progress=bar:force 2>&1 | tail -f -n +6
fi

if [ ! -f "$BUN_FILE" ]; then
    echo "错误: Bun 下载失败"
    exit 1
fi
echo "Bun 下载完成"
echo ""

# 安装 Node.js
echo "安装 Node.js..."
mkdir -p "$HOME/.local"
rm -rf "$HOME/.local/node-v${NODE_VERSION}-${NODE_ARCH}"
tar -xf "$NODE_FILE" -C "$HOME/.local"

# 安装 Bun
echo "安装 Bun..."
rm -rf "$HOME/.local/bun"
mkdir -p "$HOME/.local/bun"
unzip -o "$BUN_FILE" -d "$HOME/.local/bun"

# 为当前会话设置 PATH
export PATH="$HOME/.local/node-v${NODE_VERSION}-${NODE_ARCH}/bin:$PATH"
BUN_BINARY=$(find "$HOME/.local/bun" -name 'bun' -type f | head -1)
if [ -n "$BUN_BINARY" ]; then
    export PATH="$(dirname "$BUN_BINARY"):$PATH"
fi

# 验证安装
echo "验证安装..."
if ! command -v node &> /dev/null; then
    echo "错误: Node.js 安装失败"
    exit 1
fi
if ! command -v bun &> /dev/null; then
    echo "错误: Bun 安装失败"
    exit 1
fi

echo "Node.js 版本: $(node --version)"
echo "Bun 版本: $(bun --version)"

# 添加 PATH 到 .bashrc（如果还没有添加）
NODE_PATH="\$HOME/.local/node-v${NODE_VERSION}-${NODE_ARCH}/bin"
BUN_DIR="\$HOME/.local/bun"

if ! grep -q "$NODE_PATH" ~/.bashrc; then
    echo "添加 Node.js PATH 到 .bashrc..."
    echo "export PATH=\"$NODE_PATH:\$PATH\"" >> ~/.bashrc
fi

if ! grep -q "$BUN_DIR" ~/.bashrc; then
    echo "添加 Bun PATH 到 .bashrc..."
    echo "export PATH=\"$BUN_DIR/bun-${BUN_ARCH}:\$PATH\"" >> ~/.bashrc
fi

# 设置 Claude Code API 环境变量（需要配置离线大模型，请取消注释并替换IP:Port，pass_token，model_name）
# echo "配置 API 环境变量..."
# if ! grep -q "ANTHROPIC_BASE_URL" ~/.bashrc; then
#     echo 'export ANTHROPIC_BASE_URL="http://IP:Port"' >> ~/.bashrc
# fi

# if ! grep -q "ANTHROPIC_AUTH_TOKEN" ~/.bashrc; then
#     echo 'export ANTHROPIC_AUTH_TOKEN="pass_token"' >> ~/.bashrc
# fi

# if ! grep -q "ANTHROPIC_MODEL" ~/.bashrc; then
#     echo 'export ANTHROPIC_MODEL="model_name"' >> ~/.bashrc
# fi


# 确保 bin/claude 存在且可执行
if [ ! -f "bin/claude" ]; then
    echo "错误: bin/claude 不存在"
    exit 1
fi
chmod +x bin/claude

# 安装依赖
echo "安装项目依赖..."
if [ -d "node_modules" ]; then
    echo "检测到 node_modules 已存在，跳过安装"
else
    bun install
fi

# 本地 link claude 命令
echo "设置 claude 命令..."
bun link --local 2>/dev/null || bun link 2>/dev/null || true

# 创建全局可访问的 claude 快捷方式
mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/claude" << EOF
#!/bin/bash
export PATH="\$HOME/.local/node-v${NODE_VERSION}-${NODE_ARCH}/bin:\$PATH"
BUN_BIN=\$(find "\$HOME/.local/bun" -name 'bun' -type f | head -1)
if [ -n "\$BUN_BIN" ]; then
    export PATH="\$(dirname "\$BUN_BIN"):\$PATH"
fi
cd "$(pwd)" && bun run ./src/bootstrap-entry.ts "\$@"
EOF
chmod +x "$HOME/.local/bin/claude"

# 添加 ~/.local/bin 到 PATH
if ! grep -q '\$HOME/.local/bin' ~/.bashrc; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
fi

export PATH="$HOME/.local/bin:$PATH"

# 设置 claude.json 配置（跳过引导流程）
echo "配置 Claude Code..."
CLAUDE_JSON="$HOME/.claude.json"
if [ ! -f "$CLAUDE_JSON" ]; then
    echo '{"hasCompletedOnboarding": true}' > "$CLAUDE_JSON"
else
    # 使用 node 修改 JSON 文件
    node -e "
    const fs = require('fs');
    const path = '$CLAUDE_JSON';
    let data = {};
    try {
        data = JSON.parse(fs.readFileSync(path, 'utf8'));
    } catch (e) {
        data = {};
    }
    data.hasCompletedOnboarding = true;
    fs.writeFileSync(path, JSON.stringify(data, null, 2));
    "
fi

echo ""
echo "=== 安装完成 ==="
echo ""
echo "请运行以下命令使环境变量生效:"
echo "  source ~/.bashrc"
echo ""
echo "然后可以使用 'claude' 命令启动 Claude Code"
echo ""

# 立即测试运行
if command -v claude &> /dev/null; then
    echo "claude 命令已可用"
    claude --version 2>/dev/null || echo "版本信息获取失败，可能需要 source ~/.bashrc 后重试"
else
    echo "claude 命令将在 source ~/.bashrc 后可用"
fi
