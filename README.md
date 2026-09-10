# Renderscape for Godot

Browse, preview, and import your purchased Renderscape 3D assets directly
inside the Godot editor — no manual downloads, no drag-and-drop from a
browser tab.

## Requirements

- Godot 4.x
- A Renderscape.io account with at least one purchased asset

## Installation

**Option A — Godot Asset Library (recommended)**

1. In Godot, open the **AssetLib** tab at the top of the editor.
2. Search for "Renderscape" and click **Download**, then **Install**.
3. Go to **Project > Project Settings > Plugins** and enable **Renderscape**.

**Option B — Manual install**

1. Download or clone this repository.
2. Copy the `addons/renderscape/` folder into your project's `addons/` directory.
3. Go to **Project > Project Settings > Plugins** and enable **Renderscape**.

## Getting started

1. Open the **Renderscape** dock (left dock panel by default).
2. Log in with your Renderscape.io email and password. Credentials are
   encrypted and stored locally so you won't need to log in again next time.
3. Click **Get My Assets** to pull your purchased assets into the panel.

## For Asset Library reviewers

This plugin requires a Renderscape.io account with at least one purchased
asset to function — it can't be evaluated without logging in. A public
test account is provided for review purposes:

- **Email:** godot@renderscape.io
- **Password:** GodotPluginTest99!

This account has sample assets already purchased, so **Get My Assets**
(see "Getting started" above) should populate the panel immediately after
logging in.

## Using the plugin

- **Search & filter** — use the search box and category chips to narrow
  down your library.
- **Sort & view** — switch between newest-first or A→Z, and toggle between
  list and grid view.
- **Quality tiers** — pick Production (High), Medium, or Low Poly before
  downloading an asset; each tier is downloaded and cached separately.
- **Import** — double-click an asset (or right-click → **Import**) to
  download it into `res://renderscape_assets/`. Once downloaded, drag the
  asset directly from the panel into your 2D/3D viewport to place it.
- **New assets** — the panel checks for new purchases automatically and
  flags them so you know what's fresh.

## Troubleshooting

- **Login fails** — double-check your email/password on renderscape.io
  directly; the plugin uses the same account.
- **Download fails** — confirm the asset shows as purchased on your
  renderscape.io account page.
- **Import issues** — make sure you're on the latest version of the plugin,
  as asset formats are occasionally updated for compatibility.

## Support

Questions or issues? Reach out at [admin@renderscape.io](mailto:admin@renderscape.io)
or open an issue on this repository.

## License

The plugin source code in this repository is MIT licensed — see
[`LICENSE`](./LICENSE). Assets downloaded through the plugin remain subject
to Renderscape's [Terms of Use](https://www.renderscape.io).
