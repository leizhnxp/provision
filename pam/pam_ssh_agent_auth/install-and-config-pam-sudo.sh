#!/bin/bash

set -euo pipefail

RESTART_SSH="yes"
PAM_SSH_CONFIG="/etc/pam.d/sudo"
PAM_SSH_AGENT_AUTH_LINE="auth sufficient pam_ssh_agent_auth.so file=~/.ssh/authorized_keys"
MARK_BEGIN="# --- pam_ssh_agent_auth (BEGIN) ---"
MARK_END="# --- pam_ssh_agent_auth (END) ---"

say() { echo "$1"; }

err() {
  echo "错误: $1" >&2
}

usage() {
  cat <<'EOF'
用法:
  install-and-config-pam-sudo.sh [--no-restart-ssh] [--help]
EOF
}

while (($# > 0)); do
  case "$1" in
    --no-restart-ssh)
      RESTART_SSH="no"
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      err "未知参数: $1"
      usage
      exit 1
      ;;
  esac
  shift
done

if [[ "$EUID" -ne 0 ]]; then
  err "请使用 root 权限运行此脚本。"
  exit 1
fi

if command -v apt-get >/dev/null 2>&1; then
  OS_TYPE="debian"
elif command -v dnf >/dev/null 2>&1; then
  OS_TYPE="rhel"
else
  err "不支持的系统（未检测到 apt-get 或 dnf）。"
  exit 1
fi

if [[ ! -f "$PAM_SSH_CONFIG" ]]; then
  err "缺少 PAM 配置文件: $PAM_SSH_CONFIG"
  exit 1
fi

if [[ "$OS_TYPE" == "rhel" ]]; then
  dnf install -y pam_ssh_agent_auth
else
  apt-get update
  apt-get install -y libpam-ssh-agent-auth
fi

backup_file() {
  local timestamp
  timestamp="$(date +%Y%m%d%H%M%S)"
  local backup_path="${PAM_SSH_CONFIG}.bak.${timestamp}"
  cp -a "$PAM_SSH_CONFIG" "$backup_path"
  say "已创建备份: $backup_path"
}

write_managed_block() {
  local source_file="$1"
  local tmp_output
  tmp_output="$(mktemp)"
  awk -v mark_begin="$MARK_BEGIN" -v mark_end="$MARK_END" '
    BEGIN {skip=0}
    $0 == mark_begin {skip=1; next}
    $0 == mark_end {skip=0; next}
    skip == 0 {print}
  ' "$source_file" >"$tmp_output"

  {
    echo "$MARK_BEGIN"
    echo "$PAM_SSH_AGENT_AUTH_LINE"
    echo "$MARK_END"
    echo
    cat "$tmp_output"
  } >"${tmp_output}.merged"

  cp "${tmp_output}.merged" "$source_file"
  rm -f "$tmp_output" "${tmp_output}.merged"
}

if grep -Eq '^\s*auth\s+.*pam_ssh_agent_auth\.so' "$PAM_SSH_CONFIG"; then
  say "$PAM_SSH_CONFIG 中已存在 pam_ssh_agent_auth 配置，跳过插入。"
else
  backup_file
  write_managed_block "$PAM_SSH_CONFIG"
  say "已更新 $PAM_SSH_CONFIG 中的受管 PAM 区块。"
fi

say "pam_ssh_agent_auth 安装和配置完成。"

if [[ "$RESTART_SSH" == "yes" ]]; then
  if [[ "$OS_TYPE" == "rhel" ]]; then
    systemctl restart sshd
  else
    systemctl restart ssh
  fi
  say "SSH 服务已重启。"
else
  say "由于 --no-restart-ssh，已跳过 SSH 重启。"
fi
