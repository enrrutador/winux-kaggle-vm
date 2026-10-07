#!/usr/bin/env bash
# CHECKPOINT: sube winux.qcow2 + OVMF_VARS.fd + manifest al Dataset
# marceloate/winux-kaggle-vm-data (nueva version).
# REQUISITO: la VM debe estar APAGADA (qcow2 inconsistente si QEMU corre).
# Uso:  ./persist_upload.sh [/kaggle/working/vmdata] ["notas de version"]
set -eu
DIR="${1:-/kaggle/working/vmdata}"
NOTES="${2:-checkpoint winux qcow2}"
DATASET="marceloate/winux-kaggle-vm-data"

if pgrep -f "[q]emu-system" >/dev/null; then
  echo "ERROR: QEMU corriendo. Apaga la VM antes del checkpoint (poweroff en guest o kill)."
  exit 1
fi
[ -f "$DIR/winux.qcow2" ] || { echo "ERROR: no existe $DIR/winux.qcow2"; exit 1; }

STAGE=/tmp/vm-persist-stage
rm -rf "$STAGE"; mkdir -p "$STAGE"
cp "$DIR/winux.qcow2" "$STAGE/"
[ -f "$DIR/OVMF_VARS.fd" ] && cp "$DIR/OVMF_VARS.fd" "$STAGE/"

python3 - "$STAGE" <<'EOF'
import hashlib, json, sys, time
from pathlib import Path
stage = Path(sys.argv[1])
files = {}
for p in sorted(stage.iterdir()):
    if not p.is_file():
        continue
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for chunk in iter(lambda: f.read(8 * 1024 * 1024), b""):
            h.update(chunk)
    files[p.name] = {"size": p.stat().st_size, "sha256": h.hexdigest()}
manifest = {
    "kind": "winux-kaggle-vm-data",
    "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    "files": files,
}
(stage / "manifest.json").write_text(json.dumps(manifest, indent=2))
print(json.dumps(manifest, indent=2)[:800])
EOF

python3 - "$DATASET" "$STAGE" "$NOTES" <<'EOF'
import sys
import kagglehub as kh
ds, stage, notes = sys.argv[1], sys.argv[2], sys.argv[3]
kh.dataset_upload(ds, stage, version_notes=notes)
print("UPLOAD OK:", ds)
EOF
rm -rf "$STAGE"
echo "Checkpoint publicado en $DATASET"
