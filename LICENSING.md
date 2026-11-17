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
- **Branding.** The Mentenaz Forge logo and the icons in `layers/assets/common/` are not licensed for reuse by this
  file. (Change this line if you want them covered.)

## Packages installed by the user

Generated projects install `@microsoft/sp-*` and other packages from npm on the user's machine. None of them is
redistributed from this repo, and each keeps its own licence.
