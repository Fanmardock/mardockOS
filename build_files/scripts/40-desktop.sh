#!/bin/bash
set -ouex pipefail

# Script di gestione DMS per l'utente
cat > /usr/bin/rakuos-niri-shell << 'EOF'
#!/bin/bash
if [ "$EUID" -eq 0 ]; then
    echo "Questo script non deve essere eseguito da root!"
    exit 1
fi

case "$1" in
    "dms")
        systemctl --user unmask dms
        systemctl --user enable --now dms
        echo "DankMaterialShell attivata correttamente."
        ;;
    "none")
        systemctl --user stop dms
        systemctl --user disable dms
        echo "Shell disabilitata."
        ;;
    *)
        echo "Uso: rakuos-niri-shell <dms|none>"
        ;;
esac
EOF
chmod +x /usr/bin/rakuos-niri-shell

# Setup User Dotfiles
mkdir -p /usr/lib/systemd/user/
cat > /usr/lib/systemd/user/dotfiles-setup.service << 'UNIT'
[Unit]
Description=Initial User Dotfiles and Shell Setup
After=graphical-session-pre.target

[Service]
Type=oneshot
ExecStart=/usr/bin/bash -c '\
  FLAG="%h/.local/share/dotfiles-setup"; \
  if [ ! -f "$FLAG" ]; then \
    mkdir -p "%h/.config" "%h/.local/share"; \
    cp -rn /etc/skel/. "%h/"; \
    touch "$FLAG"; \
  fi'

[Install]
WantedBy=graphical-session.target
UNIT

systemctl enable --global dotfiles-setup.service
systemctl enable --global dms.service

# Audio Unmute
mkdir -p /etc/profile.d
cat > /etc/profile.d/unmute-audio.sh << 'EOF'
if command -v amixer &> /dev/null; then
    (
        sleep 3
        amixer -c 0 set Master unmute 70% &>/dev/null || true
        amixer -c 0 set Speaker unmute 70% &>/dev/null || true
        amixer -c 0 set Front unmute 70% &>/dev/null || true
        amixer set Master unmute 70% &>/dev/null || true
        amixer set Speaker unmute 70% &>/dev/null || true
        amixer -c 0 set IEC958 unmute 100% &>/dev/null || true
        amixer -c 0 set "IEC958,0" unmute 100% &>/dev/null || true
        amixer -c 1 set IEC958 unmute 100% &>/dev/null || true
        amixer -c 1 set "IEC958,0" unmute 100% &>/dev/null || true
    ) &
fi
EOF
chmod +x /etc/profile.d/unmute-audio.sh

# Switch Automatico WirePlumber per HDMI
mkdir -p /etc/wireplumber/wireplumber.conf.d
cat > /etc/wireplumber/wireplumber.conf.d/50-hdmi-switch.conf << 'EOF'
wireplumber.settings = {
    "linking.follow-routes": true
}
EOF

# Gsettings Terminal Override
mkdir -p /usr/share/glib-2.0/schemas/
cat > /usr/share/glib-2.0/schemas/99_nautilus-open-any-terminal.gschema.override << EOF
[com.github.stunkymonkey.nautilus-open-any-terminal]
terminal='kitty'
EOF
glib-compile-schemas /usr/share/glib-2.0/schemas

# Copia Niri Config di Default
mkdir -p /etc/skel/.config/niri/
cp -rf /ctx/dot_config/niri/. /etc/skel/.config/niri/

# Provisioning Flatpak
cat > /usr/lib/systemd/system/flatpak-provisioning.service << 'UNIT'
[Unit]
Description=Install system Flatpaks on first boot
After=network-online.target
Wants=network-online.target
ConditionPathExists=!/var/lib/flatpak-provisioning.done

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/bash -c '\
  flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo; \
  flatpak install --noninteractive --or-update flathub com.bambulab.BambuStudio || true; \
  flatpak install --noninteractive --or-update flathub info.febvre.Komikku || true; \
  flatpak install --noninteractive --or-update flathub com.google.Chrome || true; \
  touch /var/lib/flatpak-provisioning.done'

[Install]
WantedBy=multi-user.target
UNIT

systemctl enable flatpak-provisioning.service

mkdir -p /etc/modprobe.d
cat > /etc/modprobe.d/bluetooth-xbox-ertm.conf << EOF
options bluetooth disable_ertm=1
EOF