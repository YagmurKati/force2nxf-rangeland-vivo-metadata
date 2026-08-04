# FORCE2NXF-Rangeland VIVO Metadata

Run `CRC-FONDA/FORCE2NXF-Rangeland` on the FONDA Kubernetes cluster, collect execution metadata, and produce a Turtle (`.ttl`) file for VIVO.

This repository does not redistribute `FORCE2NXF-Rangeland`. It provides helper scripts and documentation for the VIVO metadata collection layer. For the workflow itself, use the upstream repository:

```text
https://github.com/CRC-FONDA/FORCE2NXF-Rangeland
```

If you use the workflow or its scientific method, cite the upstream workflow and publication. If you use these helper scripts to produce VIVO metadata, cite this repository. See `CITATION.cff` and `CITATIONS.md`.

## Files

- `Dockerfile.force-raster`: FORCE image with R packages needed by merge steps.
- `templates/fonda.config.template`: Nextflow Kubernetes config template.
- `scripts/run_workflow.sh`: writes `fonda.config` in the driver pod and starts Nextflow.
- `scripts/check_workflow.sh`: checks run status and trace counts.
- `scripts/collect_vivo_ttl.sh`: collects Nextflow, Kubernetes, Prometheus, energy, carbon, and code metadata.
- `scripts/collect_force_workflow_run_only_metadata.py`: TTL collector.
- `examples/env.example`: environment variables to edit.
- `CITATION.cff`: machine-readable citation file.
- `CITATIONS.md`: human-readable citation guidance.

## Requirements

- FONDA Kubernetes access.
- `kubectl` configured with your kubeconfig.
- A Nextflow driver pod with access to the workflow work PVC.
- A read-only data PVC mounted at `/shared`.
- Prometheus and Kepler running in the cluster.
- Docker Hub account if you build your own FORCE image.
- Python 3 on your local machine.

Do not commit `config.yml`, `wg0.conf`, `.env`, or generated run outputs.

## 1. Configure

```bash
git clone <your-github-repo-url>
cd force2nxf-rangeland-vivo-metadata

cp examples/env.example .env
vim .env
source .env
```

Required edits in `.env`:

```bash
export KUBECONFIG=/path/to/fonda/config.yml
export NS=default
export DRIVER_POD=your-rangeland-driver-pod
export WORK_PVC=your-rangeland-work-pvc
export FORCE_IMAGE=yourdockerhub/force-dev-raster:latest
export RUN_LABEL=force-rangeland-vivo
```

## 2. Build FORCE Image

The merge steps need R packages `raster`, `terra`, `sp`, and `Rcpp`.

```bash
docker login
docker buildx build --platform linux/amd64 \
  -f Dockerfile.force-raster \
  -t "$FORCE_IMAGE" \
  --push .
```

Test the image:

```bash
kubectl -n "$NS" run force-raster-test --rm -it --restart=Never \
  --image="$FORCE_IMAGE" \
  --command -- sh -lc 'date +%s%3N; Rscript -e "library(raster); library(terra); library(sp); library(Rcpp); print(\"OK\")"'
```

If the pod already exists:

```bash
kubectl -n "$NS" delete pod force-raster-test --ignore-not-found
```

## 3. Prepare Workflow Input

Enter the driver pod:

```bash
kubectl -n "$NS" exec -it "$DRIVER_POD" -- bash
```

Clone the workflow:

```bash
mkdir -p /workspace/rangeland
cd /workspace/rangeland
git clone https://github.com/CRC-FONDA/FORCE2NXF-Rangeland.git
```

Use the shared FONDA input data read-only:

```bash
cd /workspace/rangeland/FORCE2NXF-Rangeland/inputdata
rm -rf download dem wvdb vector endmember
ln -s /shared/b5/eo-01/download download
ln -s /shared/b5/eo-01/dem dem
ln -s /shared/b5/eo-01/wvdb wvdb
ln -s /shared/b5/eo-01/vector vector
ln -s /shared/b5/eo-01/endmember endmember
ls -l
exit
```

Do not write into `/shared`.

If shared data are not available, download the input data using the original workflow README. Expect hundreds of GB.

## 4. Run Workflow

From your local machine:

```bash
source .env
chmod +x scripts/*.sh
scripts/run_workflow.sh
```

This writes:

```text
/workspace/rangeland/results/nextflow-$RUN_LABEL.log
/workspace/rangeland/results/trace-$RUN_LABEL.txt
/workspace/rangeland/results/report-$RUN_LABEL.html
/workspace/rangeland/results/flowchart-$RUN_LABEL.html
```

Check progress:

```bash
scripts/check_workflow.sh
```

Finished run:

```text
Execution complete -- Goodbye
```

If only `checkResults` fails and the log says `Error is ignored`, the workflow completed. The upstream README says this can happen when Kubernetes uses a different downloaded dataset. To skip that comparison in a new run:

```bash
export SKIP_CHECK_RESULTS=1
scripts/run_workflow.sh
```

## 5. Start Prometheus Port Forward

Open a second terminal:

```bash
source .env
kubectl -n monitoring port-forward svc/prometheus-kube-prometheus-prometheus 19090:9090
```

Keep this terminal open while collecting metadata.

## 6. Collect VIVO TTL

In the first terminal:

```bash
source .env
scripts/collect_vivo_ttl.sh
```

Outputs:

```text
value of $OUTPUT_TTL
matching .metrics.json file
metadata/VIVO_UPLOAD_FILES.txt
```

Use run-only mode when the workflow page already exists in VIVO. The script already uses:

```bash
--existing-workflow-run-only
```

This prevents duplicate workflow title, description, code, engine, language, and subproject data.

## 7. Send To VIVO

Send these files to the VIVO importer/admin:

```text
metadata/$RUN_LABEL.ttl
metadata/$RUN_LABEL.metrics.json
```

Upload only the `.ttl` file to VIVO. Keep `.metrics.json` as an audit file.

## Important VIVO Fields

Set these in `.env` or pass them to `scripts/collect_vivo_ttl.sh`:

```bash
export WORKFLOW_URI=http://example.org/vivo-import/run-metadata/workflow/long-term-vegetation-dynamics-in-the-mediterranean-force2nxf
export PUBLICATION_URI=http://141.20.184.157:8080/vivo/individual/a1-publication-key-lehmann2021forceon
export RUN_OPERATOR_URI=<your VIVO person URI>
export RESPONSIBLE_RESEARCHER_URI=<workflow owner VIVO person URI>
export SUBPROJECT_URI=<FONDA subproject URI>
```

For a new workflow page, remove `--existing-workflow-run-only` from `scripts/collect_vivo_ttl.sh`.

## Troubleshooting

`there is no package called 'raster'`

Build and use `Dockerfile.force-raster`. Check that `FORCE_IMAGE` is correct.

`Unexpected: unbound variable`

The merge step used an image without the `date +%s%3N` fix. Rebuild and push the image.

`Prometheus returned no metrics`

Start the port-forward again. If the run is too old for Prometheus retention, set:

```bash
export ALLOW_MISSING_METRICS=1
scripts/collect_vivo_ttl.sh
```

`checkResults` failed

If the log says `Error is ignored`, keep the run. If you do not need reference validation, set `SKIP_CHECK_RESULTS=1` before rerunning.
