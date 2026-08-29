#!/bin/bash
set -ouex pipefail

## ==========================================
## POST-BUILD: seed overlay RakuOS per il first-boot
## (adattato da rakuos-niri/build_files/post-build-overlay.sh)
##
## Il container build NON puo' montare l'overlay su /usr (serve CAP_SYS_ADMIN),
## quindi qui si prepara /usr/share/factory/var/lib/rakuos/ cosi' che al primo
## avvio rakuos-overlay-sync trovi lo stato gia' popolato:
##   - packages.list copiato da /usr/share/rakuos/packages.list
##   - overlay upper/work creati
##   - payload "prebaked" (file dei pacchetti) dentro upper/ -> first-boot senza download
##
## E' best-effort: se la base non ha l'infrastruttura RakuOS o il prebake
## fallisce, la build continua (al first-boot i pacchetti verranno scaricati).
## ==========================================

DEFAULT_PACKAGES_LIST="/usr/share/rakuos/packages.list"
FACTORY_VAR_ROOT="/usr/share/factory/var"
PACKAGES_LIST="$FACTORY_VAR_ROOT/lib/rakuos/packages.list"
UPPER_DIR="$FACTORY_VAR_ROOT/lib/rakuos/overlay/upper"
WORK_DIR="$FACTORY_VAR_ROOT/lib/rakuos/overlay/work"
STATE_FILE="$FACTORY_VAR_ROOT/lib/rakuos/overlay.state"
DIRTY_FILE="$FACTORY_VAR_ROOT/lib/rakuos/overlay.dirty"
FACTORY_RUM_RPMDB="$FACTORY_VAR_ROOT/lib/rakuos/rum-rpmdb"

# Guaina: se la base non espone l'infrastruttura RakuOS, salta tutto in silenzio
if [[ ! -d /usr/share/rakuos ]]; then
    echo "[mardock] Infrastruttura overlay RakuOS non trovata - salto post-build-overlay."
    exit 0
fi

prebake_overlay_from_installroot() {
    local installroot
    local -a prebake_packages=()

    mapfile -t prebake_packages < <(
        grep -v '^\s*#' "$PACKAGES_LIST" \
        | grep -v '^\s*$' \
        | sed 's/\s*#.*//' \
        | tr -s ' \t' '\n' \
        | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
        | grep -v '^$'
    )

    if [[ ${#prebake_packages[@]} -eq 0 ]]; then
        echo "[mardock] Nessun pacchetto in packages.list - salto prebake."
        return 0
    fi

    installroot="$(mktemp -d /var/tmp/mardock-overlay-installroot.XXXXXX)"
    trap 'rm -rf "$installroot"' RETURN

    echo "[mardock] Prebake pacchetti overlay via rum..."
    # Nessun snapshot rpmdb di base nel container: rum risolve "gia installato"
    # contro l'rpmdb del container stesso, che e' esattamente la base su cui
    # viene costruito questo layer. --installroot ridirige i file sotto
    # $installroot/usr e crea un rpmdb overlay nuovo e scartabile.
    rum install --installroot "$installroot" -y --refresh "${prebake_packages[@]}"

    rm -f "$installroot/usr/share/icons/default/index.theme"

    echo "[mardock] Copia payload /usr prebaked in overlay upper..."
    rm -rf "$UPPER_DIR" "$WORK_DIR"
    mkdir -p "$UPPER_DIR" "$WORK_DIR"
    cp -a "$installroot/usr/." "$UPPER_DIR/"

    echo "[mardock] Copia rpmdb overlay prebaked nel seed factory..."
    rm -rf "$FACTORY_RUM_RPMDB"
    mkdir -p "$(dirname "$FACTORY_RUM_RPMDB")"
    cp -a "$installroot/var/lib/rakuos/rum-rpmdb" "$FACTORY_RUM_RPMDB"

    if [[ -d "$installroot/etc" ]] && [[ -n "$(ls -A "$installroot/etc" 2>/dev/null)" ]]; then
        echo "[mardock] Copia payload /etc prebaked nell'immagine..."
        cp -a "$installroot/etc/." /etc/
    fi

    echo "prebaked-installroot" > "$STATE_FILE"
    rm -f "$DIRTY_FILE"

    echo "[mardock] Prebake overlay completato."
}

# Crea directory runtime
mkdir -p "$FACTORY_VAR_ROOT/lib/rakuos"
mkdir -p "$UPPER_DIR" "$WORK_DIR"

# Seed packages.list
if [[ -f "$DEFAULT_PACKAGES_LIST" ]]; then
    cp "$DEFAULT_PACKAGES_LIST" "$PACKAGES_LIST"
    PKG_COUNT=$(grep -v '^\s*#' "$PACKAGES_LIST" | grep -v '^\s*$' | wc -l)
    echo "[mardock] packages.list seed con $PKG_COUNT pacchetti."
else
    echo "[mardock] WARNING: nessun packages.list in $DEFAULT_PACKAGES_LIST"
    touch "$PACKAGES_LIST"
fi

# Pulizia stato obsoleto prima del prebake
rm -f "$STATE_FILE" "$DIRTY_FILE"
sed -i -e '$a\' "$PACKAGES_LIST"

echo "[mardock] Stato overlay obsoleto pulito - il prebake scrivera' lo stato first-boot."

# Protected packages mardockOS:
# evita che brew/upgrade rimuova i pacchetti specifici del DE niri di mardockOS.
if [[ -f /usr/share/rakuos/protected-packages.txt ]]; then
    echo "[mardock] Aggiungo protected packages mardockOS..."
    cat >> /usr/share/rakuos/protected-packages.txt << 'EOF'

# MardockOS niri stack (da build_files/scripts/20-packages.sh)
  niri
  xwayland-satellite
  dms
  dms-greeter
  dankcalendar-git
  danksearch
  quickshell
  greetd
  kitty
  mpv
  code
  nautilus
  nautilus-open-any-terminal
  wlr-randr
  power-profiles-daemon
EOF
fi

# Patch treefile (solo se presente): allinea flag selinux al MAC reale
if [ -f /usr/share/rpm-ostree/treefile.json ]; then
    sed -i 's/"selinux": *true/"selinux": false/' /usr/share/rpm-ostree/treefile.json || true
fi

# Manifest base (se il tool e' fornito dalla base)
if [ -x /usr/libexec/rakuos/generate-base-manifest ]; then
    echo "[mardock] Genero manifest base..."
    /usr/libexec/rakuos/generate-base-manifest || true
fi

# Prebake payload overlay (best-effort)
if prebake_overlay_from_installroot; then
    :
else
    echo "[mardock] WARNING: prebake overlay fallito - al first-boot i pacchetti verranno scaricati."
fi

echo "[mardock] Post-build overlay completato."
