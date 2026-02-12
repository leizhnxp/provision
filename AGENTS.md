# Provision 仓库规范

## 范围与基线
- 安全基线默认面向团队共享主机，个人便利行为必须显式开启。
- 脚本目标是可重复执行、可审计、可回滚。

## Shell 开发风格
- 所有脚本使用 `#!/bin/bash` 与 `set -euo pipefail`（除非有明确兼容性例外）。
- 输入参数必须先校验再执行系统修改。
- 支持选项的脚本必须提供 `--help`。
- 错误信息应可定位并可执行。

## 幂等要求
- 重复执行不得产生重复配置或重复 key。
- 已存在资源优先补齐或跳过，避免盲目覆盖。

## 系统文件安全
- 修改系统文件前必须创建时间戳备份。
- 插入配置优先使用受管区块（begin/end marker）。
- 涉及 sudoers 的写入必须先做语法校验。

## 语言输出
- 所有用户提示统一使用中文输出。

## 认证与密码策略
- 公钥可公开，但内置默认公钥在共享主机场景有误授权风险。
- 默认允许 `empty-expire`，但必须输出风险提示。
- 必须保留更安全策略（如 `locked`）并通过显式参数启用。

## 提交信息规范
格式：
`<gitmoji> <type>(<scope>)<!>: <subject>`

约束：
- `gitmoji` 必填并与 `type` 语义一致。
- `type` 仅允许：`feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert`。
- `scope` 可选但建议填写（如 `user`/`pam`/`tmux`/`git`/`policy`）。
- `subject` 使用祈使句，简洁，不以句号结束。
- 破坏性变更使用 `!`，并在正文或 footer 写 `BREAKING CHANGE:`。

推荐映射：
- `✨ feat`
- `🐛 fix`
- `📝 docs`
- `♻️ refactor`
- `✅ test`
- `🔧 chore`
- `🚀 perf`
- `🚨 ci`

## Commit 模板
- 仓库提供 `.gitmessage`。
- 本地启用：`git config commit.template .gitmessage`。
