#!/bin/bash
set -ouex pipefail

# 1. Determinazione dinamica della cartella degli script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="${SCRIPT_DIR}/scripts"

echo "=== Avvio Build Standard: caricamento moduli da ${MODULES_DIR} ==="

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

echo "=== Build Standard completata con successo ==="
