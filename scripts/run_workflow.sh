#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

: "${KUBECONFIG:?Set KUBECONFIG}"
: "${DRIVER_POD:?Set DRIVER_POD}"
: "${FORCE_IMAGE:?Set FORCE_IMAGE}"
: "${WORK_PVC:?Set WORK_PVC}"

NS="${NS:-default}"
WORK_ROOT="${WORK_ROOT:-/workspace/rangeland}"
WF_DIR="${WORK_ROOT}/FORCE2NXF-Rangeland/nextflowWF"
RESULTS_DIR="${RESULTS_DIR:-${WORK_ROOT}/results}"
INPUTDATA="${INPUTDATA:-${WORK_ROOT}/FORCE2NXF-Rangeland/inputdata}"
OUTDATA="${OUTDATA:-${WORK_ROOT}/outputdata}"
RUN_LABEL="${RUN_LABEL:-force-rangeland-$(date +%Y%m%d-%H%M%S)}"
FORCE_VERSION="${FORCE_VERSION:-3.6.5}"
GROUP_SIZE="${GROUP_SIZE:-100}"
USE_CPU="${USE_CPU:-4}"
MAX_RETRIES="${MAX_RETRIES:-5}"
DATA_PVC="${DATA_PVC:-fonda-datasets}"
SERVICE_ACCOUNT="${SERVICE_ACCOUNT:-default}"
SKIP_ARG=""

if [[ "${SKIP_CHECK_RESULTS:-0}" == "1" ]]; then
  SKIP_ARG="--skipCheckResults"
fi

sed \
  -e "s|__NAMESPACE__|${NS}|g" \
  -e "s|__SERVICE_ACCOUNT__|${SERVICE_ACCOUNT}|g" \
  -e "s|__WORK_PVC__|${WORK_PVC}|g" \
  -e "s|__WORK_ROOT__|${WORK_ROOT}|g" \
  -e "s|__DATA_PVC__|${DATA_PVC}|g" \
  -e "s|__FORCE_IMAGE__|${FORCE_IMAGE}|g" \
  -e "s|__USE_CPU__|${USE_CPU}|g" \
  -e "s|__MAX_RETRIES__|${MAX_RETRIES}|g" \
  "$REPO_DIR/templates/fonda.config.template" \
  | kubectl -n "$NS" exec -i "$DRIVER_POD" -- sh -lc "cat > '$WF_DIR/fonda.config'"

kubectl -n "$NS" exec -i "$DRIVER_POD" -- bash -s <<REMOTE
set -euo pipefail
cd "$WF_DIR"
mkdir -p "$RESULTS_DIR"

NXF_ANSI_LOG=false nohup nextflow -c fonda.config run workflow-dsl2.nf \
  --inputdata "$INPUTDATA" \
  --outdata "$OUTDATA" \
  --groupSize "$GROUP_SIZE" \
  --forceVer "$FORCE_VERSION" \
  $SKIP_ARG \
  -with-report "$RESULTS_DIR/report-$RUN_LABEL.html" \
  -with-dag "$RESULTS_DIR/flowchart-$RUN_LABEL.html" \
  -with-trace "$RESULTS_DIR/trace-$RUN_LABEL.txt" \
  -resume > "$RESULTS_DIR/nextflow-$RUN_LABEL.log" 2>&1 &

echo \$! > "$RESULTS_DIR/nextflow-$RUN_LABEL.pid"
REMOTE

echo "Started: $RUN_LABEL"
echo "Log: $RESULTS_DIR/nextflow-$RUN_LABEL.log"
echo "Trace: $RESULTS_DIR/trace-$RUN_LABEL.txt"
