#!/bin/bash
# ctxcraft installer — Evaluate and optimize your AI agent context
#
# Global install (default — available in all projects):
#   curl -sL https://raw.githubusercontent.com/warrenth/ctxcraft/main/install.sh | bash
#
# Project-local install:
#   curl -sL https://raw.githubusercontent.com/warrenth/ctxcraft/main/install.sh | bash -s -- --local

set -e

REPO_URL="https://github.com/warrenth/ctxcraft.git"
TEMP_DIR=$(mktemp -d)

# Parse flags
INSTALL_MODE="global"
for arg in "$@"; do
    case "$arg" in
        --local)  INSTALL_MODE="local" ;;
        --global) INSTALL_MODE="global" ;;
    esac
done

if [ "$INSTALL_MODE" = "global" ]; then
    TARGET_DIR="$HOME/.claude"
    LABEL="globally (~/.claude/)"
else
    TARGET_DIR=".claude"
    LABEL="locally (.claude/)"
fi

echo "🔧 ctxcraft — Token Efficiency Toolkit"
echo "========================================"
echo "   Install target: $LABEL"
echo ""

# Ensure target directories exist
mkdir -p "$TARGET_DIR/skills" "$TARGET_DIR/rules" "$TARGET_DIR/agents"

# Clone repo to temp
echo "📥 Downloading ctxcraft..."
git clone --quiet --depth 1 "$REPO_URL" "$TEMP_DIR/ctxcraft"

# Copy skills
echo "📦 Installing skills..."
cp -r "$TEMP_DIR/ctxcraft/skills/"* "$TARGET_DIR/skills/" 2>/dev/null || true

# Copy agents
echo "📦 Installing agents..."
cp -r "$TEMP_DIR/ctxcraft/agents/"* "$TARGET_DIR/agents/" 2>/dev/null || true

# Copy rules (ask first — rules are loaded every conversation)
echo ""
read -p "📋 Install token-efficiency rules? (loaded every conversation) [y/N] " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    cp "$TEMP_DIR/ctxcraft/rules/token-efficiency.md" "$TARGET_DIR/rules/" 2>/dev/null || true
    echo "   ✅ Rules installed"
else
    echo "   ⏭️  Skipped rules"
fi

# Cleanup
rm -rf "$TEMP_DIR"

echo ""
echo "✅ ctxcraft installed $LABEL"
echo ""
echo "Available commands in Claude Code:"
echo "  /evaluate  — Analyze token efficiency and get a score"
echo "  /optimize  — Apply optimization recommendations"
echo ""
echo "Start with: /evaluate"
