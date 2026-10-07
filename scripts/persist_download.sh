#!/usr/bin/env bash
# REHIDRATAR: baja winux.qcow2 (+OVMF_VARS.fd) del Dataset a un dir escribible
# y verifica sha256 contra manifest.json.
# Uso:  ./persist_download.sh [/kaggle/working/vmdata]
# Despues: bootear con fase4 (DIR=...), que NO re-descarga ISO si ya esta.
set -eu
DIR="${1:-/kaggle/working/vmdata}"
DATASET="marceloate/winux-kaggle-vm-data"

mkdir -p "$DIR"
python3 - "$DATASET" <<'EOF'
import sys
import kagglehub as kh
ds = sys.argv[1]
p = kh.dataset_download(ds, force_download=True)
print("DOWNLOAD OK:", p)
EOF

SRC=/kaggle/input/datasets/marceloate/winux-kaggle-vm-data
[ -f "$SRC/manifest.json" ] || { echo "ERROR: dataset sin manifest.json"; exit 1; }
cp -v "$SRC/winux.qcow2" "$DIR/"
[ -f "$SRC/OVMF_VARS.fd" ] && cp -v "$SRC/OVMF_VARS.fd" "$DIR/"

python3 - "$DIR" <<'EOF'
import hashlib, json, sys
from pathlib import Path
d = Path(sys.argv[1])
manifest = json.loads((d / "manifest.json").read_text()) if (d / "manifest.json").exists() else None
src_manifest = json.loads(Path("/kaggle/input/datasets/marceloate/winux-kaggle-vm-data/manifest.json").read_text())
ok = True
for name, meta in src_manifest["files"].items():
    if name == "manifest.json":
        continue
    p = d / name
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for chunk in iter(lambda: f.read(8 * 1024 * 1024), b""):
            h.update(chunk)
    good = h.hexdigest() == meta["sha256"] and p.stat().st_size == meta["size"]
    print(("OK  " if good else "FAIL"), name, p.stat().st_size)
    ok = ok and good
sys.exit(0 if ok else 1)
EOF
cp "$SRC/manifest.json" "$DIR/"
echo "Rehidratado en $DIR (verificado sha256)"
