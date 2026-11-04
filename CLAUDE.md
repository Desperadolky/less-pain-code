# Less Pain Code

- `./setup.sh` runs route checks and builds and signs a local app at `build/Less Pain Code.app`.
- `./setup.sh --test` runs the standalone route checks without building the app.
- `Sources/MouseNav.swift` implements the AppKit floating panel, menus and shortcuts.
- `Sources/MacSpaces.swift` reads desktop topology and performs system desktop switching.
- `Sources/SpaceCycle.swift` computes the next target. `Tests/SpaceCycleCheck.swift` exercises the routing logic with synthetic display layouts.
- `Info.plist` defines the app bundle. Icons are in `Resources/`. Keep upstream attribution in `THIRD_PARTY_NOTICES.md` and `licenses/`.
