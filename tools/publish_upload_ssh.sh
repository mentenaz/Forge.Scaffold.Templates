#!/usr/bin/env bash
# Uploads a built release (see publish_build.sh) to the downloads server over SSH, using only ssh and tar.
#
# 1. The files travel as one tar stream into a staging folder (.incoming) inside the target folder.
#    Nothing is live yet.
# 2. A second ssh call renames each file from .incoming into place. A rename inside one folder is
#    atomic, so a client never sees a half-written file. Every archive is moved first and
#    index.json last, so an index never points at a file that is not there yet.
# 3. The staging folder is removed. Nothing else on the server is touched or deleted.
#
# Environment:
#   OUT_DIR              the built release (default ./out)
#   SSH_HOST, SSH_USER, SSH_PATH   required. SSH_PATH is the absolute folder on the server.
#   SSH_PORT             default 22
#   SSH_KEY_FILE         required (unless DRY_RUN=1). The private key of the deploy user.
#   SSH_KNOWN_HOSTS_FILE required (unless DRY_RUN=1). Holds the server's pinned host key: the
#                        host key is checked strictly, there is no "trust on first use".
#   SSH_MACS             optional. This server only accepts hmac-sha2-256.
#   DRY_RUN=1            print what would be done and stop.
set -euo pipefail

fail() { echo "error: $*" >&2; exit 1; }

OUT_DIR="${OUT_DIR:-out}"
: "${SSH_HOST:?}" "${SSH_USER:?}" "${SSH_PATH:?}"
SSH_PORT="${SSH_PORT:-22}"
DRY_RUN="${DRY_RUN:-0}"

# Names end up in a command run on the server, so keep every one to a safe alphabet.
[[ "$SSH_PATH" =~ ^/[A-Za-z0-9._/-]+$ ]] || fail "SSH_PATH must be an absolute path of letters, digits and . _ - /"
[[ "$SSH_PATH" != *..* ]] || fail "SSH_PATH must not contain .."
[ "$SSH_PATH" != "/" ] || fail "SSH_PATH must not be /"
[[ "$SSH_PORT" =~ ^[0-9]+$ ]] || fail "SSH_PORT must be a number"
[[ "$SSH_HOST" =~ ^[A-Za-z0-9._-]+$ ]] || fail "SSH_HOST has odd characters"
[[ "$SSH_USER" =~ ^[A-Za-z0-9._-]+$ ]] || fail "SSH_USER has odd characters"
[[ "${SSH_MACS:-}" =~ ^[A-Za-z0-9,@.-]*$ ]] || fail "SSH_MACS has odd characters"

[ -f "$OUT_DIR/index.json" ] || fail "$OUT_DIR/index.json is missing: build first"
shopt -s nullglob
archives=()
for f in "$OUT_DIR"/*.tar.gz; do archives+=("$(basename "$f")"); done
[ "${#archives[@]}" -gt 0 ] || fail "no archives in $OUT_DIR"
for name in "${archives[@]}"; do
  [[ "$name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || fail "odd file name: $name"
done

# What the server does after the files arrive: archives first, the index last.
remote_finish="set -e; cd $SSH_PATH/.incoming; chmod 644 ./*"
for name in "${archives[@]}"; do
  remote_finish+="; mv -f $name ../$name"
done
remote_finish+="; mv -f index.json ../index.json; cd ..; rmdir .incoming"

remote_stage="set -e; cd $SSH_PATH; rm -rf .incoming; mkdir .incoming; tar xf - -C .incoming --no-same-owner"

if [ "$DRY_RUN" = "1" ]; then
  echo "dry run: would connect to $SSH_USER@$SSH_HOST:$SSH_PORT and send ${#archives[@]} archives and index.json"
  echo "stage:  $remote_stage"
  echo "finish: $remote_finish"
  exit 0
fi

[ -f "${SSH_KEY_FILE:-}" ] || fail "SSH_KEY_FILE is not a file"
[ -s "${SSH_KNOWN_HOSTS_FILE:-}" ] || fail "SSH_KNOWN_HOSTS_FILE is empty: pin the server's host key, do not trust on first use"

ssh_opts=(-i "$SSH_KEY_FILE" -p "$SSH_PORT" -o BatchMode=yes -o IdentitiesOnly=yes -o ConnectTimeout=20
  -o ServerAliveInterval=15 -o StrictHostKeyChecking=yes -o UserKnownHostsFile="$SSH_KNOWN_HOSTS_FILE")
[ -z "${SSH_MACS:-}" ] || ssh_opts+=(-o "MACs=$SSH_MACS")

echo "sending ${#archives[@]} archives and index.json to $SSH_USER@$SSH_HOST:$SSH_PATH"
tar cf - -C "$OUT_DIR" "${archives[@]}" index.json | ssh "${ssh_opts[@]}" "$SSH_USER@$SSH_HOST" "$remote_stage"
echo "staged; moving into place (archives first, index.json last)"
ssh "${ssh_opts[@]}" "$SSH_USER@$SSH_HOST" "$remote_finish"
echo "upload finished"
