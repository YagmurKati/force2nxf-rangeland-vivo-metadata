#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_DIR"

: "${KUBECONFIG:?Set KUBECONFIG}"
: "${DRIVER_POD:?Set DRIVER_POD}"

NS="${NS:-default}"
WORK_ROOT="${WORK_ROOT:-/workspace/rangeland}"
WF_DIR="${WORK_ROOT}/FORCE2NXF-Rangeland/nextflowWF"
RESULTS_DIR="${RESULTS_DIR:-${WORK_ROOT}/results}"
RUN_LABEL="${RUN_LABEL:-force-rangeland-vivo}"
PROM_URL="${PROM_URL:-http://127.0.0.1:19090}"
OUTPUT_TTL="${OUTPUT_TTL:-metadata/${RUN_LABEL}.ttl}"

ARGS=(
  python3 scripts/collect_force_workflow_run_only_metadata.py
  --namespace "$NS"
  --driver-pod "$DRIVER_POD"
  --trace-remote "$RESULTS_DIR/trace-$RUN_LABEL.txt"
  --console-log-remote "$RESULTS_DIR/nextflow-$RUN_LABEL.log"
  --debug-log-remote "$WF_DIR/.nextflow.log"
  --prom-url "$PROM_URL"
  --carbon-intensity-source "${CARBON_INTENSITY_SOURCE:-co2map}"
  --co2map-data-status "${CO2MAP_DATA_STATUS:-preliminary}"
  --existing-workflow-run-only
  --output-file "$OUTPUT_TTL"
)

if [[ "${ALLOW_MISSING_METRICS:-0}" == "1" ]]; then
  ARGS+=(--allow-missing-metrics)
fi

if [[ "${INCLUDE_CACHED_ORIGIN_METRICS:-0}" == "1" ]]; then
  ARGS+=(--include-cached-origin-metrics)
fi

if [[ -n "${WORKFLOW_URI:-}" ]]; then
  ARGS+=(--workflow-uri "$WORKFLOW_URI")
fi

if [[ -n "${PUBLICATION_URI:-}" ]]; then
  ARGS+=(--publication-uri "$PUBLICATION_URI")
fi

if [[ -n "${RUN_OPERATOR_URI:-}" ]]; then
  ARGS+=(--run-operator-uri "$RUN_OPERATOR_URI")
fi

if [[ -n "${RESPONSIBLE_RESEARCHER_URI:-}" ]]; then
  ARGS+=(--responsible-researcher-uri "$RESPONSIBLE_RESEARCHER_URI")
fi

if [[ -n "${SUBPROJECT_URI:-}" ]]; then
  ARGS+=(--subproject-uri "$SUBPROJECT_URI")
fi

if [[ -n "${APPLICATION_DOMAIN_URI:-}" ]]; then
  ARGS+=(--application-domain-uri "$APPLICATION_DOMAIN_URI")
fi

if [[ -n "${BACKEND_URI:-}" ]]; then
  ARGS+=(--backend-uri "$BACKEND_URI")
fi

"${ARGS[@]}" "$@"
