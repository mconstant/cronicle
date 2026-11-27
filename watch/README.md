# Cronicle for Apple Watch

A standalone SwiftUI companion for quick task capture and one active timer.
Use the system text field to enter a task by keyboard, Scribble, or
dictation when your Watch offers it. Tap a task to start timing or mark it
complete. Stopping preserves the task and its logged time. Starting a
different task closes the existing timer. Tasks, completions, and elapsed
time are stored on the Watch and restored at launch.

The main screen puts the active timer first, then open tasks. Completed
items stay available at the bottom. Controls have text labels and use
standard watchOS navigation and Dynamic Type.

Tap **Focus Brief** in the toolbar to check what is running, what is next,
and how many tasks are complete. Use **Start next** when no timer is
running, or **Read aloud** for a spoken recap using watchOS speech
synthesis. Audio follows the active system route. Headset routing and
offline playback still need a physical Watch test.

This app works offline. The Watch ledger and the Docker ledger are
separate. Ambient Mode, syncing, and reminders require further work.

## Try the simulator build

Use a Mac with Xcode and a watchOS simulator. Download
`cronicle-watch-simulator.zip` from the GitHub release, unzip it, and boot
an Apple Watch simulator. Then run:

```sh
xcrun simctl install booted CronicleWatch.app
xcrun simctl launch booted com.mconstant.cronicle.watch
```

If more than one simulator is running, use the Watch simulator UUID in
place of `booted`. This build is for the simulator. A physical Watch,
TestFlight, and App Store distribution require an Apple-signed build.

## Build and test

With Xcode and XcodeGen installed, run `bash watch/qa.sh` from the repository.
QA runs ledger and interaction tests, builds the app, installs and launches it on
a watchOS simulator, and captures a screenshot. The ledger tests cover
duplicate capture, timer switches, completion, and restore from storage.
