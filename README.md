# Turtle Pet Happiness

A lightweight Turtle WoW / Vanilla-style addon for Hunters that shows a **smooth pet happiness meter**.

Since `GetPetHappiness()` only exposes 3 states (Unhappy/Content/Happy), this addon builds a **virtual 0-100 meter** by combining:

- current happiness state checkpoints,
- gradual decay over time,
- feed detection boosts,
- smoothing to keep transitions natural.

## Features

- Continuous happiness bar (`0-100`) instead of only `1-3` buckets
- Color-coded status:
  - Green = Happy range
  - Yellow = Content range
  - Red = Unhappy range
- Auto-sync with in-game pet state changes
- Feed boost detection (spellcast/chat-event based)
- Draggable frame
- Position persistence per character

## Installation

1. Close WoW.
2. Copy the addon folder to:
   - `World of Warcraft/Interface/AddOns/Turtle_PetHappiness`
3. Ensure these files are inside that folder:
   - `Turtle_PetHappiness.toc`
   - `Turtle_PetHappiness.lua`
4. Start WoW and enable **Turtle Pet Happiness** in AddOns at character select.

## Usage

The bar appears when you have a pet and updates automatically.

Slash commands:

- `/tph lock` — lock frame position
- `/tph unlock` — unlock and allow dragging
- `/tph reset` — reset frame position to default

## How It Works

- API state mapping:
  - `3 (Happy)` -> target ~`83`
  - `2 (Content)` -> target ~`50`
  - `1 (Unhappy)` -> target ~`17`
- A small per-second decay drains the meter gradually.
- On state changes, the meter eases toward the mapped target.
- On feed detection, the meter receives a configurable boost.

## Configuration (in code)

In `Turtle_PetHappiness.lua`:

- `DECAY_PER_SECOND` controls passive drain speed
- `FEED_BOOST` controls gain after detected feeding

Default values:

- `DECAY_PER_SECOND = 0.02`
- `FEED_BOOST = 25`

## Vanilla/Turtle Limitations

The game does **not** expose exact internal happiness values/timers via API.
This addon estimates happiness to provide a smoother, more useful display.

## Version

`0.1.0`
