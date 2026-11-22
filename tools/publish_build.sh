#!/usr/bin/env bash
# Builds the release (the .tar.gz archives and index.json) into OUT_DIR and checks it.
# Nothing is uploaded. Used by .github/workflows/publish.yml, and runnable by hand.
#
#   SPFX_DIR=<checkout of the SPFx fork>  BASE_URL=https://downloads.example/forge-scaffold \
#   bash tools/publish_build.sh
#
# Environment:
#   SPFX_DIR            required. A checkout of SharePoint/spfx (or the fork): its templates/ folder is released.
#   BASE_URL            required. Where the archives will be served from (https). Goes into index.json.
#   SDK_DIR             the Forge.Scaffold.SDK checkout (default: ../Forge.Scaffold.SDK next to this repo).
#   OUT_DIR             where to build (default: ./out). Must be empty or not exist.
#   INCLUDE_YO          1 (default) also releases the yo-derived generator folders (templates/spfxv.*).
#                       Generators written for this repo (the other templates/*/ folders with a manifest.json) are always released.
#   VITE_DIR            optional. A checkout of the Vite repo (or the fork): packages/create-vite is released as
#                       the generators vite-<template>. Empty (default) releases no Vite templates.
#   VITE_TEMPLATES      which create-vite templates to release, separated by spaces or commas (default: all but qwik and
#                       qwik-ts, which do not npm install). Only used with VITE_DIR.
#   PREVIOUS_INDEX_FILE optional. A copy of the index published last time that was read over ssh (see tools/fetch_index_ssh.sh).
#                       It is used instead of the download when it is there, and is checked the same way.
#   PREVIOUS_INDEX_URL  the index published last time, so unchanged archives keep their revision.
#                       Default BASE_URL/index.json. A 404 means "first publish". Set to empty to skip.
#   PYTHON              default python3.
set -euo pipefail

fail() { echo "error: $*" >&2; exit 1; }

: "${SPFX_DIR:?set SPFX_DIR to a checkout of the SPFx repo}"
: "${BASE_URL:?set BASE_URL to the public https URL the archives are served from}"
case "$BASE_URL" in https://*) ;; *) fail "BASE_URL must start with https://" ;; esac

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="${TEMPLATES_DIR:-$(cd "$HERE/.." && pwd)}"
SDK_DIR="${SDK_DIR:-$TEMPLATES_DIR/../Forge.Scaffold.SDK}"
OUT_DIR="${OUT_DIR:-$TEMPLATES_DIR/out}"
INCLUDE_YO="${INCLUDE_YO:-1}"
PYTHON="${PYTHON:-python3}"
PREVIOUS_INDEX_URL="${PREVIOUS_INDEX_URL-${BASE_URL%/}/index.json}"

[ -d "$SPFX_DIR/templates" ] || fail "$SPFX_DIR/templates is not a folder: is SPFX_DIR a checkout of the SPFx repo?"
[ -f "$SPFX_DIR/LICENSE" ] || fail "$SPFX_DIR/LICENSE is missing; the MIT notice has to travel with the templates"
[ -f "$SDK_DIR/Cargo.toml" ] || fail "$SDK_DIR is not the Forge.Scaffold.SDK checkout"

absolute() { (cd "$1" && pwd); }
# Native Windows tools (cargo, python) do not understand /e/... paths from Git Bash.
native() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }

mkdir -p "$OUT_DIR"
OUT_DIR="$(absolute "$OUT_DIR")"
[ -z "$(ls -A "$OUT_DIR")" ] || fail "$OUT_DIR is not empty; build into a fresh folder"
SPFX_DIR="$(absolute "$SPFX_DIR")"
SDK_DIR="$(absolute "$SDK_DIR")"
VITE_DIR="${VITE_DIR:-}"
VITE_TEMPLATES="${VITE_TEMPLATES:-react-ts vue-ts vanilla-ts svelte-ts solid-ts preact-ts lit-ts react vue vanilla preact lit solid svelte}"
if [ -n "$VITE_DIR" ]; then
  [ -f "$VITE_DIR/packages/create-vite/package.json" ] || fail "$VITE_DIR/packages/create-vite/package.json is missing: is VITE_DIR a checkout of the Vite repo?"
  [ -f "$VITE_DIR/packages/create-vite/LICENSE" ] || fail "$VITE_DIR/packages/create-vite/LICENSE is missing; the MIT notice has to travel with the templates"
  VITE_DIR="$(absolute "$VITE_DIR")"
fi

