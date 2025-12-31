# 脚本名称：sys_check_fs_errors.sh
# 用途：扫描内核与系统日志中的文件系统错误（只读检查）
# 依赖：bash、dmesg；可选：journalctl
# 权限：建议 root（读取更完整日志），普通用户只读亦可
# 参数：
#   --json               以 JSON 格式输出结果
# 环境变量：无
# 退出码：0 无错误；1 发现错误；2 严重错误（匹配到 panic/BUG）；3 依赖缺失

set -u
. "$(dirname "$0")/../lib/common.sh"
load_env

JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1 ;;
  esac; shift || true
done

require_cmd dmesg || exit_missing_dep dmesg

LOG=$(dmesg -T 2>/dev/null || dmesg)
COUNT=$(printf "%s" "$LOG" | grep -Ei 'EXT4-fs error|XFS .*error|BTRFS .*error|I/O error' | wc -l)
CRIT_COUNT=$(printf "%s" "$LOG" | grep -Ei 'Kernel panic|BUG: unable to handle' | wc -l)

SEV=0; [ "$COUNT" -gt 0 ] && SEV=1; [ "$CRIT_COUNT" -gt 0 ] && SEV=2

if [ "$JSON" -eq 1 ]; then
  print_json filesystem errors "$COUNT" 0 "$SEV"
else
  print_human filesystem errors "$COUNT" 0 "$SEV"; echo "panic/BUG=$CRIT_COUNT"
fi

if [ $SEV -ge 1 ]; then
  notify_email "文件系统错误" "errors=$COUNT panic/BUG=$CRIT_COUNT host=$(hostname_short)" || true
fi
exit $SEV