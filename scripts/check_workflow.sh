#!/usr/bin/env bash
set -euo pipefail

: "${KUBECONFIG:?Set KUBECONFIG}"
: "${DRIVER_POD:?Set DRIVER_POD}"

NS="${NS:-default}"
WORK_ROOT="${WORK_ROOT:-/workspace/rangeland}"
RESULTS_DIR="${RESULTS_DIR:-${WORK_ROOT}/results}"
RUN_LABEL="${RUN_LABEL:-force-rangeland-vivo}"
LOG_REMOTE="${RESULTS_DIR}/nextflow-${RUN_LABEL}.log"
TRACE_REMOTE="${RESULTS_DIR}/trace-${RUN_LABEL}.txt"

kubectl -n "$NS" exec -i "$DRIVER_POD" -- bash -s <<REMOTE
set -euo pipefail
echo "Nextflow process:"
ps -ef | grep -E "[j]ava.*nextflow|[n]extflow run" || true

echo
echo "Status lines:"
grep -E "Execution complete|ERROR ~|WARN: Killing|Error is ignored" "$LOG_REMOTE" || true

echo
echo "Trace counts:"
python3 - <<'PY'
import csv, collections, os
p = "$TRACE_REMOTE"
if not os.path.exists(p):
    print("trace not written yet")
else:
    rows = list(csv.DictReader(open(p), delimiter="\t"))
    print(collections.Counter(r["status"] for r in rows))
PY

echo
echo "Last log lines:"
tail -n 40 "$LOG_REMOTE" || true
REMOTE
