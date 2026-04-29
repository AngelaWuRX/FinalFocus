# FinalFocus

FinalFocus is an iPhone-first Pomodoro app for undergrad finals prep. It is designed around quick activation, hard-to-abandon focus blocks, study reminders, and reward coins that are earned only after completed work.

## What is included

- SwiftUI iOS app with Focus, Plan, and Rewards tabs
- Date-based timer that keeps working against the device clock
- 90-second activation ritual before deep work
- Friction sheet before abandoning a focus block
- Local notifications for prep, focus, and break completion
- Apple Reminders integration through EventKit
- Reward coin shop after completed blocks
- Backend planning endpoint scaffold in `Backend/server.py`

## Run

Open `FinalFocus.xcodeproj` in Xcode, select an iPhone simulator, and run the `FinalFocus` scheme.

To test the backend planner locally:

```bash
cd Backend
python3 server.py
```

The app currently points at `http://127.0.0.1:8787/plan`. On a physical iPhone, change that to your Mac's LAN IP or deploy the backend.

## App Store notes

Before App Store submission, set your Apple Developer Team, update the bundle identifier, add real app icons, add a privacy policy, and decide whether reminders are core functionality or optional.
