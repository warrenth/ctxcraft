#!/bin/bash
# ctxcraft installer — Evaluate and optimize your AI agent context
# Usage: curl -sL https://raw.githubusercontent.com/warrenth/ctxcraft/main/install.sh | bash

set -e

REPO_URL="https://github.com/warrenth/ctxcraft.git"
TEMP_DIR=$(mktemp -d)
TARGET_DIR=".claude"

echo "🔧 ctxcraft — Token Efficiency Toolkit"
echo "========================================"
echo ""

# Check if .claude directory exists
if [ ! -d "$TARGET_DIR" ]; then
    echo "⚠️  No .claude/ directory found in current project."
    echo "   Run this from your project root directory."
    echo "   Creating .claude/ directory..."
    mkdir -p "$TARGET_DIR/skills" "$TARGET_DIR/rules" "$TARGET_DIR/agents"
fi

# Clone repo to temp
echo "📥 Downloading ctxcraft..."
git clone --quiet --depth 1 "$REPO_URL" "$TEMP_DIR/ctxcraft"

# Copy skills
echo "📦 Installing skills..."
mkdir -p "$TARGET_DIR/skills"
cp -r "$TEMP_DIR/ctxcraft/skills/"* "$TARGET_DIR/skills/" 2>/dev/null || true

# Copy agents
echo "📦 Installing agents..."
mkdir -p "$TARGET_DIR/agents"
cp -r "$TEMP_DIR/ctxcraft/agents/"* "$TARGET_DIR/agents/" 2>/dev/null || true

# Copy rules (ask first)
echo ""
read -p "📋 Install token-efficiency rules? (loaded every conversation) [y/N] " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    mkdir -p "$TARGET_DIR/rules"
    cp "$TEMP_DIR/ctxcraft/rules/token-efficiency.md" "$TARGET_DIR/rules/" 2>/dev/null || true
    echo "   ✅ Rules installed"
else
    echo "   ⏭️  Skipped rules"
fi

# Cleanup
rm -rf "$TEMP_DIR"

echo ""
echo "✅ ctxcraft installed successfully!"
echo ""
echo "Available commands in Claude Code:"
echo "  /evaluate  — Analyze token efficiency and get a score"
echo "  /optimize  — Apply optimization recommendations"
echo ""
echo "Start with: /evaluate"
