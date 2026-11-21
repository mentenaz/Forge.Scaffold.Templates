#!/usr/bin/env bash
# One-off: ties the templates deploy key to ~/bin/forge-templates-receive in ~/.ssh/authorized_keys, so the
# key can run only stage, finish and check (no shell, no other path, no forwarding).
#
# Run it on the server, for example from the templates repo on Windows (PowerShell):
#   (Get-Content -Raw tools\server\restrict-key.sh) -replace "`r","" | ssh -p 24 -o MACs=hmac-sha2-256 mentefpu@downloads.mentenaz-server.com "bash -s"
#
# It keeps a dated copy of the file, changes only the one line of this key, refuses to do anything if that
# line is not found exactly once, and does nothing if the line is already restricted.
# To undo it: copy the dated backup (~/.ssh/authorized_keys.bak-<date>) back over ~/.ssh/authorized_keys.
set -euo pipefail

F="${AUTHORIZED_KEYS:-$HOME/.ssh/authorized_keys}"
KEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINfHNnnQ+P1jlgBwBYm/lOqV7pfyHMnyltTbdI23ii5S'
CMD='command="/home/mentefpu/bin/forge-templates-receive",restrict'

[ -f "$F" ] || { echo "no $F" >&2; exit 1; }
[ -x "$HOME/bin/forge-templates-receive" ] || { echo "~/bin/forge-templates-receive is not installed and executable: install it first" >&2; exit 1; }

n="$(grep -c -F "$KEY" "$F" || true)"
[ "$n" = "1" ] || { echo "expected the key on exactly one line, found $n: nothing changed" >&2; exit 1; }
if grep -F "$KEY" "$F" | grep -q '^command='; then
  echo "the key is already restricted: nothing changed"
  exit 0
fi

cp -p "$F" "$F.bak-$(date +%Y%m%d%H%M%S)"
awk -v key="$KEY" -v cmd="$CMD" 'index($0, key) == 1 { print cmd " " $0; next } { print }' "$F" > "$F.new"
[ "$(wc -l < "$F.new")" = "$(wc -l < "$F")" ] || { rm -f "$F.new"; echo "line count changed: nothing changed" >&2; exit 1; }
grep -q "^$CMD $KEY" "$F.new" || { rm -f "$F.new"; echo "the edit did not apply: nothing changed" >&2; exit 1; }
chmod --reference="$F" "$F.new"
mv "$F.new" "$F"
echo "restricted. The line now starts:"
grep -F "$KEY" "$F" | cut -c1-120
