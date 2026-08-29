#!/bin/bash
set -ouex pipefail

# 1. Determinazione dinamica della cartella degli script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="${SCRIPT_DIR}/scripts"

echo "=== Avvio Build AMD: caricamento moduli da ${MODULES_DIR} ==="

# 2. Esecuzione sequenziale dei moduli condivisi (inclusi 20-packages e 30-systemd)
if [ -d "$MODULES_DIR" ]; then
    for module in "$MODULES_DIR"/*.sh; do
        if [ -f "$module" ]; then
            echo "===> Esecuzione modulo: $module"
            bash "$module"
        fi
    done
else
    echo "ERRORE CRITICO: Directory $MODULES_DIR non trovata!"
    exit 1
fi

# 3. Impostazione flag di ottimizzazione compilazione per il runner
export CFLAGS="-O2 -pipe -march=x86-64-v3 -mtune=znver3"
export CXXFLAGS="-O2 -pipe -march=x86-64-v3 -mtune=znver3"

# 4. Installazione componenti, ROCm ed extra driver per AMD
echo "=== Installazione driver, ROCm ed estensioni hardware AMD ==="

# Aggiornamento preventivo stack Mesa per allineamento versione
rum upgrade -y --allowerasing "mesa-*" || true

# Installazione completa driver, supporto ROCm Compute e utility AMD
rum install -y --allowerasing \
    linux-firmware \
    mesa-va-drivers-freeworld \
    mesa-vdpau-drivers-freeworld \
    rocm-opencl \
    rocm-smi \
    radeontop

echo "=== Build AMD completata con successo ==="
