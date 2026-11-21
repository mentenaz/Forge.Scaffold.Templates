#!/usr/bin/env bash
# Uploads a built release (see publish_build.sh) to the downloads server over SSH, using only ssh and tar.
#
# The server side is tools/server/forge-templates-receive.sh, installed as ~/bin/forge-templates-receive,
# which is also the only thing the deploy key may run once it is switched on in authorized_keys.
#
# 1. stage:  the files travel as one tar stream into a staging folder on the server. Nothing is live yet.
# 2. finish: the server renames every archive from the staging folder into place, then index.json last.
#            A rename inside one folder is atomic, so a client never sees a half-written file, and an
#            index never points at a file that is not there yet. Nothing else on the server is touched.
#
# Environment:
#   OUT_DIR              the built release (default ./out)
#   SSH_HOST, SSH_USER   required
#   SSH_PORT             default 22
#   SSH_COMMAND          what to run on the server, default bin/forge-templates-receive (relative to home)
#   SSH_KEY_FILE         required (unless DRY_RUN=1). The private key of the deploy user.
#   SSH_KNOWN_HOSTS_FILE required (unless DRY_RUN=1). Holds the server's pinned host key: the
#                        host key is checked strictly, there is no "trust on first use".
#   SSH_MACS             optional. This server only accepts hmac-sha2-256.
#   SSH_TRIES            how many times to try the whole upload (default 3). The host sometimes does not
#                        answer GitHub's runners (a connection timeout). A try starts over from stage, which
#                        clears the staging folder first, so repeating it is safe even after a partial one.
#   SSH_RETRY_WAIT       seconds to wait between tries (default 20)
#   DRY_RUN=1            print what would be done and stop.
set -euo pipefail

fail() { echo "error: $*" >&2; exit 1; }

OUT_DIR="${OUT_DIR:-out}"
: "${SSH_HOST:?}" "${SSH_USER:?}"
SSH_PORT="${SSH_PORT:-22}"
SSH_COMMAND="${SSH_COMMAND:-bin/forge-templates-receive}"
DRY_RUN="${DRY_RUN:-0}"
SSH_TRIES="${SSH_TRIES:-3}"
SSH_RETRY_WAIT="${SSH_RETRY_WAIT:-20}"

[[ "$SSH_PORT" =~ ^[0-9]+$ ]] || fail "SSH_PORT must be a number"
[[ "$SSH_TRIES" =~ ^[1-9][0-9]*$ ]] || fail "SSH_TRIES must be a positive number"
[[ "$SSH_RETRY_WAIT" =~ ^[0-9]+$ ]] || fail "SSH_RETRY_WAIT must be a number"
[[ "$SSH_HOST" =~ ^[A-Za-z0-9._-]+$ ]] || fail "SSH_HOST has odd characters"
[[ "$SSH_USER" =~ ^[A-Za-z0-9._-]+$ ]] || fail "SSH_USER has odd characters"
[[ "$SSH_COMMAND" =~ ^[A-Za-z0-9._/-]+$ ]] || fail "SSH_COMMAND has odd characters"
[[ "${SSH_MACS:-}" =~ ^[A-Za-z0-9,@.-]*$ ]] || fail "SSH_MACS has odd characters"

[ -f "$OUT_DIR/index.json" ] || fail "$OUT_DIR/index.json is missing: build first"
shopt -s nullglob
archives=()
for f in "$OUT_DIR"/*.tar.gz; do archives+=("$(basename "$f")"); done
[ "${#archives[@]}" -gt 0 ] || fail "no archives in $OUT_DIR"
for name in "${archives[@]}"; do
  [[ "$name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || fail "odd file name: $name"
done

if [ "$DRY_RUN" = "1" ]; then
  echo "dry run: would connect to $SSH_USER@$SSH_HOST:$SSH_PORT, run '$SSH_COMMAND stage' with ${#archives[@]} archives and index.json, then '$SSH_COMMAND finish'"
  exit 0
fi

[ -f "${SSH_KEY_FILE:-}" ] || fail "SSH_KEY_FILE is not a file"
[ -s "${SSH_KNOWN_HOSTS_FILE:-}" ] || fail "SSH_KNOWN_HOSTS_FILE is empty: pin the server's host key, do not trust on first use"

ssh_opts=(-i "$SSH_KEY_FILE" -p "$SSH_PORT" -o BatchMode=yes -o IdentitiesOnly=yes -o ConnectTimeout=30
  -o ServerAliveInterval=15 -o StrictHostKeyChecking=yes -o UserKnownHostsFile="$SSH_KNOWN_HOSTS_FILE")
[ -z "${SSH_MACS:-}" ] || ssh_opts+=(-o "MACs=$SSH_MACS")

upload_once() {
  tar cf - -C "$OUT_DIR" "${archives[@]}" index.json | ssh "${ssh_opts[@]}" "$SSH_USER@$SSH_HOST" "$SSH_COMMAND stage" || return 1
  echo "staged; moving into place (archives first, index.json last)"
  ssh "${ssh_opts[@]}" "$SSH_USER@$SSH_HOST" "$SSH_COMMAND finish"
}

echo "sending ${#archives[@]} archives and index.json to $SSH_USER@$SSH_HOST"
try=1
until upload_once; do
  if [ "$try" -ge "$SSH_TRIES" ]; then
    fail "the upload failed $SSH_TRIES times; the files already live are unchanged unless the last step got as far as moving them"
  fi
  echo "try $try of $SSH_TRIES failed; waiting $SSH_RETRY_WAIT s and starting again from the staging step"
  sleep "$SSH_RETRY_WAIT"
  try=$((try + 1))
done
echo "upload finished"
