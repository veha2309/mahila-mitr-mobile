# Mahila Mitr Rive asset

Place the commercially licensed character file at `mahila_guide.riv`.

Runtime contract:

- Artboard: `Guide`
- State machine: `GuideState`
- Number input: `screen` (`0` home, `1` insights, `2` moments, `3` more)
- Trigger inputs: `wave`, `celebrate`
- Boolean input: `isCheckedIn`

The app deliberately hides the guide if this licensed file is absent or does
not satisfy the contract; all core workflows remain available.
