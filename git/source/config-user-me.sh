#!/bin/bash

set -euo pipefail

show_value() {
  local level="$1"
  local key="$2"
  local value
  value="$(git config "--${level}" "$key" 2>/dev/null || true)"
  if [[ -n "$value" ]]; then
    echo "  ${key}=${value}"
  else
    echo "  ${key}=<未设置>"
  fi
}

echo "Local 配置列表:"
local_list="$(git config --local --list 2>/dev/null || true)"
if [[ -n "$local_list" ]]; then
  echo "$local_list"
else
  echo "<local 未发现配置>"
fi
show_value "local" "user.name"
show_value "local" "user.email"

echo "Global 配置列表:"
global_list="$(git config --global --list 2>/dev/null || true)"
if [[ -n "$global_list" ]]; then
  echo "$global_list"
else
  echo "<global 未发现配置>"
fi
show_value "global" "user.name"
show_value "global" "user.email"
