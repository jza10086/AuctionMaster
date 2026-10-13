# Verification

Validated with Godot `4.7.2.stable.official.ed1daf0bf` on Linux.

## Automated

Run `GODOT=/path/to/godot ./tests/run_tests.sh`.

- Import/editor smoke: passed; no parse or import errors.
- Model tests: 3,231 checks, 0 failures.
- Independent rule tests: 44,532 checks, including 500 seeded complete games.
- UI flow: complete three-warehouse match, invalid input, over-budget input, skill state, pause rejection, result/ranking, restart and timeout: passed.
- Project startup smoke: passed, no runtime errors.
- Test runner additionally treats Godot `ERROR` / `SCRIPT ERROR` logs as failure even when the process exits with code zero.

## Native GUI

The independent reviewer exercised a natural three-warehouse match, final rankings (including a shared rank), restart, keyboard pause, help/return and real application-focus loss. Gameplay and paused timer behavior passed. An initial overlap on the fourth bidder card was identified and corrected by reducing card padding. The latest executable was then restarted and rechecked: all four bidder cards and previous-bid hints fit correctly.

The two README screenshots are script-driven captures of the actual main scene using a graphical Godot SubViewport at 1800 × 1125, not image mockups. `tests/capture_screenshots.gd` recreates them with seed 8; the native GUI playthrough was tested separately.

This is local-engine validation. No network/multiplayer, platform export, mobile touch-device, or performance certification is claimed. No CI workflow has been added.
