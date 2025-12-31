# 脚本名称：sec_check_file_integrity.sh
# 用途：检查关键文件完整性（优先使用 AIDE），发现变更时告警
# 依赖：bash、aide（可选）；否则需外部快照机制
# 权限：建议 root
# 参数：
#   --json                   以 JSON 输出违规数量
# 环境变量：无
# 退出码：0 正常；1 发现变更；2 严重（大量变更或数据库损坏）；3 依赖缺失

set -u
. "$(dirname "$0")/../lib/common.sh"
load_env

JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1 ;;
  esac; shift || true
done

if command -v aide >/dev/null 2>&1; then
  OUT=$(aide --check 2>/dev/null)
  VIOL=$(printf "%s" "$OUT" | grep -c 'changed files')
  SEV=0; [ "$VIOL" -gt 0 ] && SEV=1
  if printf "%s" "$OUT" | grep -qi 'database not found'; then SEV=2; fi
  if [ "$JSON" -eq 1 ]; then
    print_json integrity violations "$VIOL" 0 "$SEV"
  else
    print_human integrity violations "$VIOL" 0 "$SEV"
  fi
  [ $SEV -ge 1 ] && notify_email "文件完整性异常" "violations=$VIOL" || true
  exit $SEV
else
  exit_missing_dep aide
fi