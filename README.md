<img width="2048" height="419" alt="image" src="https://github.com/user-attachments/assets/f1e17c1f-6a72-44f2-87f6-1fbae70977fd" />

<img width="1916" height="821" alt="image" src="https://github.com/user-attachments/assets/b775c84e-73e4-43bf-abc7-7bcfe285f007" />


# What is this?
-Little project to fix things I find annoying in vape.

-I will try my best to keep this as a high quality custom.

# Loader

```luau
loadstring(game:HttpGet('https://raw.githubusercontent.com/Floorzey/VapeTweakerForRoblox/main/loader.lua', true))()
```

# Game modules

Game-specific modules do not use manifests or a game list. Put each module directly in the current PlaceId folder:

```text
src/games/<placeid>/<module>.lua
```

Example:

```text
src/games/6872274481/killaura.lua
src/games/6872274481/fastbreak.lua
```

The loader discovers the folder from `game.PlaceId` and loads every `.lua` file inside it.

# Credits

7GrandDadPGN (Vape Owner)

Vanilla Roblox Vape: https://7granddadpgn.github.io
