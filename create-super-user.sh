#!/bin/bash

set -euo pipefail

DEFAULT_USERNAME="zhenhua.lei"
DEFAULT_PUBKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHbWEZygV6f+MENAwwP24NwGGMOqKC0XkH6DjEE7PVSA zhenhua.lei@GUI"
PASSWORD_POLICY="empty-expire"
BASE_DIR=$([ -d "/mnt/disk/sub/home" ] && echo "/mnt/disk/sub/home" || echo "/home")

warn() {
  local msg="$1"
  echo "警告: $msg" >&2
}

err() {
  local msg="$1"
  echo "错误: $msg" >&2
}

usage() {
  cat <<'EOF'
用法:
  create-super-user.sh [username] [public_key] [--password-policy <empty-expire|locked>] [--help]

示例:
  ./create-super-user.sh zhenhua.lei "ssh-ed25519 AAAA... comment"
  ./create-super-user.sh zhenhua.lei "ssh-ed25519 AAAA... comment" --password-policy locked
EOF
}

is_valid_username() {
  local value="$1"
  [[ "$value" =~ ^[a-z_][a-z0-9_.-]{0,31}$ ]]
}

is_valid_pubkey() {
  local value="$1"
  [[ "$value" =~ ^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp(256|384|521))\ [A-Za-z0-9+/=]+(\ .*)?$ ]]
}

find_available_id() {
  local id=61919
  while getent passwd "$id" >/dev/null 2>&1 || getent group "$id" >/dev/null 2>&1; do
    ((id++))
  done
  echo "$id"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    err "缺少必要命令: $1"
    exit 1
  }
}

USERNAME="$DEFAULT_USERNAME"
PUBLIC_KEY="$DEFAULT_PUBKEY"
POSITIONAL_INDEX=0

while (($# > 0)); do
  case "$1" in
    --password-policy)
      shift
      if (($# == 0)); then
        err "--password-policy 需要参数值。"
        usage
        exit 1
      fi
      PASSWORD_POLICY="$1"
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --*)
      err "未知参数: $1"
      usage
      exit 1
      ;;
    *)
      if ((POSITIONAL_INDEX == 0)); then
        USERNAME="$1"
      elif ((POSITIONAL_INDEX == 1)); then
        PUBLIC_KEY="$1"
      else
        err "位置参数过多。"
        usage
        exit 1
      fi
      ((POSITIONAL_INDEX += 1))
      ;;
  esac
  shift
done

case "$PASSWORD_POLICY" in
  empty-expire|locked) ;;
  *)
    err "无效的 --password-policy: $PASSWORD_POLICY"
    exit 1
    ;;
esac

if ! is_valid_username "$USERNAME"; then
  err "用户名不合法: '$USERNAME'。"
  exit 1
fi

if ! is_valid_pubkey "$PUBLIC_KEY"; then
  err "SSH 公钥格式不合法。"
  exit 1
fi

if [[ "$PUBLIC_KEY" == "$DEFAULT_PUBKEY" ]]; then
  warn "正在使用内置默认公钥。共享主机建议显式传入公钥。"
fi

require_command sudo
require_command useradd
require_command usermod
require_command getent
require_command visudo

SUDOERS_FILE_SAFE_NAME="$(echo "$USERNAME" | tr -cd '[:alnum:]_.-' | tr '.' '_')"
SUDOERS_FILE="/etc/sudoers.d/${SUDOERS_FILE_SAFE_NAME}"
SUDOERS_MARK_BEGIN="# --- create-super-user managed block (BEGIN) ---"
SUDOERS_MARK_END="# --- create-super-user managed block (END) ---"

if id "$USERNAME" >/dev/null 2>&1; then
  echo "用户 '$USERNAME' 已存在，继续执行补齐逻辑。"
  USER_HOME="$(getent passwd "$USERNAME" | cut -d: -f6)"
  PRIMARY_GROUP="$(id -gn "$USERNAME")"
else
  if getent group "$USERNAME" >/dev/null 2>&1; then
    GID="$(getent group "$USERNAME" | cut -d: -f3)"
  else
    GID="$(find_available_id)"
    sudo groupadd -g "$GID" "$USERNAME"
  fi

  sudo useradd "$USERNAME" -u "${GID}" -g "${GID}" -m -s /bin/bash -b "$BASE_DIR"
  USER_HOME="$(getent passwd "$USERNAME" | cut -d: -f6)"
  PRIMARY_GROUP="$(id -gn "$USERNAME")"
fi

if getent group wheel >/dev/null 2>&1; then
  sudo usermod -aG wheel "$USERNAME"
elif getent group sudo >/dev/null 2>&1; then
  sudo usermod -aG sudo "$USERNAME"
else
  warn "系统不存在 wheel 或 sudo 组，跳过管理员组分配。"
fi

SUDOERS_TMP="$(mktemp)"
cat >"$SUDOERS_TMP" <<EOF
${SUDOERS_MARK_BEGIN}
$USERNAME ALL=(ALL) ALL
Defaults:$USERNAME timestamp_timeout=1000
Defaults:$USERNAME env_keep += "SSH_AUTH_SOCK"
${SUDOERS_MARK_END}
EOF

sudo visudo -cf "$SUDOERS_TMP" >/dev/null
sudo install -m 0440 "$SUDOERS_TMP" "$SUDOERS_FILE"
rm -f "$SUDOERS_TMP"

USER_SSH_DIR="${USER_HOME}/.ssh"
USER_AUTH_KEYS="${USER_SSH_DIR}/authorized_keys"

sudo install -d -m 0700 -o "$USERNAME" -g "$PRIMARY_GROUP" "$USER_SSH_DIR"
sudo touch "$USER_AUTH_KEYS"
sudo chown "$USERNAME:$PRIMARY_GROUP" "$USER_AUTH_KEYS"
sudo chmod 0600 "$USER_AUTH_KEYS"

if sudo grep -Fxq "$PUBLIC_KEY" "$USER_AUTH_KEYS"; then
  echo "公钥已存在于 ${USER_AUTH_KEYS}，跳过追加。"
else
  echo "$PUBLIC_KEY" | sudo tee -a "$USER_AUTH_KEYS" >/dev/null
  echo "已将公钥写入 ${USER_AUTH_KEYS}。"
fi

sudo chmod 0700 "$USER_HOME"

case "$PASSWORD_POLICY" in
  empty-expire)
    warn "应用密码策略 empty-expire（风险较高，仅建议在受控环境使用）。"
    sudo passwd -d "$USERNAME"
    sudo chage -d 0 "$USERNAME"
    ;;
  locked)
    echo "应用密码策略: locked。"
    sudo passwd -l "$USERNAME"
    ;;
esac

echo "用户 '$USERNAME' 初始化完成。"
