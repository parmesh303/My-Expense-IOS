# Param_Expense — Commands Cheat Sheet

Run these in **Terminal**, starting from the project folder:

```bash
cd "/Users/parmeshwar.pawar/Documents/Parmesh/Learner_Parmesh/Udemy/Course 1/MyExpense"
```

---

## 1. Install / update on your iPhone (most used)

Use this after code changes, or every ~7 days when the app stops opening (free Apple account limit).
Connect the iPhone with a cable and **unlock** it first.

```bash
TEAM_ID=HCHL95U8PW BUNDLE_ID=com.parmesh.myexpense scripts/run.sh device
```

This generates the Xcode project, builds, signs, installs and launches the app. Data on the phone is kept.

---

## 2. Run in the iPhone Simulator (on the Mac)

```bash
xcodebuild -downloadPlatform iOS    # one time only: downloads the iOS Simulator (several GB)
scripts/run.sh simulator
```

---

## 3. Run the unit tests

```bash
swift test
```

---

## 4. Open in Xcode

```bash
xcodegen generate && open MyExpense.xcodeproj
```

Then pick your iPhone in the device menu at the top and press **⌘R**.

---

## 5. Regenerate the app icon (only if you change its design)

```bash
swift scripts/make-icon.swift MyExpenseApp/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png
```

---

## 6. Check that your iPhone is connected

```bash
xcrun devicectl list devices
```

---

## 7. View the saved history (local Git)

```bash
git log --oneline
```

---

## One-time setup (already done on this Mac)

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
xcodebuild -runFirstLaunch
brew install xcodegen
```

On the iPhone (already done):
- Settings › Privacy & Security › **Developer Mode** → On
- Settings › General › VPN & Device Management → **Trust** your developer certificate

---

## If something goes wrong

| Problem | Fix |
|---|---|
| "No paired iPhone found" | Unlock the phone, re-plug the cable, tap **Trust** |
| Signing / team errors | Xcode › Settings › Accounts — make sure your Apple ID is still signed in |
| App won't open after ~7 days | Run the command in section 1 again |
| "Untrusted Developer" | Settings › General › VPN & Device Management › Trust |
| `xcodebuild requires Xcode` | Run the one-time `xcode-select` command above |

More detail: [docs/06-run-on-iphone.md](docs/06-run-on-iphone.md)
