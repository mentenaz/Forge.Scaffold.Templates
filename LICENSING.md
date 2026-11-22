# Licensing

This is a plain description of what is covered by which licence. It is not legal advice.

## Covered by `MIT OR Apache-2.0` (`LICENSE-MIT`, `LICENSE-APACHE`)

Files written for this repo, which belong to the repo owner:

- `tools/` (the scripts that make generator folders, packs and icons)
- `Manifest.v1.json`, `pack.v1.json` and the other schemas and notes
- every `manifest.json` under `templates/`
- the files that were added or changed on top of the generator output, such as `DemoComponent.tsx` and the
  `react-hook-form` / `zod` additions in the 1.23.2 template

## Not covered

- **Microsoft-derived content.** `generators/spfx-webpart/<version>/` is the raw output of
  `@microsoft/generator-sharepoint`, and `templates/spfxv.<version>/` is that output turned into tokenised templates.
  The licence on this repo does not license Microsoft's content: the repo owner cannot grant rights to it. Whether
  templates derived from the generator output may be redistributed, and under what terms, is the open question in
  [SharePoint/sp-dev-docs discussion 11052](https://github.com/SharePoint/sp-dev-docs/discussions/11052).
  The repo owner has chosen to publish these folders while that question is open, so treat them as having no licence grant from this repo. The welcome images and Teams icons are no longer Microsoft's
  (they were replaced), but the code and configuration around them still derive from the generator output.
  **In short:** these templates were built from the `yo` generator and then modified (tokens, a rewritten component, added
  files, replaced images). The modifications are the repo owner's; the generator-derived rest is not, and the replaced
  images do not change that. Files that still name Microsoft (links to its documentation, JSON-schema URLs the build tools
  use) are left as they are.
- **Branding.** The Mentenaz Forge name, logo and the artwork in `layers/assets/common/` are brand assets, not offered under
  `MIT OR Apache-2.0`. They are the same artwork as in the Forge Super repository, whose
  [`BRANDING.md`](https://github.com/mentenaz/mentenaz.Forge.Super/blob/main/BRANDING.md) says what may be done with it.
  The text files in `layers/vite/` were written for this repo and are covered by the licence above.
  **Projects made from these templates:** the Forge favicon and the Forge image that some of the templates put in a project
  (for example the Vite React template's `public/favicon.svg` and `src/assets/hero.png`) may be kept, changed or removed by
  whoever makes the project; the project is theirs. That is a permission for those copies in that project, not a licence for
  the artwork in general: the name and logo may not be used to suggest that something else is Mentenaz Forge or endorsed by it.

## Official SharePoint/spfx templates

The release builder in the Forge.Scaffold.SDK repo can also build archives from the templates of
[SharePoint/spfx](https://github.com/SharePoint/spfx). Those are Microsoft's, licensed MIT (its root `LICENSE`: "The projects
in this monorepo are licensed under the MIT license", Copyright (c) Microsoft Corporation). Nothing of them is stored in this
repo. Every archive built from them carries a `NOTICE.txt` with Microsoft's copyright and licence text, as the MIT licence
requires, and says which images were replaced by the files in `layers/`. The contribution terms and individual file headers
of that repo have not been read.

## Packages installed by the user

Generated projects install `@microsoft/sp-*` and other packages from npm on the user's machine. None of them is
redistributed from this repo, and each keeps its own licence.
