#!/bin/bash
set -ouex pipefail

export CFLAGS="-O2 -pipe -march=x86-64-v3 -mtune=generic"
export CXXFLAGS="-O2 -pipe -march=x86-64-v3 -mtune=generic"
export LDFLAGS="-Wl,-O1,--sort-common"

mkdir -p /etc/rpm
cat > /etc/rpm/macros.override << 'EOF'
%_target_cpu x86_64
%optflags -O2 -g -grecord-gcc-switches -pipe -Wall -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -Wp,-D_GLIBCXX_ASSERTIONS -fstack-protector-strong --param=ssp-buffer-size=4 -fasynchronous-unwind-tables -fstack-clash-protection -fcf-protection -march=x86-64-v3 -mtune=generic
EOF

if [ -f /etc/dnf/dnf.conf ]; then
    sed -i '/^\[main\]/a max_parallel_downloads=10' /etc/dnf/dnf.conf
fi

mkdir -p /usr/lib/sysusers.d
cat > /usr/lib/sysusers.d/core-groups.conf << EOF
g audio     - -
g video     - -
g render    - -
g disk      - -
g kvm       - -
g input     - -
g tty       - -
g clock     - -
g utmp      - -
g plugdev   - -
g lp        - -
g bluetooth - -
EOF

getent passwd tss &>/dev/null || useradd -r -g tss -d /var/empty -s /usr/sbin/nologin -c "TPM2 TSS User" tss