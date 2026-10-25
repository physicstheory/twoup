# Two-Up

A free, play-money version of the Australian game Two-Up for iOS 17+, with a countdown to 25 April.
SwiftUI, Swift 5.9, no third-party dependencies.

> Play money only. No real-money gambling. For entertainment and education.

## Build and run

Requirements: Xcode 15+, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```sh
xcodegen            # generates TwoUp.xcodeproj from project.yml
open TwoUp.xcodeproj
```

Pick an iPhone simulator and run the `TwoUp` scheme. Set your own bundle identifier and team in
`project.yml` (`PRODUCT_BUNDLE_IDENTIFIER`, `bundleIdPrefix`).

**Tests**

```sh
swift test                                   # TwoUpCore: engine, clock, session (no simulator needed)
xcodebuild test -scheme TwoUp -destination 'platform=iOS Simulator,name=iPhone 15'   # app tests
```

**Debug date.** In DEBUG builds, tap the "TWO-UP" pill on the home screen five times to override today's date
(jump to 24 April 23:59:50 to watch the countdown roll into 25 April). The menu is compiled out of release builds.

## Structure

| Path | What it is |
|---|---|
| `Sources/TwoUpCore` | Pure Swift, no UI. `TwoUpEngine`, betting and payouts, `CommemorationDayClock`, the `GameSession` protocol and `LocalSimulatedSession` |
| `Tests/TwoUpCoreTests` | Engine (all outcomes, five-odds, payouts, rotation), clock (year boundaries, leap years, time zones, 25 April, the day after), session |
| `TwoUpApp` | SwiftUI app: `Home`, `Game`, `Scene` (SceneKit), `Settings`, `Services`, `Design` |
| `TwoUpAppTests` | View-model and formatting tests |

MVVM throughout. Views talk to view models; `GameViewModel` talks to a `GameSession`. Swapping in a networked session
means changing one line in `GameViewModel.local(mode:env:)`.

## Rules as implemented

- Two heads: Spinner wins and keeps spinning. Two tails: Spinner loses and the spin passes. One of each ("odds"): toss again; five odds in a row and the Spinner loses.
- The Spinner stakes on heads; other players fade (cover) it. Only the covered amount is at risk, and any uncovered stake is returned.
- Side bets settle on every toss: heads 1:1, tails 1:1, odds a fixed 2:1. The 2:1 odds price is a stated rule of this play-money game, not a fair price.
- Everyone starts with 1,000 pennies (play money). If you reach zero a free reset is offered. It is never purchasable.

## Legal and product constraints (do not break these)

- Play money only: no real money, no in-app purchases, no cash-out, no prizes of real-world value, no ads, no links to gambling sites.
- Disclaimer on first launch and in Settings: "Play money only. No real-money gambling. For entertainment and education."
- No accounts, no payment SDKs, no analytics. All state is local (UserDefaults).
- Respectful treatment of 25 April. No RSL logos or official commemorative branding. No jokes about war or veterans.
- The word "Anzac" is deliberately not used anywhere in the app, its name, code or metadata, because its commercial use is restricted by law in Australia.
- About screen covers the history of two-up and that real two-up is only legal at approved venues on 25 April (plus a lead-up period in Victoria), with a note that rules vary by state.
- Settings links to Gambling Help Online (gamblinghelponline.org.au).

**Before you ship, get these checked:**
1. **Keep the word "Anzac" out of everything**: app name, subtitle, keywords, description, screenshots and icon. Its commercial use is restricted in Australia. The same goes for RSL logos and names.
2. **The legal wording in `AboutView.swift`**, in particular the Victorian lead-up sentence. It reflects the brief and I could not verify it. Have it confirmed against current Victorian regulator guidance.
3. Whether a play-money two-up game needs any state-level approval where you distribute. Get legal advice.

## Making it photorealistic

SwiftUI and SceneKit can't produce photorealism by themselves. The scene is built so that photographic assets drop in
with no code changes. Add them to `TwoUpApp/Assets.xcassets` as image sets with these names (see `SceneAssets.swift`):

| Asset name | What to supply |
|---|---|
| `beer_garden_panorama` | A 2:1 equirectangular panorama or HDRI of a pub beer garden at dusk. It becomes the sky, backdrop and the reflections on the coins. Poly Haven has CC0 HDRIs; shoot your own with a 360 camera for the best result |
| `ground_dirt` | Seamless dirt or gravel texture for the ring |
| `crowd_01` to `crowd_12` | Transparent PNG cut-outs of full-length people facing the camera, ideally at slightly different angles. The scene turns them into billboards around the ring. Photograph models with signed releases, or use properly licensed stock or generated characters. Never use anyone's likeness without consent |
| `coin_heads`, `coin_tails` | Square textures for the coin faces |

For a higher ceiling: model the garden, kip and coins in Blender, bake the lighting, export USDZ, and load it in
`CoinSceneController` in place of the procedural geometry. For the most cinematic result, pre-render the toss from the
Spinner's point of view and play back the matching clip; you lose flexibility but gain realism.

Without these assets the app uses stylised stand-ins (dusk sky, silhouette crowd, procedural gold coins).

## Online multiplayer (not built)

`GameSession` is the seam. A networked implementation should:

- Treat the **server as the authority** for tosses, bets and balances. A client-side random number generator can be cheated.
- Keep the same play-money rules: no purchases, no cash-out, no prizes.
- Use anonymous identity if possible, and moderate or restrict nicknames and any chat. Provide report and block tools.
- Update the privacy nutrition label to match whatever the backend actually collects. **"Data Not Collected" only holds for the offline app.**
- Revisit the age rating.

## App Store submission checklist

**Age rating (simulated gambling).** Answer the age-rating questionnaire honestly for "Simulated Gambling". A game built around betting, even with play money, is rated at the upper end, so expect a high age rating (17+ under the older scheme, 18+ under the newer one). Do not pick a lower answer to get a lower rating. Check the current questionnaire in App Store Connect and any regional restrictions.

**Privacy nutrition label.** Offline build: select **Data Not Collected**. No SDKs collect anything. The privacy manifest (`TwoUpApp/PrivacyInfo.xcprivacy`) declares no tracking, no collected data, and the one required-reason API the app uses, `UserDefaults` (reason `CA92.1`).

**Review notes.** State clearly: play money only, no purchases, no cash-out, no real-world prizes, no accounts. Mention that Gambling Help Online is linked in Settings.

**Other items**
- [ ] App icon (1024×1024) with no commemorative or RSL marks
- [ ] Set bundle ID, team, version and build number
- [ ] Support URL and privacy policy URL (a short page saying nothing is collected)
- [ ] Export compliance: `ITSAppUsesNonExemptEncryption` is already `NO`
- [ ] Accessibility pass: VoiceOver, Dynamic Type at the largest sizes, Reduce Motion, light and dark mode
- [ ] Test on a small phone and an iPad if you keep iPad support

**Screenshots needed**
- iPhone 6.9" (1320×2868): home countdown, 25 April state, game with coins in the air, result banner, side bets, settings or About
- iPhone 6.5" (1284×2778) if required by your App Store Connect setup
- iPad 13" (2064×2752) if you ship iPad support (the project targets iPhone and iPad)
- Take the 25 April screenshots using the debug date menu, and avoid imagery that looks like a casino
