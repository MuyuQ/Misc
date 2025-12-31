# 脚本名称：web_check_http_health.sh
# 用途：对多个 URL 执行 HTTP 健康检查（状态码、响应时间）
# 依赖：bash、curl
# 权限：无需 root
# 参数：
#   --json                   以 JSON 输出最差响应时间与失败计数
#   --urls u1,u2             覆盖 URL 列表
# 环境变量：
#   HTTP_CHECK_URLS="https://example.com/"
# 退出码：0 正常；1 警告（响应慢/部分失败）；2 严重（大量失败）；3 依赖缺失

set -u
. "$(dirname "$0")/../lib/common.sh"
load_env

command -v curl >/dev/null 2>&1 || exit_missing_dep curl

JSON=0; URLS=${HTTP_CHECK_URLS:-https://example.com/}
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1 ;;
    --urls) URLS="$2"; shift ;;
  esac; shift || true
done

WORST_MS=0; FAILS=0; TOTAL=0
IFS=',' read -r -a arr <<< "$URLS"
for u in "${arr[@]}"; do
  TOTAL=$((TOTAL+1))
  res=$(curl -s -o /dev/null -w '%{http_code} %{time_total}' "$u" 2>/dev/null)
  code=$(echo "$res" | awk '{print $1}')
  ms=$(echo "$res" | awk '{printf "%.0f", $2*1000}')
  [ "$ms" -gt "$WORST_MS" ] && WORST_MS=$ms
  if [ "$code" -lt 200 ] || [ "$code" -ge 400 ]; then FAILS=$((FAILS+1)); fi
done

SEV=0
if [ "$FAILS" -ge "$TOTAL" ]; then SEV=2
elif [ "$FAILS" -gt 0 ] || [ "$WORST_MS" -ge 2000 ]; then SEV=1
else SEV=0; fi

if [ "$JSON" -eq 1 ]; then
  print_json http worst_latency_ms "$WORST_MS" 2000 "$SEV"; echo "{""failures"":""$FAILS""}"
else
  print_human http worst_latency_ms "$WORST_MS" 2000 "$SEV"; echo "failures=$FAILS total=$TOTAL"
fi

if [ $SEV -ge 1 ]; then
  notify_email "HTTP 健康异常" "worst_ms=$WORST_MS failures=$FAILS/$TOTAL host=$(hostname_short)" || true
fi
exit $SEV