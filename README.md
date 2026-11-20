# Forge.Scaffold.Templates

Template data for the Forge scaffolding engine ([Forge.Scaffold.SDK](../Forge.Scaffold.SDK)): captures of SharePoint
Framework generator output, the generator folders made from them, the artwork that replaces Microsoft's images, the
schemas, and the scripts that connect them.

This file says where everything comes from. The licences are in [LICENSING.md](LICENSING.md). Statements below that were
checked say so; things nobody has checked are listed at the end, not hidden.

## What is here and where it comes from

| Path | What it is | Where it comes from |
|---|---|---|
| `generators/spfx-webpart/<version>/` | raw output of `yo @microsoft/generator-sharepoint` for SPFx 1.20.0, 1.21.1, 1.22.2, 1.23.0, 1.23.2 | Microsoft's generator, run by the repo owner. See [the captures](#the-yo-captures). |
| `templates/spfxv.<version>/` | the captures turned into generator folders (`manifest.json`, `solution/`, `webpart/`) | made from the captures by `tools/make_generator.py`. See [the generator folders](#the-generator-folders). |
| `layers/assets/common/` | the Forge logo, a resized welcome image, the two Teams icons | the repo owner's artwork. See [the artwork](#the-artwork). |
| `layers/overlay.json` | tells the release builder which Microsoft images to replace with that artwork | written for this repo |
| `Manifest.v1.json`, `pack.v1.json` | JSON Schemas for generator manifests and packs | written for this repo |
| `spfx-1.23.2-r1.pack.json` | a hand-written sample pack | written for this repo. It does not load: its `base/assets/icon.png` is a truncated placeholder. |
| `tools/` | `make_generator.py`, `make_teams_icons.py`, `make_welcome_image.py`, and `publish_build.sh`, `publish_verify.py` for publishing | written for this repo |
| `.github/workflows/publish.yml` | a workflow that builds the archives and index and uploads them over FTPS, by hand only | written for this repo; it has built and published once (20 November 2026), after one re-run for a connection timeout |
| `CurrentVersions.md`, `DirectoryTress.ps1`, `PerposedTemplateStructure.json`, `tree.json` | working notes and helper files | written by the repo owner |
| `generators/backend-api`, `fullstack`, `vite-react` | empty folders, planned generators | nothing yet |

**The official SPFx templates are not stored here.** The SDK's release builder reads them from a checkout of
[SharePoint/spfx](https://github.com/SharePoint/spfx) and puts a `NOTICE.txt` with Microsoft's MIT notice in every archive. The
checkout used so far is the repo owner's fork `mentenaz/spfx` at commit `c2fd2f5` ("Bump package versions (#242)", 2026-11-03),
whose root `LICENSE` says the projects in the monorepo are MIT licensed, Copyright (c) Microsoft Corporation.

## The yo captures

Each folder is what `@microsoft/generator-sharepoint` wrote when run with placeholder names (no real project, no work code).
`.yo-rc.json` in each folder records the versions, and `CurrentVersions.md` records the Node version and the Node range of each
generator line:

| Folder | SPFx / generator | Node it was run under | Build | Solution name used |
|---|---|---|---|---|
| `1.20.0` | 1.20.0 | 18.20.8 | gulp | `Template` |
| `1.21.1` | 1.21.1 | 22.21.1 | gulp | `Template` |
| `1.22.2` | 1.22.2 | 22.22.0 | heft | `Template` |
| `1.23.0` | 1.23.0 | 22.22.3 | heft | `1-23-0` |
| `1.23.2` | 1.23.2 | 22.23.0 | heft | `1-23-2` |

Only git-tracked files are used. Build output (`node_modules`, `lib`, `lib-commonjs`, `temp`) may be on disk, but it is not tracked in git and never enters
the generators or the archives. The captures' `package-lock.json` files are
tracked; they list third-party npm packages and versions, each under its own licence.

**These captures are not pristine.** A clean `yo` run was measured (see `spfx-add-findings.md` in the SDK repo) and never
contains a `fast-serve/` folder or a `Types/` folder. These captures do, and have other additions:

| Capture | Not part of a clean `yo` run (checked by looking at the files) |
|---|---|
| 1.20.0 | `fast-serve/` |
| 1.21.1 | `fast-serve/`, `src/Types/`, `tsconfig.json` paths for `Types` |
| 1.22.2 | `src/Types/`, `tsconfig.json` paths for `Types` |
| 1.23.0 | `src/Types/`, `tsconfig.json` paths for `Types` |
| 1.23.2 | `src/Types/`, `tsconfig.json` paths for `Types`, `DemoComponent.tsx`, and the dependencies `react-hook-form`, `zod`, `@hookform/resolvers` |

The `Types/`, `DemoComponent.tsx` and form-library additions were made after generation: they are not Microsoft's generator
output. Which of the other files differ from a clean run has not been checked file by file (for example `src/custom.d.ts`,
which declares PNG imports, may or may not be part of a clean run).

All five generators were scaffolded, installed, built and packaged for real (1.20.0 under Node 18.20.8, the others under Node
22.23.0); the results are in `docs/spfx-generator-findings.md` of the SDK repo.

## The generator folders

`tools/make_generator.py <version>` turns a capture into `templates/spfxv.<version>/`. It:

- reads git-tracked files only, and leaves out `package-lock.json` and generated `*.scss.ts` files;
- puts everything that belongs to the one web part in the capture (`src/webparts/template`, its `Types`, its Teams icons) into
  `webpart/`, expanded once per web part name, and everything else into `solution/`;
- replaces the values of the capture (solution name, library id, feature id, web part id, description) with `{__token__}`s read
  from the capture itself, and writes a `manifest.json`;
- empties `bundles` and `localizedResources` in `config/config.json`, which the manifest fills per web part;
- drops the shared `src/Types/index.ts` barrel and points each web part at its own type files, so several web parts can coexist;
- replaces `welcome-dark.png`, `welcome-light.png` and the two Teams icons with the files in `layers/assets/common/`, so none of
  Microsoft's images are in the generators.

The code, configuration and structure around those images still derive from the generator output.

## The artwork

`layers/assets/common/` holds files the repo owner supplied and processed with the scripts in `tools/`:

- `forge-logo.png`: the original, copied unchanged from the owner's `Forge_Super_Watermark.png`.
- `forge-logo-welcome.png`: the same logo cropped to the visible area, 300 px on the long side, 256-colour palette
  (`tools/make_welcome_image.py`).
- `teams-color-192.png`, `teams-outline-32.png`: cut out of the owner's icon sheet `Mentenaz Forge Icon Set.png`, which has a
  checkerboard painted into the picture, so the cut-out is done by the script (`tools/make_teams_icons.py`).

They are not licensed for reuse by this repo (see `LICENSING.md`). How the original artwork was created is not recorded here.

## Checked, and not checked

Checked:

- Every git-tracked file was searched for the names the repo owner asked to keep out of this repo (employer names): no match.
- The generators contain none of Microsoft's images: the only image files in `templates/` are the four per-version slots
  (two welcome images, two Teams icons), and all of them are the files from `layers/assets/common/`.

Not checked, or open:

- **The licence of the `yo` output.** Whether templates derived from `@microsoft/generator-sharepoint` output may be
  redistributed, and on what terms, is the open question in
  [SharePoint/sp-dev-docs discussion 11052](https://github.com/SharePoint/sp-dev-docs/discussions/11052). It has no answer. The
  repo owner has chosen to publish these folders while it is open. Nothing here says they are licensed or cleared.
- **Differences from a clean run** beyond those listed above (no file-by-file diff was made).
- **The SPFx repo's contribution terms and per-file headers.** Only its root `LICENSE` was read. The templates carry no
  per-file notices.
- **Third-party packages** named in the `package-lock.json` files: each has its own licence, not reviewed here.
- **How the artwork was made.**

## Publishing

`.github/workflows/publish.yml` builds the archives and `index.json` (official SPFx templates from the fork, plus the
`yo`-derived generators) and, when asked, uploads them to the downloads server over FTPS. Setup, safety and what has been
tested are in `docs/publishing.md` of the SDK repo. It has been run only on a developer machine, never on GitHub.

## Rebuilding

```powershell
python tools/make_generator.py 1.23.2 1.23.0 1.22.2 1.21.1 1.20.0   # generators from the captures
python tools/make_welcome_image.py                                   # the welcome image from forge-logo.png
python tools/make_teams_icons.py "<path to the icon sheet>"          # the Teams icons
```

The scripts need Python 3 with Pillow (and numpy for the icons). The SDK repo has the engine, the tests that scaffold every
generator here, and `docs/publishing.md` for building and hosting the archives.
