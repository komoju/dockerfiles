#!/bin/sh
set -u

. /etc/os-release

# Fixed Debian revisions for CVE-2026-111497.
case "$VERSION_CODENAME" in
  bookworm) fixed=1.0.9-2+deb12u1 ;;
  trixie) fixed=1.1.0-2+deb13u1 ;;
  *)
    echo "::warning::Debian $VERSION_CODENAME has no fixed libbrotli1 for CVE-2026-111497"
    exit 0
    ;;
esac

version=$(dpkg-query -W -f='${Version}' libbrotli1 2>/dev/null)
if [ -z "$version" ]; then
  echo "ok   libbrotli1 is not installed"
elif dpkg --compare-versions "$version" ge "$fixed"; then
  echo "ok   libbrotli1 $version (fixed in $fixed)"
else
  echo "FAIL libbrotli1 $version, expected $fixed or later"
  exit 1
fi
