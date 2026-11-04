# Third-party notices

The app builds with the macOS SDK and has no third-party runtime dependencies. The following projects informed the Swift code in `Sources/MacSpaces.swift`.

- **yabai (MIT)**. The private Core Graphics event fields and the begin/end sequence in `postSwipe` are adapted from [yabai's Space manager](https://github.com/asmvik/yabai/blob/master/src/space_manager.c). The original copyright and license text are in [licenses/yabai.txt](licenses/yabai.txt).
- **Hammerspoon (MIT)**. The [`hs.spaces` module](https://github.com/Hammerspoon/hammerspoon/blob/master/extensions/spaces/spaces.lua) documents the Mission Control Accessibility hierarchy used to find the target desktop button. The original copyright and license text are in [licenses/Hammerspoon.txt](licenses/Hammerspoon.txt).

yabai credits [InstantSpaceSwitcher](https://github.com/jurplel/InstantSpaceSwitcher) and [wacom-driver-fix](https://github.com/thenickdude/wacom-driver-fix/blob/bdfda9a788934c88d09d31ea6a42664b9ba1471e/Readme.md) and notes that the gesture technique was first observed in BetterTouchTool. [Instant Space Switcher (iss)](https://github.com/joshuarli/iss) was also consulted for gesture field definitions.
