#!/usr/bin/env python3
"""Turns a raw `yo @microsoft/generator-sharepoint` capture into a generator folder.

    python tools/make_generator.py <version> [<version> ...]

Reads  generators/spfx-webpart/<version>/   (git-tracked files only, so no
                                              node_modules, lib, temp, ...)
Writes templates/spfxv.<version>/           (manifest.json + solution/ + webpart/)

Everything that belongs to the one web part in the capture (src/webparts/template,
its Types, its Teams icons) goes into `webpart/` and is expanded once per web part
name. Everything else goes into `solution/` and is copied once. The values used
when the capture was made (solution name, GUIDs, description) are read from the
capture itself and replaced by tokens.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SKIP_NAMES = {"package-lock.json"}

# The assets layer: files kept once in layers/assets/ and used instead of the
# images in the capture (which come from Microsoft's template).
ASSETS = REPO / "layers" / "assets" / "common"
WELCOME_IMAGE = ASSETS / "forge-logo-welcome.png"
REPLACED_ASSETS = {"assets/welcome-dark.png", "assets/welcome-light.png"}
TEAMS_ICONS = {"_color.png": ASSETS / "teams-color-192.png", "_outline.png": ASSETS / "teams-outline-32.png"}

WP = "{__webpartPascal__}"
WC = "{__webpartCamel__}"


def tracked(folder: Path):
    out = subprocess.run(
        ["git", "ls-files", "-z", "."], cwd=folder, capture_output=True, check=True
    ).stdout.decode()
    return [p for p in out.split("\0") if p]


def read_text(path: Path):
    try:
        return path.read_bytes().decode("utf-8")
    except UnicodeDecodeError:
        return None


def webpart_text(s: str, web_part_id: str) -> str:
    # The captures import the props from a shared `Types` barrel. With several
    # web parts that barrel would be written once per web part, so import from
    # each web part's own files instead. This runs before the token
    # replacement, while the names still read `ITemplate...`.
    def split_import(m):
        lines = []
        for name in (n.strip() for n in m.group(1).split(",")):
            name = re.sub(r"^type\s+", "", name)
            if name.endswith("WebPartProps"):
                lines.append(f'import {{ {name} }} from "Types/ITemplateWebPart/ITemplateWebPart";')
            else:
                lines.append(f'import {{ {name} }} from "Types/ITemplate/{name}";')
        return "\n".join(lines)

    s = re.sub(r'import \{([^}]*)\} from "Types";', split_import, s)
    s = s.replace("TemplateWebPart", WP + "WebPart")
    s = s.replace("Template", WP)
    s = s.replace(web_part_id, "{__webpartId__}")
    s = s.replace("styles.template", "styles." + WC)
    return re.sub(r"^\.template ", "." + WC + " ", s, flags=re.M)


def build(version: str):
    src = REPO / "generators" / "spfx-webpart" / version
    dst = REPO / "templates" / f"spfxv.{version}"
    if not src.is_dir():
        sys.exit(f"no capture for {version}: {src}")

    yo = json.loads((src / ".yo-rc.json").read_text("utf-8"))["@microsoft/generator-sharepoint"]
    pkg_sol_text = (src / "config" / "package-solution.json").read_text("utf-8")
    wp_manifest_text = (src / "src/webparts/template/TemplateWebPart.manifest.json").read_text("utf-8")
    solution_name = yo["solutionName"]
    library_name = yo.get("libraryName", solution_name)
    description = yo.get("solutionShortDescription") or f"{solution_name} description"
    solution_id = yo["libraryId"]
    # These files may carry comments, so read the ids by pattern, not as JSON.
    feature_id = re.search(r'"features"[\s\S]*?"id":\s*"([0-9a-f-]{36})"', pkg_sol_text).group(1)
    web_part_id = re.search(r'"id":\s*"([0-9a-f-]{36})"', wp_manifest_text).group(1)

    def solution_text(s: str) -> str:
        s = s.replace(solution_id, "{__solutionId__}")
        s = s.replace(feature_id, "{__featureId__}")
        s = s.replace(description, "{__solutionDescription__}")
        # The folder/package name and the display name can differ (1.20.0-1.22.2
        # captures: `template` and `Template`). Replace whole words only, and
        # never a JSON key such as `"template": "react"` in .yo-rc.json.
        for name in dict.fromkeys([library_name, solution_name]):
            s = re.sub(r'(?<![\w-])' + re.escape(name) + r'(?![\w])(?!"\s*:)', "{__solutionName__}", s)
        return s

    import shutil

    if dst.exists():
        shutil.rmtree(dst)
    (dst / "solution").mkdir(parents=True)
    (dst / "webpart").mkdir()

    def put(rel: str, where: str, data: bytes):
        target = dst / where / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)

    for rel in tracked(src):
        name = rel.rsplit("/", 1)[-1]
        if name in SKIP_NAMES or name.endswith(".scss.ts"):
            continue
        raw = (src / rel).read_bytes()
        text = raw.decode("utf-8") if read_text(src / rel) is not None else None

        if rel == "config/config.json":
            cfg = json.loads(text)
            cfg["bundles"] = {}
            cfg["localizedResources"] = {}
            put(rel, "solution", (json.dumps(cfg, indent=2) + "\n").encode())
        elif rel == "src/Types/index.ts":
            continue  # replaced by per-web-part imports
        elif rel.startswith("src/webparts/template/"):
            tail = rel[len("src/webparts/template/"):]
            out = f"src/webparts/{WC}/" + tail.replace("Template", WP)
            if tail in REPLACED_ASSETS:
                raw, text = WELCOME_IMAGE.read_bytes(), None
            put(out, "webpart", webpart_text(text, web_part_id).encode() if text is not None else raw)
        elif rel.startswith("src/Types/"):
            put(rel.replace("Template", WP), "webpart",
                webpart_text(text, web_part_id).encode() if text is not None else raw)
        elif rel.startswith("teams/") and web_part_id in rel:
            for suffix, icon in TEAMS_ICONS.items():
                if rel.endswith(suffix):
                    raw = icon.read_bytes()
            put(rel.replace(web_part_id, "{__webpartId__}"), "webpart", raw)
        else:
            put(rel, "solution", solution_text(text).encode() if text is not None else raw)

    manifest = {
        "id": "spfx-webpart",
        "version": version,
        "prompts": [
            {"key": "solutionName", "type": "text", "label": "Solution name", "rule": "solution-name"},
            {"key": "solutionDescription", "type": "text", "label": "Solution description", "default": "My SPFx solution"},
            {"key": "webparts", "type": "list", "label": "Web part names", "rule": "webpart-names"},
            {"key": "install", "type": "bool", "label": "Run install afterwards", "default": False},
        ],
        "folderFrom": "solutionName",
        "nestedMarker": ".yo-rc.json",
        "guids": ["solutionId", "featureId"],
        "include": [{"folder": "solution"}],
        "repeat": [{"over": "webparts", "as": "webpart", "folder": "webpart", "guids": ["webpartId"]}],
        "merge": [
            {
                "file": "config/config.json",
                "strategy": "json-set",
                "path": "bundles.{__webpartKebab__}-web-part",
                "per": "webparts",
                "value": {
                    "components": [
                        {
                            "entrypoint": f"./lib/webparts/{WC}/{WP}WebPart.js",
                            "manifest": f"./src/webparts/{WC}/{WP}WebPart.manifest.json",
                        }
                    ]
                },
            },
            {
                "file": "config/config.json",
                "strategy": "json-set",
                "path": f"localizedResources.{WP}WebPartStrings",
                "per": "webparts",
                "value": f"lib/webparts/{WC}/loc/{{locale}}.js",
            },
        ],
        "post": [{"action": "install", "when": {"key": "install", "equals": True}}],
        "packageManagers": {"default": "npm", "tested": ["npm"]},
    }
    # The Node the capture needs (engines.node of its package.json), so the host can check it before installing.
    engines = json.loads((src / "package.json").read_text("utf-8")).get("engines", {}).get("node")
    if engines:
        manifest["requires"] = {"node": engines}
    (dst / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", "utf-8")
    print(f"{version}: wrote {dst}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    for v in sys.argv[1:]:
        build(v)
