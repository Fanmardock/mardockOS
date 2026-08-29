#!/bin/bash
set -ouex pipefail

echo "=== Configurazione Greetd e Servizi di Sistema ==="

# 1. Creazione directory e configurazione principale di greetd
mkdir -p /etc/greetd/

cat > /etc/greetd/config.toml << 'EOF'
[terminal]
vt = "next"

[default_session]
user = "greeter"
command = "dms-greeter --command niri"
EOF

chmod 0755 /etc/greetd
chmod 0644 /etc/greetd/config.toml
chown -R root:root /etc/greetd

# 2. Configurazione permessi e utenti per il greeter
mkdir -p /usr/lib/sysusers.d/
cat > /usr/lib/sysusers.d/greetd.conf << 'EOF'
g video 44 -
g render 989 -
u greeter - "Greetd Greeter" - /usr/sbin/nologin
m greeter video
m greeter render
EOF

# 3. Cache directory per DMS
mkdir -p /usr/lib/tmpfiles.d/
cat > /usr/lib/tmpfiles.d/dms.conf << 'EOF'
d /var/cache/dms 0770 greeter greeter - -
Z /var/cache/dms 0770 greeter greeter - -
EOF

# 4. Sblocco automatico Keyring GNOME su PAM (se il file esiste)
if [ -f /etc/pam.d/greetd ]; then
    sed -i -E 's/^-([a-z]+[[:space:]]+.*pam_gnome_keyring\.so)/\1/' /etc/pam.d/greetd
fi

# 5. Abilitazione servizi systemd (con override forzato di display-manager.service)
rm -f /etc/systemd/system/display-manager.service
systemctl enable --force greetd.service

echo "=== Configurazione systemd completata ==="
