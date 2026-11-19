#!/usr/bin/env bash
# Uploads a built release (see publish_build.sh) to the downloads server over SFTP.
#
# The order matters: every archive first, index.json last, so a client never sees an index
# that points at a file that is not there yet. Each file is uploaded under a temporary name
# and renamed into place, so a half-sent file is never served. Nothing on the server is deleted.
#
# Environment:
#   OUT_DIR              the built release (default ./out)
#   SFTP_HOST, SFTP_USER required
#   SFTP_PORT            default 22
#   SFTP_PATH            required. The folder on the server (absolute, e.g. /var/www/downloads/forge-scaffold).
#   SFTP_KEY_FILE        required (unless DRY_RUN=1). The private key of the deploy user.
#   SFTP_KNOWN_HOSTS_FILE required (unless DRY_RUN=1). Holds the server's pinned host key. The host key is
#                        checked strictly: there is no "trust on first use".
#   DRY_RUN=1            print what would be sent and stop.
set -euo pipefail

fail() { echo "error: $*" >&2; exit 1; }

OUT_DIR="${OUT_DIR:-out}"
: "${SFTP_HOST:?}" "${SFTP_USER:?}" "${SFTP_PATH:?}"
SFTP_PORT="${SFTP_PORT:-22}"
DRY_RUN="${DRY_RUN:-0}"

# The batch file is plain text, so keep every name in it to a safe alphabet.
[[ "$SFTP_PATH" =~ ^/[A-Za-z0-9._/-]+$ ]] || fail "SFTP_PATH must be an absolute path of letters, digits and . _ - /"
[ "$SFTP_PATH" != "/" ] || fail "SFTP_PATH must not be /"
[[ "$SFTP_PORT" =~ ^[0-9]+$ ]] || fail "SFTP_PORT must be a number"
[[ "$OUT_DIR" =~ ^[A-Za-z0-9._/:-]+$ ]] || fail "OUT_DIR must not contain spaces or other odd characters (it is written into the sftp batch)"
[[ "$SFTP_HOST" =~ ^[A-Za-z0-9._-]+$ ]] || fail "SFTP_HOST has odd characters"
[[ "$SFTP_USER" =~ ^[A-Za-z0-9._-]+$ ]] || fail "SFTP_USER has odd characters"

[ -f "$OUT_DIR/index.json" ] || fail "$OUT_DIR/index.json is missing: build first"
shopt -s nullglob
archives=("$OUT_DIR"/*.tar.gz)
[ "${#archives[@]}" -gt 0 ] || fail "no archives in $OUT_DIR"

batch="$(mktemp)"
trap 'rm -f "$batch"' EXIT
{
  echo "cd $SFTP_PATH"
  for f in "${archives[@]}"; do
    name="$(basename "$f")"
    [[ "$name" =~ ^[A-Za-z0-9._-]+$ ]] || fail "odd file name: $name"
    echo "put $f .$name.part"
    echo "rename .$name.part $name"
  done
  # the index goes last
  echo "put $OUT_DIR/index.json .index.json.part"
  echo "rename .index.json.part index.json"
} > "$batch"

if [ "$DRY_RUN" = "1" ]; then
  echo "dry run: would connect to $SFTP_USER@$SFTP_HOST:$SFTP_PORT and send:"
  cat "$batch"
  exit 0
fi

[ -f "${SFTP_KEY_FILE:-}" ] || fail "SFTP_KEY_FILE is not a file"
[ -s "${SFTP_KNOWN_HOSTS_FILE:-}" ] || fail "SFTP_KNOWN_HOSTS_FILE is empty: pin the server's host key, do not trust on first use"

echo "uploading ${#archives[@]} archives, then index.json, to $SFTP_USER@$SFTP_HOST:$SFTP_PATH"
# A rename over an existing file needs the server to support posix-rename (OpenSSH does). If it does
# not, this fails at that step and the old file stays in place.
sftp -b "$batch" \
  -i "$SFTP_KEY_FILE" -P "$SFTP_PORT" \
  -o BatchMode=yes -o IdentitiesOnly=yes -o ConnectTimeout=20 \
  -o StrictHostKeyChecking=yes -o UserKnownHostsFile="$SFTP_KNOWN_HOSTS_FILE" \
  "$SFTP_USER@$SFTP_HOST"
echo "upload finished"