# ---- the previous index: it decides which archives keep their revision
PREV_COPY=""
if [ -n "${PREVIOUS_INDEX_FILE:-}" ] && [ -s "$PREVIOUS_INDEX_FILE" ]; then
  # Read over ssh by the job before this one, from the server itself. It has to be an index to be used.
  if "$PYTHON" -c 'import json,sys; d=json.load(open(sys.argv[1],encoding="utf-8")); assert d.get("schema")==1 and d.get("templates")' "$PREVIOUS_INDEX_FILE" 2>/dev/null; then
    cp "$PREVIOUS_INDEX_FILE" "$OUT_DIR/index.json"
    PREV_COPY="$(mktemp)"
    cp "$PREVIOUS_INDEX_FILE" "$PREV_COPY"
    echo "previous index: read over ssh from the server"
  else
    echo "the index read over ssh is not valid; downloading it instead"
  fi
fi
if [ -z "$PREV_COPY" ] && [ -n "$PREVIOUS_INDEX_URL" ]; then
  # The host sometimes does not answer GitHub's runners, so fail each try fast (15 s to connect) and
  # try again for a few minutes instead of hanging for ten.
  code="$(curl -sS -L --connect-timeout 15 --max-time 60 --retry 6 --retry-delay 20 --retry-all-errors \
    -o "$OUT_DIR/index.json" -w '%{http_code}' "$PREVIOUS_INDEX_URL")"
  case "$code" in
    200)
      PREV_COPY="$(mktemp)"
      cp "$OUT_DIR/index.json" "$PREV_COPY"
      echo "previous index: $PREVIOUS_INDEX_URL"
      ;;
    404)
      rm -f "$OUT_DIR/index.json"
      echo "no previous index at $PREVIOUS_INDEX_URL (404): this is the first publish"
      ;;
    *)
      rm -f "$OUT_DIR/index.json"
      fail "could not read the previous index ($code from $PREVIOUS_INDEX_URL). Refusing to guess the revisions."
      ;;
  esac
fi

# ---- what to release
args=(--overlay "$(native "$TEMPLATES_DIR/layers")")
count=0
for dir in "$SPFX_DIR"/templates/*/; do
  [ -f "${dir}template.json" ] || continue
  args+=(--upstream "$(native "$SPFX_DIR")" "$(basename "$dir")")
  count=$((count + 1))
done
[ "$count" -gt 0 ] || fail "no templates (folders with a template.json) found in $SPFX_DIR/templates"
echo "official templates: $count"

if [ -n "$VITE_DIR" ]; then
  vite=0
  for t in ${VITE_TEMPLATES//,/ }; do
    [[ "$t" =~ ^[a-z0-9-]+$ ]] || fail "odd create-vite template name: $t"
    [ -d "$VITE_DIR/packages/create-vite/template-$t" ] || fail "no create-vite template named $t in $VITE_DIR/packages/create-vite"
    args+=(--create-vite "$(native "$VITE_DIR")" "$t")
    vite=$((vite + 1))
  done
  [ "$vite" -gt 0 ] || fail "VITE_DIR is set but VITE_TEMPLATES names no template"
  echo "create-vite templates: $vite"
fi

if [ "$INCLUDE_YO" = "1" ]; then
  yo=0
  for dir in "$TEMPLATES_DIR"/templates/spfxv.*/; do
    [ -f "${dir}manifest.json" ] || continue
    args+=("$(native "${dir%/}")")
    yo=$((yo + 1))
  done
  echo "yo-derived generators: $yo"
fi

