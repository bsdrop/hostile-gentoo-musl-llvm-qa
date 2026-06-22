#!/usr/bin/env bash
# security-sweep.sh — the patch-management half of "security" that hardening flags do NOT cover.
# See docs/08-findings.md F13 (hardening is mitigation, not patch management).
#
# Report-only by default: syncs the tree and enumerates applicable security advisories + pending
# @world updates, without changing anything. Pass --apply to actually pull GLSA fixes + update @world.
#
# Requires: app-portage/gentoolkit (glsa-check). Run as root.
set -u

APPLY=0
[ "${1:-}" = "--apply" ] && APPLY=1

have() { command -v "$1" >/dev/null 2>&1; }

if ! have glsa-check; then
  echo "[sweep] glsa-check missing — emerge app-portage/gentoolkit first" >&2
  exit 1
fi

echo "=== [1/4] sync portage tree ==="
if have eix-sync; then eix-sync; else emerge --sync; fi

echo "=== [2/4] applicable security advisories (GLSA; ~ dnf updateinfo) ==="
# NOTE: a clean result here is NOT proof of zero vulns — many Gentoo fixes ship as plain version
# bumps with no GLSA, so this under-reports. Always pair with the @world update below.
glsa-check -t affected || true
echo "--- detail (test) ---"
glsa-check -d affected 2>/dev/null || true

echo "=== [3/4] pending @world updates (where silent security bumps actually live) ==="
emerge -puDUv --with-bdeps=y @world 2>&1 | tail -40 || true

if [ "$APPLY" -eq 1 ]; then
  echo "=== [4/4] APPLY: GLSA fixes + @world update ==="
  glsa-check -f affected || true
  emerge -uDUv --with-bdeps=y @world
  have etc-update && echo "[sweep] review config updates with etc-update / dispatch-conf"
else
  echo "=== [4/4] report-only (pass --apply to remediate) ==="
  echo "[sweep] to remediate: glsa-check -f affected ; emerge -uDUv @world"
fi
