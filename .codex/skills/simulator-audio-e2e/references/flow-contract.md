# Simulator Flow Contract

The canonical flows are `e2e/maestro/audio-ios.yaml` and
`e2e/maestro/audio-android.yaml`. They use stable `e2e-*` accessibility IDs
from the example app; visible text is asserted only for user-observable state.

| Area | Required proof |
| --- | --- |
| Launch | Home title renders after a clean app launch. |
| Direct recorder | Start resolves, time reaches at least one second, pause and resume accept input, stop returns to `Recording: No`. |
| Direct player | Play reaches `Playing: Yes`; pause, resume, and stop each reach the expected state. |
| Hook recorder | The `useSound` screen reaches four callback-driven seconds, repeats pause/resume/stop, and exposes a file path. |
| Hook player | The hook repeats play/pause/resume/stop with callback-driven state. |
| Errors | No permission, start, stop, or playback error alert may be dismissed silently. |

Android shows a success alert containing the saved path after recorder stop;
the Android flow asserts and dismisses it. iOS does not show this alert.

Simulator output proves API state transitions and native integration, not
speaker fidelity. Remote rapid-switch flows remain separate because they
depend on external network and media hosts.
