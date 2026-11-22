#!/usr/bin/env bash
# Reads the index that is live on the downloads server over SSH (port 24), the same way publish_upload_ssh.sh
# uploads, and writes it to OUT_FILE. It exists because the web server (port 443) sometimes does not answer GitHub's
# runners while the SSH port does. It only runs the server's read-only `index` command.
#
# Environment: SSH_HOST, SSH_USER, SSH_PORT (default 22), SSH_KEY_FILE, SSH_KNOWN_HOSTS_FILE, SSH_MACS (optional),
#   SSH_COMMAND (default bin/forge-templates-receive), OUT_FILE (required), SSH_TRIES (default 3), SSH_RETRY_WAIT (20).
# Exit status: 0 the index was written; 3 the server says there is no index yet (the first publish);
#   anything else: it could not be read (the caller decides what to do, and must not guess).
set -euo pipefail

fail() { echo "error: $*" >&2; exit 1; }

: "${SSH_HOST:?}" "${SSH_USER:?}" "${OUT_FILE:?}"
SSH_PORT="${SSH_PORT:-22}"
SSH_COMMAND="${SSH_COMMAND:-bin/forge-templates-receive}"
SSH_TRIES="${SSH_TRIES:-3}"
SSH_RETRY_WAIT="${SSH_RETRY_WAIT:-20}"
[[ "$SSH_PORT" =~ ^[0-9]+$ ]] || fail "SSH_PORT must be a number"
[[ "$SSH_TRIES" =~ ^[1-9][0-9]*$ ]] || fail "SSH_TRIES must be a positive number"
[[ "$SSH_RETRY_WAIT" =~ ^[0-9]+$ ]] || fail "SSH_RETRY_WAIT must be a number"
[[ "$SSH_HOST" =~ ^[A-Za-z0-9._-]+$ ]] || fail "SSH_HOST has odd characters"
[[ "$SSH_USER" =~ ^[A-Za-z0-9._-]+$ ]] || fail "SSH_USER has odd characters"
[[ "$SSH_COMMAND" =~ ^[A-Za-z0-9._/-]+$ ]] || fail "SSH_COMMAND has odd characters"
[[ "${SSH_MACS:-}" =~ ^[A-Za-z0-9,@.-]*$ ]] || fail "SSH_MACS has odd characters"
[ -f "${SSH_KEY_FILE:-}" ] || fail "SSH_KEY_FILE is not a file"
[ -s "${SSH_KNOWN_HOSTS_FILE:-}" ] || fail "SSH_KNOWN_HOSTS_FILE is empty: pin the server's host key"

ssh_opts=(-i "$SSH_KEY_FILE" -p "$SSH_PORT" -o BatchMode=yes -o IdentitiesOnly=yes -o ConnectTimeout=30
  -o ServerAliveInterval=15 -o StrictHostKeyChecking=yes -o UserKnownHostsFile="$SSH_KNOWN_HOSTS_FILE")
[ -z "${SSH_MACS:-}" ] || ssh_opts+=(-o "MACs=$SSH_MACS")

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
try=1
while true; do
  set +e
  ssh "${ssh_opts[@]}" "$SSH_USER@$SSH_HOST" "$SSH_COMMAND index" > "$tmp"
  code=$?
  set -e
  if [ "$code" -eq 0 ]; then
    # what came back must be the index, not an error message or a half-sent file
    python3 - "$tmp" <<'PYEOF' || fail "the server answered, but not with a valid index.json"
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
assert d.get("schema") == 1 and isinstance(d.get("templates"), list) and d["templates"], "not an index"
PYEOF
    mkdir -p "$(dirname "$OUT_FILE")"
    cp "$tmp" "$OUT_FILE"
    echo "read the live index over ssh ($SSH_HOST:$SSH_PORT)"
    exit 0
  fi
  if [ "$code" -eq 3 ]; then
    echo "the server has no index yet (the first publish)"
    exit 3
  fi
  if [ "$try" -ge "$SSH_TRIES" ]; then
    echo "could not read the index over ssh after $SSH_TRIES tries (last status $code)" >&2
    exit 1
  fi
  echo "try $try of $SSH_TRIES failed (status $code); waiting $SSH_RETRY_WAIT s"
  sleep "$SSH_RETRY_WAIT"
  try=$((try + 1))
done