# Generators written for this repo (templates/<name>/manifest.json, for example backend-api and fullstack). They are always
# released; the yo-derived ones above live in templates/spfxv.* and are skipped here.
own=0
for dir in "$TEMPLATES_DIR"/templates/*/; do
  case "$(basename "$dir")" in spfxv.*) continue ;; esac
  [ -f "${dir}manifest.json" ] || continue
  args+=("$(native "${dir%/}")")
  own=$((own + 1))
done
echo "own generators: $own"

# ---- build
cargo run --release --quiet --manifest-path "$(native "$SDK_DIR")/Cargo.toml" --example release -- \
  "$(native "$OUT_DIR")" "$BASE_URL" "${args[@]}"

# ---- check what was built before anything can be uploaded
OUT_DIR_N="$(native "$OUT_DIR")" SPFX_DIR_N="$(native "$SPFX_DIR")" BASE_URL="$BASE_URL" \
PREV_COPY_N="${PREV_COPY:+$(native "$PREV_COPY")}" "$PYTHON" - <<'PYEOF'
import hashlib, json, os, sys, tarfile

out = os.environ["OUT_DIR_N"]
spfx = os.environ["SPFX_DIR_N"]
base = os.environ["BASE_URL"].rstrip("/")
prev_path = os.environ.get("PREV_COPY_N", "")
MAX_ARCHIVE = 25 * 1024 * 1024          # the limit the engine's index applies

problems = []
index = json.load(open(os.path.join(out, "index.json"), encoding="utf-8"))
if index.get("schema") != 1:
    problems.append(f"index schema is {index.get('schema')}, expected 1")
entries = index.get("templates", [])
if not entries:
    problems.append("the index lists no templates")

previous = {}
if prev_path and os.path.isfile(prev_path):
    for e in json.load(open(prev_path, encoding="utf-8")).get("templates", []):
        previous[(e["generator"], e["version"])] = e

# the names of the official templates, from their template.json
official = set()
for name in os.listdir(os.path.join(spfx, "templates")):
    tj = os.path.join(spfx, "templates", name, "template.json")
    if os.path.isfile(tj):
        official.add(json.load(open(tj, encoding="utf-8"))["name"])

listed, rows = set(), []
for e in entries:
    fname = e["dir"] + ".tar.gz"
    listed.add(fname)
    path = os.path.join(out, fname)
    if not os.path.isfile(path):
        problems.append(f"{fname}: listed in the index but not built")
        continue
    data = open(path, "rb").read()
    if hashlib.sha256(data).hexdigest() != e["sha256"]:
        problems.append(f"{fname}: sha256 does not match the index")
    if len(data) != e["size"]:
        problems.append(f"{fname}: size {len(data)} does not match the index ({e['size']})")
    if len(data) > MAX_ARCHIVE:
        problems.append(f"{fname}: larger than {MAX_ARCHIVE} bytes")
    if e["url"] != f"{base}/{fname}":
        problems.append(f"{fname}: url is {e['url']}, expected {base}/{fname}")
    if e.get("revision", 0) < 1:
        problems.append(f"{fname}: revision {e.get('revision')}")

    with tarfile.open(path) as t:
        names = t.getnames()
        if any(part in (".git", "node_modules") for n in names for part in n.split("/")):
            problems.append(f"{fname}: contains .git or node_modules")
        if f"{e['dir']}/manifest.json" not in names:
            problems.append(f"{fname}: has no manifest.json")
        # the MIT licence requires Microsoft's notice to travel with an official template
        if e["generator"] in official:
            member = f"{e['dir']}/NOTICE.txt"
            if member not in names:
                problems.append(f"{fname}: an official template without NOTICE.txt")
            elif b"Copyright (c) Microsoft Corporation" not in t.extractfile(member).read():
                problems.append(f"{fname}: NOTICE.txt has no Microsoft copyright line")
        # the same for a create-vite template: its MIT notice travels with it
        if e["generator"].startswith("vite-"):
            member = f"{e['dir']}/NOTICE.txt"
            if member not in names:
                problems.append(f"{fname}: a create-vite template without NOTICE.txt")
            elif b"VoidZero Inc. and Vite contributors" not in t.extractfile(member).read():
                problems.append(f"{fname}: NOTICE.txt has no Vite copyright line")

    old = previous.get((e["generator"], e["version"]))
    state = "new" if old is None else ("unchanged" if old["sha256"] == e["sha256"] else "CHANGED")
    rows.append((e["generator"], e["version"], e["revision"], len(data), state))

for f in sorted(os.listdir(out)):
    if f.endswith(".tar.gz") and f not in listed:
        problems.append(f"{f}: built but not in the index")
dropped = sorted(set(previous) - {(e["generator"], e["version"]) for e in entries})

width = max((len(r[0]) for r in rows), default=10)
lines = [f"{'template':<{width}}  version  rev   bytes  vs published"]
for g, v, rev, size, state in sorted(rows):
    lines.append(f"{g:<{width}}  {v:<7}  {rev:<3} {size:>7}  {state}")
print("\n".join(lines))
if dropped:
    print("\nnot in this release any more (their files stay on the server):", ", ".join(f"{g} {v}" for g, v in dropped))

summary = os.environ.get("GITHUB_STEP_SUMMARY")
if summary:
    with open(summary, "a", encoding="utf-8") as s:
        s.write("### Release built\n\n| template | version | revision | bytes | vs published |\n|---|---|---|---|---|\n")
        for g, v, rev, size, state in sorted(rows):
            s.write(f"| {g} | {v} | {rev} | {size} | {state} |\n")
        if problems:
            s.write("\n**Problems**\n\n" + "\n".join(f"- {p}" for p in problems) + "\n")

if problems:
    print("\nPROBLEMS:", file=sys.stderr)
    for p in problems:
        print(f"  - {p}", file=sys.stderr)
    sys.exit(1)
print(f"\nok: {len(rows)} archives, all checked")
PYEOF
