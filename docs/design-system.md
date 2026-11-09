# Design system

Direction: **Colorful Notebook**. Clean off-white paper with cool blue-tinted surfaces, ruled-line dividers, rounded friendly shapes, a little expressiveness in headlines and empty states, and dense readable rows. No dashboard look, no decoration for its own sake. Tokens live in code as `ColorScheme` plus one `ThemeExtension` (store palette, spacing, success colours); widgets never hard-code values.

## 3.1 Colour tokens

Both schemes are written out explicitly rather than generated from a seed, to keep the brand colours exact. Brand inputs: deep blue #334E8C, periwinkle #A5BDF4, coral #F67583, mint #A5D5B6, off-white #FFFDF5.

| Role | Light | Dark |
| --- | --- | --- |
| background, surface | #FFFDF5 | #14171F |
| surfaceContainerLowest | #FFFFFF | #0F1218 |
| surfaceContainerLow | #F7F9FE | #191D26 |
| surfaceContainer | #F0F4FC | #1D212C |
| surfaceContainerHigh | #E6ECF8 | #262B38 |
| onSurface | #1E2230 | #E8E9F0 |
| onSurfaceVariant | #4D5368 | #B4B8C8 |
| outline | #7B8094 | #8A8FA3 |
| outlineVariant (ruled lines) | #D8DFEE | #3A3F4E |
| primary / onPrimary | #334E8C / #FFFFFF | #A5BDF4 / #14264F |
| primaryContainer / on | #DDE6FC / #14264F | #334E8C / #DDE6FC |
| secondary / onSecondary | #A5BDF4 / #1B2C55 | #B9C6E8 / #1B2C55 |
| secondaryContainer / on (nav indicator) | #C9D8F9 / #1B2C55 | #3A4A78 / #DCE5FB |
| tertiary (coral, FAB) / on | #F67583 / #3A0910 | #FF9AA4 / #3A0910 |
| tertiaryContainer / on | #FFD9DD / #5A1420 | #6B2230 / #FFD9DD |
| success (mint) / on | #A5D5B6 / #123B24 | #A5D5B6 / #123B24 |
| successContainer / on | #D9EEE0 / #123B24 | #1F4A33 / #D9EEE0 |
| error / onError | #B3261E / #FFFFFF | #F2B8B5 / #601410 |
| errorContainer / on | #F9DEDC / #410E0B | #8C1D18 / #F9DEDC |

Usage: primary for filled buttons, checked checkboxes, links and the wordmark; coral only for the Quick add FAB and the odd accent; mint for 'finished' and success states; errorContainer behind the swipe-to-remove action. Dark mode uses lifted surfaces, never pure black, and the same hues.

**Store palette** (separate from the brand palette; decorative dot or stripe, the name is always shown):

| Key | Hex | Key | Hex |
| --- | --- | --- | --- |
| tomato | #E5604F | teal | #2BA6A0 |
| tangerine | #F2994A | sky | #4A9BE0 |
| lemon | #D9A400 | grape | #8E6CCB |
| lime | #7DB84A | bubblegum | #E96FA6 |

On Home, store cards are filled with the store colour mixed about 38% into the theme background, with normal theme text on top (verify contrast for every palette colour in both themes). Elsewhere a store shows only its dot. The same hexes serve both themes; check each against the dark surface when building.

## 3.2 Typography

Bundled static fonts (offline-first, no runtime download): **Roboto** Regular 400, Medium 500, Bold 700 for all UI text, and **DynaPuff** Bold 700 for the wordmark only. Roboto is the Android default, so Android looks unchanged and iOS gets the same typeface instead of SF. Roboto covers Latin Extended (Serbian Latin) and Cyrillic in my understanding, but I have not checked it: verify after download. DynaPuff only has to render 'ZeroCart'. Licences: DynaPuff is OFL; Roboto's licence (Apache 2.0 in my recollection) must be confirmed from the downloaded files and credited on the licences page.

| Style | Font and weight | Size / line (sp) | Use |
| --- | --- | --- | --- |
| wordmark | DynaPuff Bold | 28 / 32 | Home app bar |
| storeCount | Roboto Bold | 52 / 52 | Items-left number on Home store cards |
| displaySmall | Roboto Bold | 24 / 30 | Empty-state headlines |
| headlineSmall | Roboto Medium | 24 / 32 | Large screen titles |
| titleLarge | Roboto Medium | 20 / 28 | App bar and sheet titles, store card names (Bold) |
| titleMedium | Roboto Medium | 16 / 24 | Section headers, card titles |
| bodyLarge | Roboto Medium | 16 / 24 | Item titles, inputs |
| bodyMedium | Roboto Regular | 14 / 20 | Descriptions, secondary text |
| labelLarge | Roboto Medium | 14 / 20 | Buttons |
| labelMedium | Roboto Medium | 12 / 16 | Chips, badges, nav labels |

