#!/usr/bin/env bash
# Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.
# 

# Build and install the PKCS#11 bridge to /usr/local/lib on this Mac.
#
# /usr/local/lib is the production home because it sits inside
# ssh-agent's default PKCS#11 provider allowlist (/usr/lib* and
# /usr/local/lib*); a module anywhere under $HOME is refused by
# ssh-add unless the agent is started with an explicit -P override.
# /usr/lib itself is sealed by SIP. The installed name matches the
# Linux module (librefineid_pkcs11.so) so consumer documentation and
# SunPKCS11 configuration read the same on both platforms.
#
# The library's install name is rewritten to its installed path and
# the bundle is re-signed ad hoc, since install_name_tool invalidates
# the build signature.
#
# Usage:
#
#   Scripts/install-pkcs11-macos.sh            build, install, verify
#   Scripts/install-pkcs11-macos.sh --check    verify what is installed
#
set -euo pipefail
cd "$(dirname "$0")/.."

library_name="librefineid_pkcs11.dylib"
sign_library_name="librefineid_pkcs11_sign.dylib"
install_dir="/usr/local/lib"
installed="${install_dir}/${library_name}"
installed_sign="${install_dir}/${sign_library_name}"
package_dir="PKCS11Bridge"
built="${package_dir}/.build/release/libPKCS11Bridge.dylib"

# Names from earlier revisions that no longer exist; removed on
# install so no stale profile lingers.
superseded_names=("librefineid_pkcs11_signing.dylib")

fail() { echo "install-pkcs11-macos: $*" >&2; exit 1; }
note() { echo "install-pkcs11-macos: $*"; }

# Lists the card keys through the installed module. A missing card is
# not a failure; the module is still installed correctly.
smoke_test() {
  note "smoke test: ssh-keygen -D ${installed}"
  if ssh-keygen -D "$installed" 2>/dev/null | sed 's/^/  /'; then
    note "card keys listed"
  else
    note "no card keys listed (no card inserted?); insert the card and run:"
    note "  ssh-keygen -D ${installed}"
  fi
}

# Stages one name from the shared binary and installs it: the same
# module behaves as authentication-only or full depending on the file
# name it is loaded under (see IdentityPolicy in the package).
install_variant() {
  local name="$1"
  local target="${install_dir}/${name}"
  local staged="${package_dir}/.build/release/${name}"
  note "staging ${name} with production install name"
  cp "$built" "$staged"
  install_name_tool -id "$target" "$staged"
  codesign --force --sign - "$staged"
  codesign --verify "$staged" || fail "staged ${name} failed signature verification"
  note "installing to ${target}"
  if [[ -w "$install_dir" ]]; then
    install -m 0755 "$staged" "$target"
  else
    sudo install -d -m 0755 "$install_dir"
    sudo install -m 0755 "$staged" "$target"
  fi
  note "installed: $(ls -l "$target")"
}

# Removes library names from earlier revisions.
remove_superseded() {
  local name
  for name in "${superseded_names[@]}"; do
    local target="${install_dir}/${name}"
    [[ -e "$target" ]] || continue
    note "removing superseded ${target}"
    if [[ -w "$install_dir" ]]; then
      rm -f "$target"
    else
      sudo rm -f "$target"
    fi
  done
}

if [[ "${1:-}" == "--check" ]]; then
  for target in "$installed" "$installed_sign"; do
    [[ -f "$target" ]] || fail "nothing installed at ${target}"
    codesign --verify "$target" || fail "signature verification failed: ${target}"
    note "installed: $(ls -l "$target")"
  done
  smoke_test
  exit 0
fi

note "building release"
(cd "$package_dir" && swift build -c release)
[[ -f "$built" ]] || fail "build produced no ${built}"

install_variant "$library_name"
install_variant "$sign_library_name"
remove_superseded
smoke_test
note "done. ssh usage: ssh -o PKCS11Provider=${installed} user@host"
note "signing consumers (SunPKCS11/DSS) load: ${installed_sign}"
