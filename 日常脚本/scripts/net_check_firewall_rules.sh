#!/bin/bash
# 脚本名称：net_check_firewall_rules.sh
# 用途：检查防火墙规则是否存在，空规则或默认全通告警
# 依赖：bash、nft 或 iptables
# 权限：建议 root（读取完整规则）
# 参数：
#   --json               以 JSON 格式输出规则条目数量
# 环境变量：无
# 退出码：0 正常；1 警告（规则较少或默认 ACCEPT）；2 严重（无规则）；3 依赖缺失

set -euo pipefail
. "$(dirname "$0")/../lib/common.sh"
load_env
DESCRIPTION="检查防火墙规则是否存在，空规则或默认全通告警"

JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1 ;;
    --help|-h) print_help; exit 0 ;;
  esac; shift || true
done

RULES=0; SEV=0; MSG=""
if command -v nft >/dev/null 2>&1; then
  RULES=$(nft list ruleset 2>/dev/null | grep -c 'chain' || true)
  DEFAULT=$(nft list ruleset 2>/dev/null | grep -E 'policy' | awk '{print $NF}' | sort -u | tr '\n' ' ' || true)
  if [ "$RULES" -eq 0 ]; then SEV=2
  elif echo "$DEFAULT" | grep -qi 'accept'; then SEV=1
  fi
  MSG="nft policies=$DEFAULT"
elif command -v iptables >/dev/null 2>&1; then
  RULES=$(iptables -S 2>/dev/null | wc -l | tr -d ' ')
  DEFAULT=$(iptables -L 2>/dev/null | awk '/Chain INPUT|Chain FORWARD|Chain OUTPUT/ {chain=$2} /policy/ {print chain ":" $4}' | tr '\n' ' ')
  if [ "$RULES" -eq 0 ]; then SEV=2
  elif echo "$DEFAULT" | grep -qi 'ACCEPT'; then SEV=1
  fi
  MSG="iptables policies=$DEFAULT"
else
  exit_missing_dep nft/iptables
fi

if [ "$JSON" -eq 1 ]; then
  print_json firewall rules "$RULES" 1 "$SEV"
else
  print_human firewall rules "$RULES" 1 "$SEV"; echo "$MSG"
fi

if [ $SEV -ge 1 ]; then
  notify_email "防火墙规则异常" "rules=$RULES $MSG host=$(hostname_short)" || true
fi
exit $SEV