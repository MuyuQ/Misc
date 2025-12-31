# 脚本名称：net_check_route_table_changes.sh
# 用途：检测路由表与基线差异（可选），发现变更时告警
# 依赖：bash、ip route
# 权限：无需 root
# 参数：
#   --json                 以 JSON 输出差异条目数量
#   --baseline <path>      指定基线文件路径（若不存在则创建）
# 环境变量：
#   ROUTE_BASELINE_PATH=./state/route.last
# 退出码：0 无差异；1 有差异；2 严重（路由条目显著变化）；3 依赖缺失

set -u
. "$(dirname "$0")/../lib/common.sh"
load_env

JSON=0; BASELINE=${ROUTE_BASELINE_PATH:-./state/route.last}
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1 ;;
    --baseline) BASELINE="$2"; shift ;;
  esac; shift || true
done

require_cmd ip || exit_missing_dep ip

CUR=$(ip route show | sort)
mkdir -p "$(dirname "$BASELINE")" 2>/dev/null || true
if [ ! -f "$BASELINE" ]; then
  printf "%s\n" "$CUR" > "$BASELINE"
  DIFF_CNT=0
else
  DIFF_CNT=$(diff -u "$BASELINE" <(printf "%s\n" "$CUR") | grep -E '^[+-]' | grep -Ev '^---|^+++' | wc -l)
fi

SEV=0
if [ "$DIFF_CNT" -ge 20 ]; then SEV=2
elif [ "$DIFF_CNT" -gt 0 ]; then SEV=1
else SEV=0; fi

if [ "$JSON" -eq 1 ]; then
  print_json network route_diff "$DIFF_CNT" 0 "$SEV"
else
  print_human network route_diff "$DIFF_CNT" 0 "$SEV"
fi

if [ $SEV -ge 1 ]; then
  notify_email "路由表变更" "diff_count=$DIFF_CNT host=$(hostname_short)" || true
fi

# 更新基线
printf "%s\n" "$CUR" > "$BASELINE"
exit $SEV