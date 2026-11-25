# 06 — Running MyExpense on your iPhone

Building an iOS app needs **full Xcode** (Command Line Tools are not enough). The steps below take about 30–60 minutes the first time, mostly the Xcode download.

## 1. One-time Mac setup

1. Install **Xcode 26 or later** from the Mac App Store (it is free; about 15 GB with the iOS platform).
2. Open Xcode once, accept the licence, and let it install the iOS platform (Xcode › Settings › Components).
3. In Terminal:
   ```bash
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   xcodebuild -runFirstLaunch
   brew install xcodegen        # already installed on this Mac
   ```
4. Sign in with your Apple ID: Xcode › Settings › Accounts › **+** › Apple ID.
   * A free Apple ID gives you a **Personal Team**. Apps signed with it run for **7 days**, then must be re-installed.
   * A paid Apple Developer Program membership ($99/year) is needed for TestFlight and the App Store.
5. Find your **Team ID**: Xcode › Settings › Accounts › select the team. For paid accounts it is also at developer.apple.com › Account › Membership.

## 2. One-time iPhone setup

1. Your iPhone must run **iOS 26 or later** (the app's minimum version).
2. Connect it with a USB cable, unlock it, and tap **Trust This Computer**.
3. Turn on **Developer Mode**: Settings › Privacy & Security › Developer Mode › On. The phone restarts; confirm when asked.
   *(The Developer Mode switch only appears after the phone has been connected to Xcode once. Open Xcode › Window › Devices and Simulators to trigger it.)*

## 3a. Try it in the Simulator first (no signing needed)

```bash
cd MyExpense
scripts/run.sh simulator
```

## 3b. Install on your iPhone

Pick a bundle ID that is unique to you, e.g. `com.parmesh.myexpense`:

```bash
cd MyExpense
TEAM_ID=YOURTEAMID BUNDLE_ID=com.parmesh.myexpense scripts/run.sh device
```

The first time with a free Personal Team, iOS blocks the app as an "Untrusted Developer". Go to **Settings › General › VPN & Device Management**, tap your Apple ID, then tap **Trust**. Then open MyExpense from the Home Screen.

### Prefer clicking in Xcode?

```bash
xcodegen generate && open MyExpense.xcodeproj
```
1. Select the **MyExpense** target › **Signing & Capabilities**.
2. Tick *Automatically manage signing*, choose your Team, and set a unique Bundle Identifier.
3. Choose your iPhone in the device menu at the top, then press **⌘R**.

## 4. What to try (Phase 2 checklist)

- [ ] Complete onboarding and create a bank account with an opening balance
- [ ] Add an expense, an income, a refund and a transfer (Home or Transactions › **+**)
- [ ] Check that Home totals ignore the transfer and that balances update
- [ ] Search by payee; filter by type, account, category, date and amount; change the sort
- [ ] Open a transaction, edit it, attach a photo and a PDF, preview them, remove one
- [ ] Swipe to delete a transaction and confirm
- [ ] Settings › Accounts: add a credit card (amount owed), archive and restore an account
- [ ] Settings › Categories: add, rename, recolour, reorder (Edit) and archive a category
- [ ] Dark mode, larger Dynamic Type sizes and VoiceOver

## Troubleshooting

| Problem | Fix |
|---|---|
| `xcodebuild requires Xcode` | Run the `xcode-select -s` command from step 1 |
| "No profiles for … were found" / signing errors | Sign in to Xcode › Settings › Accounts, check TEAM_ID, and use a unique BUNDLE_ID |
| "Failed to register bundle identifier" | That bundle ID is taken. Choose a different one |
| iPhone not found | Unlock the phone, re-plug the cable, tap Trust, and check Developer Mode is on |
| "Untrusted Developer" | Settings › General › VPN & Device Management › Trust |
| App stops opening after 7 days | Free Personal Team limit. Run the device command again |
| Compile error in `SchemaV1.swift` / `SwiftDataRepositories.swift` | These files could not be compiled without Xcode during development. Send me the error text and I'll fix it |
