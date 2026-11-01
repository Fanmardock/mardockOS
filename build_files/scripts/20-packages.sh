#!/bin/bash
set -euo pipefail

## ==========================================
## 1. RIMOZIONE PREVENTIVA CONFLITTI
## ==========================================
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
## 2b. KERNEL / XPADNEO
## ==========================================
# La regola corretta è:
# - non usare uname -r
# - non usare kernel-devel generico
# - usare il pacchetto devel che corrisponde al kernel RakuOS v3 disponibile nel repo
#
# Esempio atteso:
#   kernel-rakuos-v3-devel-7.3.0-rakuos.5.v3.fc44.x86_64
#
# Quindi il nome del devel viene ricavato dinamicamente dal repo, non dal runner.

get_latest_rakuos_v3_devel_pkg() {
    local found

    found="$(rum search --showduplicates 'kernel-rakuos-v3-devel' 2>/dev/null || true)"
    if [[ -n "${found}" ]]; then
        printf '%s\n' "${found}" \
            | awk '/^kernel-rakuos-v3-devel-/ {print $1}' \
            | sort -V \
            | tail -n1
        return 0
    fi

    found="$(rum search 'kernel-rakuos-v3-devel' 2>/dev/null || true)"
    if [[ -n "${found}" ]]; then
        printf '%s\n' "${found}" \
            | awk '/^kernel-rakuos-v3-devel-/ {print $1; exit}'
        return 0
    fi

    return 1
}

KERNEL_DEVEL_PKG="$(get_latest_rakuos_v3_devel_pkg || true)"
if [[ -z "${KERNEL_DEVEL_PKG}" ]]; then
    echo "FATAL: nessun kernel-rakuos-v3-devel disponibile nel repo di RakuOS."
    echo "Controllo disponibili:"
    rum search kernel-rakuos-v3-devel 2>/dev/null || true
    exit 1
fi

# Estrae la versione del kernel dal nome del pacchetto:
# kernel-rakuos-v3-devel-7.3.0-rakuos.5.v3.fc44.x86_64
# -> 7.3.0-rakuos.5.v3.fc44.x86_64
KERNEL_VERSION="${KERNEL_DEVEL_PKG#kernel-rakuos-v3-devel-}"

echo "Kernel immagine (repo): ${KERNEL_VERSION}"
echo "Kernel-devel del repo: ${KERNEL_DEVEL_PKG}"

# Installazione base del kernel target
rum install -y \
    dkms \
    gcc \
    make \
    git \
    "${KERNEL_DEVEL_PKG}"

# xpadneo: installa solo se il repo lo fornisce
XPADNEO_AVAILABLE=0
if rum search --showduplicates 'xpadneo-akmod-modules' >/dev/null 2>&1; then
    XPADNEO_AVAILABLE=1
fi

if [[ "${XPADNEO_AVAILABLE}" -eq 1 ]]; then
    echo "Installazione xpadneo-akmod-modules..."
    rum install -y xpadneo-akmod-modules

    akmods --force --rebuild --kernels "${KERNEL_VERSION}"

    if find "/lib/modules/${KERNEL_VERSION}" -type f \( -iname '*xpadneo*.ko*' -o -iname '*xpad*.ko*' \) | grep -q .; then
        echo "Modulo xpadneo costruito per il kernel ${KERNEL_VERSION}"
        mkdir -p /etc/modules-load.d/
        printf '%s\n' "hid-xpadneo" > /etc/modules-load.d/xpadneo.conf
        modprobe xpadneo || true
    else
        echo "WARN: modulo xpadneo non trovato in /lib/modules/${KERNEL_VERSION}; skip."
    fi
else
    echo "WARN: xpadneo-akmod-modules non disponibile nel repo attuale; skip del driver xpadneo."
fi

## ==========================================
## 3. APPLICAZIONI, UTILITY & XBOX DRIVERS
## ==========================================
rum install -y --skip-broken --skip-unavailable \
    code \
    libvirt virt-manager qemu-kvm flatpak-builder wlr-randr \
    iotop sysstat lxqt-openssh-askpass lxpolkit parallel \
    rakuos-software-gtk \
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

## ==========================================
## 4. FIX CONTROLLER XBOX (BLUETOOTH ERTM)
## ==========================================
mkdir -p /etc/modprobe.d/
echo "options bluetooth disable_ertm=1" > /etc/modprobe.d/bluetooth-xbox.conf
echo "options usbcore autosuspend=-1" | tee /etc/modprobe.d/disable-autosuspend.conf

## ==========================================
## 5. PULIZIA PACCHETTI IN ECCESSO
## ==========================================
rum remove -y waybar swaylock alacritty cosmic-comp cosmic-initial-setup cosmic-settings || true