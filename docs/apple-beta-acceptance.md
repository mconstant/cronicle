# Cronicle Apple beta acceptance

Cronicle on iPhone works by itself. The home screen opens directly into today's
work and makes speaking a task the primary capture action. Watch has a shorter
flow for checking what's next, starting or stopping a timer, and checking
something off. Both experiences keep core task actions available offline.

| Given | When | Then | Evidence |
| --- | --- | --- | --- |
| iPhone opens offline with an empty ledger | I type a task and start its timer | Relaunch restores the timer and completing the task survives a second relaunch | iPhone XCUITest |
| My speech produces a draft | I cancel it, then speak and save again | Only the saved task appears | iPhone XCUITest with injected transcript |
| Voice access is unavailable | I request voice capture | The reason is visible and I can type and save in the same sheet | iPhone XCUITest with unavailable speech fixture |
| On-device recognition is available and allowed | I speak, edit the result, and background the app | I can review the transcript and backgrounding stops the mic | Physical iPhone beta |
| I have two tasks ready on Watch | I start the next task from Focus Brief | The current task changes and time stays with the previous task | Watch ledger and simulator tests |
| I have the same work available on both devices | I start it offline on Watch and reconnect | iPhone reports the same task and time once, with a visible pending state if needed | Cross-device acceptance, pending sync |
| Both builds are accepted by Apple | I open TestFlight and install on supported hardware | Both apps launch and work independently offline | TestFlight and device smoke tests |

The simulator speech fixture exercises UI and save behavior. It cannot establish
microphone permission handling, offline recognition availability, audio routing,
or Bluetooth behavior on actual hardware.
