#!/bin/bash

# 检查是否具有root权限
if [ "$EUID" -ne 0 ]; then
  echo "请使用root权限运行该脚本。"
  exit 1
fi

# 检查包管理器类型
if type apt > /dev/null 2>&1; then
  OS_TYPE="debian"
elif type dnf > /dev/null 2>&1; then
  OS_TYPE="rhel"
else
  echo "不支持的操作系统类型。"
  exit 1
fi

# 根据操作系统类型安装pam_ssh_agent_auth
if [ "$OS_TYPE" = "rhel" ]; then
  dnf install -y pam_ssh_agent_auth
elif [ "$OS_TYPE" = "debian" ]; then
  apt-get update
  apt-get install -y libpam-ssh-agent-auth
fi

# 配置pam_ssh_agent_auth（幂等）
PAM_SSH_CONFIG="/etc/pam.d/sudo"
PAM_SSH_AGENT_AUTH_LINE="auth sufficient pam_ssh_agent_auth.so file=~/.ssh/authorized_keys"
MARK_BEGIN="# --- pam_ssh_agent_auth (BEGIN) ---"
MARK_END="# --- pam_ssh_agent_auth (END) ---"

# 如果已经存在 pam_ssh_agent_auth 行，则不重复插入
if grep -Eq '^\s*auth\s+.*pam_ssh_agent_auth\.so' "$PAM_SSH_CONFIG"; then
  echo "已检测到 /etc/pam.d/sudo 中存在 pam_ssh_agent_auth 配置，跳过重复插入。"
else
  tmpfile=$(mktemp)
  {
    echo "$MARK_BEGIN"
    echo "$PAM_SSH_AGENT_AUTH_LINE"
    echo "$MARK_END"
    echo
    cat "$PAM_SSH_CONFIG"
  } > "$tmpfile" && cp "$tmpfile" "$PAM_SSH_CONFIG" && rm -f "$tmpfile"
  echo "已在 /etc/pam.d/sudo 顶部插入 pam_ssh_agent_auth 配置。"
fi

echo "pam_ssh_agent_auth 安装和配置步骤完成。"

# 重新启动SSH服务
if [ "$OS_TYPE" = "rhel" ]; then
  systemctl restart sshd
elif [ "$OS_TYPE" = "debian" ]; then
  systemctl restart ssh
fi

echo "SSH服务已重新启动。"

