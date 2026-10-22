#!/bin/sh
set -eu

. /etc/os-release

# Pull the patched ca-certificates and Node.js releases where the distro still
# ships security updates.
case "$VERSION_CODENAME" in
  bookworm|trixie)
    apt-get update
    apt-get install -y --no-install-recommends --only-upgrade ca-certificates nodejs
    rm -rf /var/lib/apt/lists/*
    ;;
esac

# Distrust the roots that the compromised eMudhra intermediates chain to.
sed -i \
  -e 's|^mozilla/emSign_ECC_Root_CA_-_G3.crt|!&|' \
  -e 's|^mozilla/Comodo_AAA_Services_root.crt|!&|' \
  /etc/ca-certificates.conf
update-ca-certificates --fresh
