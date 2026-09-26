# SmoeBag

`SmoeBag` is a clean, lightweight one-bag addon for World of Warcraft with fast updates, live resize, built-in search, and practical sorting.

It is designed to stay responsive during normal gameplay while keeping item management simple and predictable.

## Highlights

- Unified bag window with Blizzard bag toggle overrides
- Live resize with ghost-slot preview
- Instant search filter by name, type, and subtype
- Smart sort flow:
  - Stack merge phase for partial stacks
  - Defrag/reorder phase by practical item priority
- Footer with money + honor display
- In-game config panel (columns, slot size, slot gap)
- Compatibility wrappers for modern `C_Container` and classic APIs

## Commands

- `/smoebag` - Toggle the bag window
- `/smoebagclean` - Start sorting
- `/smoebagconfig` - Open settings

## Install

1. Download or clone this repository.
2. Place the folder in your WoW addons directory:
   - `_classic_era_/Interface/AddOns/`
   - `_classic_/Interface/AddOns/` (MoP Classic)
   - `_anniversary_/Interface/AddOns/` (TBC Anniversary)
   - `_retail_/Interface/AddOns/`
3. Ensure the final path looks like:
   - `.../AddOns/SmoeBag/SmoeBag.toc`
4. Start WoW and enable `SmoeBag` in the AddOns list.

## Notes on Version Support

The addon is built with API compatibility in mind and includes wrappers for both classic and newer container functions. The TOC includes multiple interface targets to support multiple WoW clients.

## Development

Core files are separated by concern:

- `events.lua` - event wiring and bag override behavior
- `layout.lua` - slot layout generation and frame sizing
- `slots.lua` - slot rendering and interactions
- `sort.lua` - sorting pipeline (stack + defrag)
- `resize.lua` - live resize behavior
- `config_ui.lua` - options panel and persistence controls

## License

No license file is currently included. Add one if you want explicit reuse terms.
