#!/bin/bash
set -ouex pipefail

## ==========================================
## 1. RIMOZIONE PREVENTIVA CONFLITTI
## ==========================================
# Rimozione di tuned-ppd per consentire l'installazione di power-profiles-daemon
# Rimozione di qt6ct nativo se presente, per evitare conflitti
rum remove -y tuned-ppd || true

## ==========================================
## 2. STACK RAKUOS / NIRI / COMPONENTI DI SISTEMA
## ==========================================
rum install -y \
    niri \
    xwayland-satellite \
    dms \
    dms-greeter \
    dankcalendar-git \
    danksearch \
    quickshell \
    greetd \
    cups-pk-helper \
    xdg-desktop-portal \
    xdg-desktop-portal-gnome \
    xdg-desktop-portal-gtk \
    xdg-user-dirs-gtk \
    wl-clipboard \
    wtype \
    wl-mirror \
    gnome-keyring \
    gnome-keyring-pam \
    fprintd-pam \
    pipewire \
    wireplumber \
    pavucontrol \
    blueman \
    ddcutil \
    adw-gtk3-theme \
    qt6ct \
    libnotify \
    power-profiles-daemon \
    libva-utils \
    clinfo \
    vulkan-tools

## ==========================================
## 2b. ABILITAZIONE COPR XPADNEO
## ==========================================
# akmod-xpadneo NON è presente nei repository ufficiali Fedora/RakuOS:
# vive nel COPR shdwchn10/xpadneo (il vecchio sentry/xpadneo è stato rimosso).
# Scriviamo il file .repo inline così è idempotente e non dipende da $releasever.
cat > /etc/yum.repos.d/copr-xpadneo.repo << 'EOF'
[copr:shdwchn10:xpadneo]
name=Copr repo for xpadneo owned by shdwchn10
baseurl=https://download.copr.fedorainfracloud.org/results/shdwchn10/xpadneo/fedora-$releasever-$basearch/
type=rpm-md
skip_if_unavailable=True
gpgcheck=1
gpgkey=https://download.copr.fedorainfracloud.org/results/shdwchn10/xpadneo/pubkey.gpg
repo_gpgcheck=0
enabled=1
EOF

## ==========================================
## 3. APPLICAZIONI, UTILITY & XBOX DRIVERS
## ==========================================
rum install -y --skip-broken --skip-unavailable\
    code \
    libvirt virt-manager qemu-kvm flatpak-builder wlr-randr \
    iotop sysstat lxqt-openssh-askpass lxpolkit parallel \
    rakuos-software-gtk \
    akmod-xpadneo \
    bluez \
    bluez-tools \
    nautilus \
    kitty \
    ghostty \
    mpv \
    rfkill \
    gvfs \
    gvfs-mtp \
    gvfs-nfs \
    file-roller \
    gnome-calculator \
    gnome-disk-utility \
    nautilus-open-any-terminal

#!/bin/bash
set -euo pipefail

## ==========================================
## 2b. XPADNEO: build solo se il kernel dell'immagine ha il devel
## ==========================================

# 1) determina il kernel effettivo dell'immagine, da RPM, non da /lib/modules/*
CURRENT_KERNEL="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-core 2>/dev/null || uname -r)"
echo "Kernel dell'immagine: ${CURRENT_KERNEL}"

TARGET_KERNEL="${CURRENT_KERNEL}"

# 2) se il kernel attuale non ha il devel, cerca una versione precedente compatibile
if ! rpm -q "kernel-devel-${TARGET_KERNEL}" >/dev/null 2>&1; then
    echo "kernel-devel per ${TARGET_KERNEL} non disponibile; cerco una versione compatibile precedente..."

    # Cerca la versione più recente disponibile con kernel-devel
    # Nota: se repoquery non è disponibile, puoi usare "dnf repoquery" al suo posto
    mapfile -t CANDIDATES < <(
        dnf repoquery --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' --latest-limit 20 'kernel-devel' 2>/dev/null \
        | sort -V || true
    )

    FOUND=""
    for cand in "${CANDIDATES[@]}"; do
        if rpm -q "kernel-devel-${cand}" >/dev/null 2>&1; then
            FOUND="${cand}"
            break
        fi
    done

    if [ -z "${FOUND}" ]; then
        echo "FATAL: nessun kernel-devel compatibile trovato per xpadneo; fermo il build."
        exit 1
    fi

    TARGET_KERNEL="${FOUND}"
    echo "Uso kernel compatibile: ${TARGET_KERNEL}"

    # Se vuoi pinare la versione compatibile, puoi bloccarla così:
    rum install -y "kernel-${TARGET_KERNEL}" "kernel-devel-${TARGET_KERNEL}" || true
    rum versionlock add kernel kernel-devel || true
else
    echo "Kernel attuale compatibile con xpadneo: ${TARGET_KERNEL}"
    rum install -y "kernel-devel-${TARGET_KERNEL}"
fi

# 3) build del modulo solo sul kernel compatibile
echo "Building xpadneo against image kernel: ${TARGET_KERNEL}"
akmods --force --rebuild --kernels "${TARGET_KERNEL}"

find "/lib/modules/${TARGET_KERNEL}" -name 'xpad.ko*' | grep -q . || \
    { echo "ERROR: xpad.ko non trovato sotto /lib/modules/${TARGET_KERNEL}"; exit 1; }

mkdir -p /etc/modules-load.d/
echo "hid-xpadneo" > /etc/modules-load.d/xpadneo.conf

## ==========================================
## 4. FIX CONTROLLER XBOX (BLUETOOTH ERTM)
## ==========================================
# Disabilita ERTM per evitare disconnessioni del pad Xbox via Bluetooth
mkdir -p /etc/modprobe.d/
echo "options bluetooth disable_ertm=1" > /etc/modprobe.d/bluetooth-xbox.conf

echo "options usbcore autosuspend=-1" | tee /etc/modprobe.d/disable-autosuspend.conf
## ==========================================
## 5. PULIZIA PACCHETTI IN ECESSO (POST-INSTALL)
## ==========================================
rum remove -y waybar swaylock alacritty cosmic-comp cosmic-initial-setup cosmic-settings || true
