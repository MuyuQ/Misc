# 脚本名称：log_check_auth_failures.sh
# 用途：检查登录失败事件（如 SSH），异常时告警
# 依赖：bash、journalctl 或 /var/log/auth.log
# 权限：建议 root
# 参数：
#   --json                 以 JSON 输出最近一小时失败次数
# 环境变量：无
# 退出码：0 正常；1 有失败；2 严重（失败很多）；3 依赖缺失

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
if command -v journalctl >/dev/null 2>&1; then
  COUNT=$(journalctl --since "-60 min" 2>/dev/null | grep -Ei 'Failed password|authentication failure' | wc -l)
elif [ -r /var/log/auth.log ]; then
  COUNT=$(grep -Ei 'Failed password|authentication failure' /var/log/auth.log 2>/dev/null | wc -l)
else
  exit_missing_dep journalctl/auth.log
fi

SEV=0
if [ "$COUNT" -ge 50 ]; then SEV=2
elif [ "$COUNT" -gt 0 ]; then SEV=1
else SEV=0; fi

if [ "$JSON" -eq 1 ]; then
  print_json auth failures "$COUNT" 0 "$SEV"
else
  print_human auth failures "$COUNT" 0 "$SEV"
fi

if [ $SEV -ge 1 ]; then
  notify_email "登录失败异常" "count=$COUNT host=$(hostname_short)" || true
fi
exit $SEV