Purchased item titles switch to Regular with a strikethrough. All text honours the system text scale; nothing is clamped except navigation bar labels, which may cap at 1.3x.

## 3.3 Spacing and layout

Base unit 4dp; scale 4, 8, 12, 16, 24, 32, 48. Screen side padding 16. List row: minimum height 56, vertical padding 12, gap between checkbox and text 12. Every tappable target is at least 48 x 48dp. Rows never use fixed heights.

## 3.4 Shapes

Corner radii: 8 (inputs, small chips), 16 (cards, FAB), 24 (bottom sheet top corners), 28 (dialogs), full pill (chips, badges). Checkbox corners 6. Rows are separated by 1dp ruled lines in outlineVariant, the main notebook motif; list screens may show a faint left margin line in primaryContainer.

## 3.5 Elevation

Material 3 tonal surfaces, not shadows. Cards are filled (surfaceContainer) with no shadow. FAB uses the default M3 elevation. A dragged row lifts to elevation 6 with a 1.02 scale. Sheets and dialogs use surfaceContainerHigh.

## 3.6 Icons

Built-in Material icons, rounded variants, 24dp, no extra icon package. Icons that carry meaning have a text label or a semantic label.

## 3.7 Components

- **NavigationBar** with three destinations; Inbox shows a badge. **FAB** (coral) for Quick add on tab screens.
- **Filled card** for stores and lists; custom row for items (checkbox, content, handle).
- **Checkbox** M3 with rounded corners; checked fill is primary with a white check.
- **Bottom sheets** with a drag handle, scroll-safe, padded by keyboard insets; used for all forms. **AlertDialog** only for store archive with active lists and replace-all restore.
- **ChoiceChip** for store selection and colour swatches; **SegmentedButton** for the theme and the Archive segments.
- **Floating SnackBar** with an action for Undo and Open, above the bottom bar.
- Buttons: FilledButton for the main action, TextButton for secondary, no outlined buttons unless needed.

## 3.8 Component states and motion

States follow M3 state layers (hover, focus, pressed, disabled at 38% opacity). Focus rings are visible for keyboard and switch access. Purchased rows: muted colour, strikethrough, checked box; never colour alone.

| Motion | Duration | Notes |
| --- | --- | --- |
| Check toggle and chip select | 150 ms | Emphasised easing |
| Row removal collapse | 200 ms | Fade and size |
| Purchased section expand and collapse | 250 ms | Chevron rotates |
| Sheets and dialogs | 250 ms | Platform defaults |

When the system asks to reduce motion (`MediaQuery.disableAnimations`), transitions become instant or simple fades.

## 3.9 Accessibility

- Text 4.5:1 and non-text UI 3:1 against its background in both themes; verify with a checker, including dark store tints.
- Dynamic type to at least 200% without clipped titles, overlapping rows or unreachable buttons; test it explicitly, in both English and Serbian.
- Screen readers: each item row announces title, description, and state ('Milk, 2L lactose-free, not purchased'); the checkbox has its own label. Custom accessibility actions: Move up, Move down, Remove. Removal and Undo are announced through the snackbar live region.
- Every gesture has a non-gesture path (D-22). Back navigation always works, including closing sheets.
- Colour never carries meaning alone (D-23). Haptics are light and optional (check, drag start).

## 3.10 Light and dark behaviour

The app follows the system by default and the user can force Light or Dark (SE-1). Two complete `ColorScheme`s drive all component themes. Status bar and navigation bar icon brightness follow the active theme, and the native launch screen uses the matching background colour.

## 3.11 Branding

The wordmark is the text 'ZeroCart' in DynaPuff Bold, primary colour, with a small coral dot. The idea behind the name is getting the cart to zero. App label: ZeroCart. Repository: zero-cart. Dart package: zero\_cart.

## 3.12 Home screen: store cards

Home has no list shortcuts. It is a staggered two-column board of large store cards, one per active store (the prototype shows it):

- **Fill:** the store colour mixed about 38% into the background, a solid store-colour circle clipped at the top-right corner, corner radius 28.
- **Content:** the number of unpurchased items across the store's active lists in storeCount style with the label 'left to buy'; store name in Bold 20sp; a thin progress bar (purchased share of all items); the list count. At zero the label reads 'cart is empty' (the idea of the name); a store without lists reads 'no lists yet'.
- **Layout:** the right column sits 26dp lower; every third card is taller (230dp against a 170dp minimum); cards tilt about 1 degree, alternating. Above 1.3x text scale the board becomes one column with no tilt.
- **Behaviour:** tapping a card opens store details, where the lists live. Order: most recently active store first. Accessibility label: store name, items left, list count.
- **Alternatives considered:** a horizontal swipe deck of big cards, and single-column full-width cards. Both are easy to swap in later since only the Home screen changes.
