# Design prototype

`shopping-app-prototype.html` is a self-contained, mobile-first HTML prototype of ZeroCart. Open it directly in a browser; no build step. It uses in-memory sample data, so a reload resets everything.

## What it is for

It shows intended layout, flow and behaviour for the Flutter UI. Token values are defined in `docs/design-system.md`, which wins over the prototype where they differ. Business rules are defined in `docs/product-requirements.md` and `docs/data-model.md`.

## Using it

- Bottom tabs: Home, Inbox, Stores. The + button adds to the Inbox. Settings is the gear on Home.
- Mouse alternatives for touch gestures: drag the handle (or focus it and press Up/Down) to reorder; on touch, swipe left to remove; on desktop use Remove in the edit sheet. Removal shows Undo for 5 seconds.
- Sample stores: Lidl and DM, with lists Weekend groceries, Party, Next week, Drugstore run and an archived Easter list.
- Theme switching is in Settings (System, Light, Dark).

## Not in the prototype

Inbox multi-select and batch assignment (D-16), backup export and import (stubbed), Serbian strings, haptics, text-scale testing, and the exact Flutter motion. Fonts load from Google Fonts online and fall back to system fonts offline; the app bundles its own copies.
