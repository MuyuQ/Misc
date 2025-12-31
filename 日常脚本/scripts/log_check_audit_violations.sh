# 脚本名称：log_check_audit_violations.sh
# 用途：检查 auditd 关键事件与策略违规情况
# 依赖：bash、ausearch 或 auditctl
# 权限：建议 root
# 参数：
#   --json                 以 JSON 输出最近一小时关键事件数量
# 环境变量：无
# 退出码：0 正常；1 有事件；2 严重（大量或高危）；3 依赖缺失

set -u
. "$(dirname "$0")/../lib/common.sh"
load_env

JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1 ;;
  esac; shift || true
done

COUNT=0
if command -v ausearch >/dev/null 2>&1; then
  COUNT=$(ausearch -ts recent 2>/dev/null | grep -Ei 'permission denied|AVC|execve|SYSCALL' | wc -l)
elif command -v auditctl >/dev/null 2>&1; then
  COUNT=$(auditctl -l 2>/dev/null | wc -l)
else
  exit_missing_dep ausearch
fi

SEV=0
if [ "$COUNT" -ge 50 ]; then SEV=2
elif [ "$COUNT" -gt 0 ]; then SEV=1
else SEV=0; fi

if [ "$JSON" -eq 1 ]; then
  print_json audit events "$COUNT" 0 "$SEV"
else
  print_human audit events "$COUNT" 0 "$SEV"
fi

if [ $SEV -ge 1 ]; then
  notify_email "审计事件告警" "count=$COUNT host=$(hostname_short)" || true
fi
exit $SEV