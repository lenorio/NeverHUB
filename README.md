# NeverHUB

A Roblox script hub that detects your current game and offers to load a matching script. Click **Load script** to start it, then enable the features you want in the game script's panel.

The hub unloads after a script starts successfully. Opening an already running script also unloads the hub. If loading fails, the hub stays open so you can retry.

## Getting started

```luau
loadstring(game:HttpGet("https://raw.githubusercontent.com/lenorio/NeverHUB/main/NeverHUB.luau"))()
```

To run the hub after every injection, copy [autoexec/NeverHUB.luau](autoexec/NeverHUB.luau) into Real's **AutoExec** folder. AutoExec runs after the executor attaches to Roblox; you still need to inject the executor yourself.

**Right Shift** toggles the panel while the hub is running. **Unload hub** removes the hub without stopping your game script. To open the hub again after it unloads, run the loader above.

## Supported games

| Game | PlaceId | Script |
| --- | --- | --- |
| Tap Incremental | `82103875404639` | [TapIncremental_Automator.luau](TapIncremental_Automator.luau) |

Tap Incremental includes auto taps, runes, classes, rarities, available upgrades, mining, trees, fruit collection with teleports, and ore/fish selling. Rune purchases from a distance briefly move your character to the rune button and back. Taps, fruit collection, stone mining, ore selling, and Basic runes have been verified in game; other actions need separate checks in their respective zones.

## Adding a game

1. Upload the game's `.luau` script to this repository.
2. Add an entry to `manifest.json`:

```json
{
  "id": "example-game",
  "name": "Example Game",
  "version": "1.0.0",
  "description": "What the script can do",
  "placeIds": [123456789],
  "file": "ExampleGame.luau",
  "runtimeKey": "ExampleGameRuntime"
}
```

Use a unique `id`. The optional `runtimeKey` identifies the script's runtime in `getgenv()` through its `alive` and `window` fields. Each game script should stop its previous instance when loaded again. You can also specify `universeIds`: an exact `PlaceId` match takes priority, followed by `game.GameId`. Only use a universe ID when the script supports all places in that universe.

The catalog updates when the hub starts and when you click **Refresh catalog**. Downloads are cached in the executor's Workspace under `NeverHUB`; valid cached files are used if GitHub is temporarily unavailable.

## Files

- `NeverHUB.luau` — game detection, catalog, load prompt, and script loading.
- `manifest.json` — supported games and script versions.
- `autoexec/NeverHUB.luau` — Real AutoExec loader with a cached fallback.
- `TapIncremental_Automator.luau` — Tap Incremental automation.

The interface uses [WindUI](https://github.com/Footagesus/WindUI). Hub controls, messages, catalog descriptions, and documentation are in English.
