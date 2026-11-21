#!/usr/bin/env bash
# forge-templates-receive: the only thing the templates deploy key is allowed to do on the server.
#
# Install it as ~/bin/forge-templates-receive (mode 755) and, once it works, tie the key to it in
# ~/.ssh/authorized_keys:   command="/home/mentefpu/bin/forge-templates-receive",restrict ssh-ed25519 AAAA...
# After that the key can run these three commands and nothing else (no shell, no other path):
#
#   forge-templates-receive stage    reads a tar stream on stdin into <folder>/.incoming (at most 200 MB)
#   forge-templates-receive finish   moves .incoming/*.tar.gz into the folder, then index.json last,
#                                    then removes .incoming. Every move is an atomic rename.
#   forge-templates-receive check    prints the folder and what it can do, and writes and removes one probe file
#
# Without the forced command (before it is switched on) the client calls this script by its path and the
# arguments arrive normally. With it, ssh puts what the client asked for in SSH_ORIGINAL_COMMAND and
# this script uses the words after the program name, so the same client works both ways.
set -euo pipefail

DIR="${FORGE_TEMPLATES_DIR:-/home/mentefpu/downloads.mentenaz-server.com/forge-scaffold}"
MAX_BYTES=209715200
NAME_OK='^[A-Za-z0-9][A-Za-z0-9._-]*$'

die() { echo "forge-templates-receive: $*" >&2; exit 1; }

if [ -n "${SSH_ORIGINAL_COMMAND:-}" ]; then
  read -r -a words <<<"$SSH_ORIGINAL_COMMAND"
  set -- "${words[@]:1}"
fi
[ "$#" -eq 1 ] || die "usage: forge-templates-receive stage|finish|check"

[ -d "$DIR" ] || die "the templates folder does not exist"
cd "$DIR"
shopt -s nullglob dotglob

case "$1" in
  stage)
    rm -rf .incoming
    mkdir .incoming
    # --no-same-owner: the files belong to this account. head caps what a client can send.
    head -c "$MAX_BYTES" | tar xf - -C .incoming --no-same-owner || { rm -rf .incoming; die "tar failed"; }
    # Only plain files with plain names directly in .incoming: archives and index.json.
    for f in .incoming/*; do
      name="${f#.incoming/}"
      if [ ! -f "$f" ] || [ -L "$f" ] || ! [[ "$name" =~ $NAME_OK ]]; then
        rm -rf .incoming
        die "refusing an unexpected entry in the upload: $name"
      fi
      case "$name" in
        index.json | *.tar.gz) ;;
        *) rm -rf .incoming; die "refusing an unexpected file in the upload: $name" ;;
      esac
    done
    echo "staged $(printf '%s\n' .incoming/* | wc -l) files"
    ;;

  finish)
    [ -d .incoming ] || die "nothing is staged"
    [ -f .incoming/index.json ] || die "the staged upload has no index.json"
    archives=(.incoming/*.tar.gz)
    [ "${#archives[@]}" -gt 0 ] || die "the staged upload has no archives"
    for f in .incoming/*; do
      name="${f#.incoming/}"
      case "$name" in index.json | *.tar.gz) ;; *) die "unexpected staged file: $name" ;; esac
    done
    chmod 644 .incoming/*
    # archives first, so an index never points at a file that is not there yet
    for f in "${archives[@]}"; do
      mv -f "$f" "./${f#.incoming/}"
    done
    mv -f .incoming/index.json ./index.json
    rmdir .incoming
    echo "moved ${#archives[@]} archives and index.json into place"
    ;;

  check)
    pwd
    command -v tar
    ls -l | head -n 40
    mkdir .incoming-check
    echo ok > .incoming-check/probe
    mv -f .incoming-check/probe .incoming-check/probe2
    rm -r .incoming-check
    echo "write, rename and remove all work"
    ;;

  *) die "unknown command (use stage, finish or check)" ;;
esac
