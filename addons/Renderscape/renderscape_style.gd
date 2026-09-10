## Shared visual constants for the Renderscape dock.
class_name RenderscapeStyle
extends RefCounted

const TITLE_COLOR := Color(0.5, 0.8, 1.0, 1.0)
const ACCENT_COLOR := Color(0.15, 0.35, 0.75, 1.0)      # active chip / active view-toggle button
const INACTIVE_COLOR := Color(0.12, 0.12, 0.12, 1.0)    # inactive chip / inactive view-toggle button
const NEW_ASSET_COLOR := Color.GREEN
const NEW_ITEM_HIGHLIGHT := Color(0.012, 0.293, 0.722, 1.0)
const DOWNLOADING_TEXT_COLOR := Color(0.6, 0.6, 0.6, 1.0)
const IMPORTED_TEXT_COLOR := Color(0.4, 0.8, 0.4, 1.0)

const THUMBNAIL_SIZE := Vector2(64, 64)
const GRID_ICON_SIZE := Vector2(96, 96)

const NEW_ASSET_BADGE_TEXT := "● NEW ASSETS READY"
const DOWNLOADING_SUFFIX := "  [⬇ downloading]"
const IMPORTED_SUFFIX := "  [✓ imported]"
