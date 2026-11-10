# SmoeBag

A modular one-bag inventory addon for World of Warcraft. SmoeBag combines carried bags in one window, dims items that do not match a search, and provides adjustable columns, slot size and spacing.

## Features

- One inventory window with bag-toggle integration and a bag selector.
- Search by item name, type and subtype.
- Drag-to-resize preview and an options panel with Apply/Cancel.
- Sorting in two stages: merge partial stacks, then reorder items by priority.
- Item quality and quest indicators, plus money and honor in the footer.
- Adapters for modern `C_Container` and legacy container APIs.

## Install and use

Download the repository, rename the extracted folder **SmoeBag**, and place it in the `Interface/AddOns/` directory of the WoW client you use. The final layout must contain:

```text
Interface/AddOns/SmoeBag/SmoeBag.toc
Interface/AddOns/SmoeBag/config.lua
Interface/AddOns/SmoeBag/...
```

Enable SmoeBag in the character-selection AddOns list. Avoid enabling a second addon that replaces the same bag-toggle functions while checking behavior.

| Command | Action |
| --- | --- |
| `/smoebag` | Toggle the inventory window |
| `/smoebag config` or `/smoebagconfig` | Open settings |
| `/smoebag sort` or `/smoebagclean` | Start sorting |

The options panel supports 4–20 columns, 20–100 UI-unit slots and spacing from −2 to 8. Narrow windows hide header controls when they cannot fit; slash commands remain available. Settings and window position are stored in `SmoeBagDB` and normalized when loaded.

## Compatibility and limits

The TOC currently declares interface values `50503, 11508, 20505, 120001`. These are repository metadata, **not a tested compatibility matrix**. API wrappers alone do not establish support for every Retail or Classic build. This refresh was checked outside the game; current-client rendering, protected actions and interaction with other addons still require in-game validation.

Sorting uses inventory pickup/split APIs and respects source and destination item locks. Combat interrupts a sort. A pass stops after thirty seconds of active processing so unavailable item data or restricted bag types cannot cause endless retries. Sorting pauses while the bag window is hidden. Specialized bags and client-specific inventory restrictions can prevent the requested order.

## Code map

The [TOC](SmoeBag.toc) defines module load order.

| Module | Responsibility |
| --- | --- |
| `config.lua`, `saved_variables.lua` | Defaults, shared ranges and persisted-value validation |
| `helpers.lua` | Container API adapters, tooltips and common formatting |
| `ui_frame.lua`, `ui_search.lua`, `ui_footer.lua`, `bagbar.lua` | Window and controls |
| `main.lua`, `events.lua` | Throttled refresh, slash commands and game events |
| `slots.lua`, `layout.lua`, `resize.lua` | Item widgets, grid geometry and resizing |
| `sort.lua` | Stack merging, move queue and retry handling |
| `config_ui.lua` | Live settings preview and Apply/Cancel |

Use four-space indentation and keep client API fallbacks in the helper layer. Add new runtime modules to the TOC in dependency order.

## Development checks

From the repository root, run the standalone Lua 5.1-compatible suite:

```sh
lua tests/run.lua
```

It parses every TOC-listed Lua file and checks persisted-value bounds, partial/legacy API fallback, stack splitting, layout calculations, header visibility, slash commands and the sort deadline with explicit API stubs. It does not emulate a full WoW client.

For an in-game check, verify opening/closing, search and item tooltips, resize persistence after relog, Apply/Cancel, partial stacks, locked items, specialized bags and entering combat during sorting. Include the client build, locale and other bag addons when reporting an issue.

No license file is currently included.
