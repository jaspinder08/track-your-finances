# Impeccable audit: `lib/` (TYF mobile)

Date: 2026-11-28 · Branch: `feature/jassi/001_auth` · Method: `/impeccable audit lib/`, native playbook (`reference/audit.native.md`), scored against `reference/android.md` (the app ships SMS-inbox features, so Android is the primary target; iOS guarantees noted where they apply).

No code was changed. There is no PRODUCT.md or DESIGN.md, so the code is the only design authority; `/impeccable init` then `/impeccable document` would give later passes something to hold the app to.

Focus requested: what makes the UI read as AI-generated rather than designed by a person. That lens runs through every section below and has its own list in [Why it reads as AI-generated](#why-it-reads-as-ai-generated).

---

## Audit Health Score

| # | Dimension | Score | Key finding |
|---|-----------|-------|-------------|
| 1 | Accessibility | 1 | Calendar day cells have no semantics; income/expense/accent colours fail contrast in light mode; no Reduce Motion handling anywhere |
| 2 | Performance | 3 | History builds every row eagerly; count-up and stagger animations replay on every tab visit |
| 3 | Appearance & Theming | 2 | Tokens exist but are bypassed: 47 raw hex colours in 14 files, 14 different corner radii, light/dark themes copy-pasted |
| 4 | Platform Conformance | 2 | Custom floating pill nav + glowing FAB, custom page route with no predictive Back, mixed icon sets |
| 5 | Adaptivity | 1 | Portrait-locked in code and manifest; no tablet/expanded layout; `FittedBox` shrinks text instead of reflowing |
| **Total** | | **9/20** | **Poor (major overhaul)** |

## Platform Conformance Verdict

**Fail.** A fluent Android user would trust what the app does, but not how it looks: it reads as a Dribbble-style concept shot built in Flutter, not a Material 3 app. The giveaways are a floating glass pill nav bar with a glowing centre `+`, ambient radial "glow" blobs behind every screen and inside every hero card, gradient-and-glow tiles for every category and stat, and a custom slide-and-fade route that skips Android's predictive Back. Material 3 is switched on (`useMaterial3: true`), then almost every surface opts out of it.

## Executive Summary

- Audit Health Score: **9/20 (Poor)**
- Issues found: **P0: 1 · P1: 9 · P2: 8 · P3: 3**
- Top issues:
  1. **[P0]** Calendar day cells, the app's main interaction, can't be used with TalkBack (`calendar_screen.dart:397`).
  2. **[P1]** Light-mode contrast fails for income green (3.07:1), expense red (3.91:1) and 4 of the 8 accents with white `onPrimary` text (amber 2.14:1, teal 2.62:1).
  3. **[P1]** A decorative glow system (`AppBackground`, `HeroCard._Glow`, glowing FAB, glowing category tiles) is the strongest AI tell and does nothing for the user.
  4. **[P1]** The token system exists but is ignored: radii go 3/4/6/8/10/12/13/14/16/18/20/28/36/100, and three different reds stand in for "expense".
  5. **[P1]** Nothing honours Remove Animations; money counts up from ₹0 every time a tab is opened.
- Next steps: fix accessibility and contrast first (`/impeccable harden`), then strip the decoration (`/impeccable quieter`, `/impeccable distill`), then put one token source in place (`/impeccable document`, then `/impeccable polish`).

---

## Why it reads as AI-generated

Ranked by how loudly each one says "generated". Every item has a full entry in the findings below.

1. **Ambient accent glows everywhere.** Three radial gradients behind every route (`app_background.dart:39-79`), two more glow circles inside every hero card (`hero_card.dart:76-89`), an accent-coloured shadow under the hero in dark mode (`hero_card.dart:63-70`), the nav bar (`floating_nav_bar.dart:97-106`) and the FAB (`floating_nav_bar.dart:115-123`). This "soft aurora" backdrop is the single most common generated-UI look of 2024–26.
2. **Gradient + coloured drop-shadow on every tile.** Category tiles (`category_icons.dart:245-264`), account tiles (`accounts_screen.dart:308-325`, `385-400`), the categories CTA (`categories_screen.dart:468-483`), stat cards, total tiles and analytics panels (`analytics_screen.dart:136-152`) all use a top-left→bottom-right `LinearGradient`, usually with a shadow in the same colour. When everything glows, nothing stands out.
3. **The icon-in-a-tinted-circle + label + big number KPI tile, repeated.** `_StatCard` (`calendar_screen.dart:241-320`), `_TotalTile` (`analytics_screen.dart:427-500`), the budget hero's icon chip (`budgets_screen.dart:103-117`), every `_Panel` header (`analytics_screen.dart:158-160`), and every `OptionSection` (`option_row.dart:22`). Every block gets an icon whether or not the icon tells you anything.
4. **A hard-coded violet second accent.** `0xFF8B5CF6` / `0xFFA78BFA` blended into the user's accent for the avatar ring, greeting name, brand wordmark and heart (`app_drawer.dart:121, 171, 372, 390`). Pick "Green" in Settings and the drawer still goes purple. The "accent + neighbouring hue" trick repeats in `app_background.dart:22-25`.
5. **Template copy.** "Hello there" / "Good to see you again!" (`app_drawer.dart:162, 183`), "Track Your Finances. Live Better." brand card with a heart icon (`app_drawer.dart:345-397`), `'TRACK  YOUR  FINANCES'` spaced caps under the logo (`welcome_screen.dart:104`), `'BALANCE'` eyebrow (`top_bar.dart:98`), 👋 in the first-run hint (`calendar_screen.dart:499`), a sparkle icon for "Insights" (`top_bar.dart:176`).
6. **The three-feature onboarding list.** Icon badge + bold title + one-line blurb, three times (`welcome_screen.dart:112-126`). This is the landing-page hero formula on a phone.
7. **Settings has a hero card.** A gradient glow card with a fake "₹24,500 saved this month" (`settings_screen.dart:48-95`). Profile has one as well (`profile_screen.dart:53`). Settings is an Operate surface; a hero there is decoration standing in for hierarchy.
8. **Numbers that animate in.** `AnimatedMoney` counts from ₹0 to the real total over 900 ms on each tab visit (`motion.dart:19-33`), and `FadeSlideIn` staggers 18 blocks into place (`motion.dart:37-61`). In a finance app the number *is* the content, and making the user wait to read it is the opposite of trustworthy.
9. **Comments that contradict the code.** "Pill-shaped filled segments" above an 8 px radius (`app_theme.dart:278-286`), "Flat pill" above a square icon-button theme (`app_theme.dart:334-336`), "Soft circular button" next to the 8 px-square `iconButtonTheme`, "a soft wave at the foot" on a stat card with no wave (`calendar_screen.dart:240`, `321`), and a `HeroCard.foreground = Colors.white` "legacy constant" that's wrong in light mode (`hero_card.dart:22-23`). This is what code looks like after several regenerations nobody reconciled.

---

## Detailed Findings by Severity

### P0 Blocking

**[P0] Calendar day cells are unusable with TalkBack/VoiceOver**
- **Location**: Calendar tab, `lib/features/calendar/screens/calendar_screen.dart:397-450`
- **Category**: Accessibility
- **Impact**: Each cell is a bare `GestureDetector` around a `FittedBox`. A screen reader announces "14", then "+1.2k", then "−850" as separate nodes, with no date, month, "today", or "button" role. Tapping a day is the home screen's main action (open the day, or add to it), so a blind user can't do the app's core task.
- **Guideline**: Material accessibility: every touch target needs a role and a label.
- **Recommendation**: Wrap each cell in `Semantics(button: true, label: 'Friday 14 November, spent ₹850, earned ₹1,200', selected: isToday, onTap: onTap, excludeSemantics: true)`, or use `InkWell`/`Material` so it gets a ripple and a role.
- **Suggested command**: `/impeccable harden`

### P1 Major

**[P1] Light-mode contrast fails for the colours that carry meaning**
- **Location**: `lib/app/theme/app_theme.dart:22-23` (income `#22A861`, expense `#E5484D`), `app_theme.dart:41, 205` (`onPrimary` threshold `> 0.45`)
- **Category**: Accessibility
- **Impact**: Measured on white: income 3.07:1, expense 3.91:1, accent blue 3.91:1. All fail the 4.5:1 AA minimum for text, and they're used for 11 px amounts in calendar cells (`calendar_screen.dart:472-478`). On the `#F3F4F7` canvas, green falls to 2.79:1. The luminance threshold also gives amber (lum 0.44) **white** text at 2.14:1, teal 2.62:1, coral 2.99:1 and green 3.07:1, so the main `+` button, Save buttons and selected segments are hard to read in half the accents.
- **Guideline**: WCAG 2.2 1.4.3; Material colour roles (`on*` colours must pass against their container).
- **Recommendation**: Split each finance colour into a role pair: a darker text tone for light mode (about `#137A43` green and `#C42F35` red, ≥4.5:1) and the current brighter tone for fills and dark mode. Pick `onPrimary` by actual contrast ratio (whichever of white or near-black passes), not by a luminance cut-off.
- **Suggested command**: `/impeccable harden`

**[P1] Decorative glow layer on every screen**
- **Location**: `lib/core/design/app_background.dart:39-79`; `lib/core/widgets/hero_card.dart:63-89`; `lib/app/shell/floating_nav_bar.dart:97-123`; `lib/core/design/category_icons.dart:255-264`
- **Category**: Theming / Conformance (and the top AI tell)
- **Impact**: Three full-screen radial gradients, plus two per hero card, plus accent-coloured shadows. It's visual noise behind numbers people need to read, it washes out contrast near the corners in dark mode (accent at 20 % alpha), and it's why every screen looks the same.
- **Guideline**: Material 3 tonal elevation: depth comes from surface tone levels, not arbitrary glows.
- **Recommendation**: Replace `AppBackground` with a flat `scheme.surface` (keep the 5 % accent tint if wanted; drop the glows). Delete `_Glow` and the coloured hero shadow. Let hierarchy come from type scale and spacing. If one signature moment is wanted, give it to a single place, such as the calendar's spending heat, and nowhere else.
- **Suggested command**: `/impeccable quieter`

**[P1] Gradient + coloured shadow on every tile and card**
- **Location**: `category_icons.dart:245-264`; `accounts_screen.dart:308-325, 385-400`; `categories_screen.dart:246-255, 468-483`; `calendar_screen.dart:263-273`; `analytics_screen.dart:136-152, 446-456`; `budgets_screen.dart:343-348` (sweep-gradient ring)
- **Category**: Theming
- **Impact**: 18 gradients across 10 files. Everything is tinted and lifted, so nothing has priority, and the category colour tiles all look equally loud next to each other.
- **Recommendation**: Flat fills only. Category tile: a 14 % tint of the category colour with the icon in the full colour (which `IconBadge` already does at `icon_badge.dart:34-45`, so use it everywhere). Cards: one `AppCard` style with no gradient. Progress rings: a solid stroke.
- **Suggested command**: `/impeccable distill`

**[P1] Off-platform navigation: floating glass pill with a glowing centre FAB**
- **Location**: `lib/app/shell/floating_nav_bar.dart:62-142`, `lib/app/shell/app_shell.dart:193-205`
- **Category**: Conformance
- **Impact**: A hand-made 72 dp pill with gradient fill, accent border and glow, icon-only tabs (labels only in tooltips, which need a long-press), and the FAB inside the bar. Users don't see labels, TalkBack gets no "tab, 2 of 4, selected" state, and the `+` changes meaning by tab (budget on Budgets, transaction elsewhere) while its tooltip always says "Add transaction" (`floating_nav_bar.dart:131`).
- **Guideline**: M3 Navigation bar (3–5 destinations, labelled, with an active indicator); one FAB for one primary action.
- **Recommendation**: Use `NavigationBar` with `NavigationDestination`s (labels on), themed with `indicatorColor` from the accent. Put a standard `FloatingActionButton` in `Scaffold.floatingActionButton` (`endFloat` or `centerDocked`), and set its tooltip and icon per tab.
- **Suggested command**: `/impeccable adapt`

**[P1] Custom page route breaks predictive Back and ignores the platform transition**
- **Location**: `lib/core/navigation/page_route.dart:11-30`; `android/app/src/main/AndroidManifest.xml` (no `android:enableOnBackInvokedCallback`)
- **Category**: Conformance
- **Impact**: Every pushed page uses a non-opaque `PageRouteBuilder` slide+fade. On Android 14+ there's no predictive Back preview, and on iOS there's no edge-swipe-back (`PageRouteBuilder` isn't a `CupertinoRouteTransitionMixin`). The route is non-opaque to work around a Riverpod issue, so every route also repaints the full `AppBackground` glow stack underneath.
- **Guideline**: Android: system Back always works, predictive Back honoured. iOS: edge-swipe back.
- **Recommendation**: Use `MaterialPageRoute` with `pageTransitionsTheme: PageTransitionsTheme(builders: {TargetPlatform.android: PredictiveBackPageTransitionsBuilder(), TargetPlatform.iOS: CupertinoPageTransitionsBuilder()})`, and add `android:enableOnBackInvokedCallback="true"`. Fix the Riverpod pause issue at its source (`ref.listen` in widgets above the route, or `TickerMode`-safe providers) rather than with `opaque: false`.
- **Suggested command**: `/impeccable adapt`

**[P1] No Reduce Motion / Remove Animations support anywhere**
- **Location**: `lib/core/design/motion.dart:19-61`, `lib/app/shell/app_shell.dart:47-60, 149-166`, `page_route.dart`, `welcome_screen.dart:41-53`, `top_bar.dart:107-118`
- **Category**: Accessibility
- **Impact**: `MediaQuery.disableAnimations` isn't read anywhere in `lib/`. Balances count from ₹0 over 900 ms every time a tab is opened (`TabVisit` re-keys them), 18 `FadeSlideIn` blocks slide up on each visit, and the whole tab slides on switch. That's motion-sickness risk, and a slow read of the one number the user came for.
- **Guideline**: Material motion: honour the system "Remove animations" setting; iOS Reduce Motion.
- **Recommendation**: Read `MediaQuery.disableAnimationsOf(context)` in `AnimatedMoney` and `FadeSlideIn` and render the final state at once when it's set. Separately (for everyone): don't count money up from zero. Show the value and only tween *changes* (`begin:` the previous value), and drop the per-visit replay.
- **Suggested command**: `/impeccable animate`

**[P1] Token system exists but is bypassed: radii, colours and duplicated themes**
- **Location**: `lib/core/design/tokens.dart:17-28` vs `lib/app/theme/app_theme.dart:31` (`radius = 20.0`), `hero_card.dart:15` (20), `option_row.dart:49, 86` (18), `app_drawer.dart:58, 100, 200, 350` (18/28), `floating_nav_bar.dart:91` (36), `analytics_screen.dart:137, 447` (20/18); colours across 14 files
- **Category**: Theming
- **Impact**: `AppRadius` says "tight corners, never pill-shaped" and tops out at 12, but the code uses 14 radii (3, 4, 6, 8, 10, 12, 13, 14, 16, 18, 20, 28, 36, 100), with `circular(100)` pills 11 times. There are 47 raw `Color(0x…)` values outside the theme. "Expense red" exists as `#E5484D`, `#FF6B78` (`app_drawer.dart:335`, `accounts_screen.dart:366`, `sms_scan_screen.dart:344`), `#C8303A` and `#FF8A92` (`calendar_screen.dart:439-441`). Warning amber is `#F5A524` (`budget_progress_bar.dart:7`), separate from the amber accent `#F2A007`. `AppTheme.light` and `.dark` are about 160 near-identical lines each (`app_theme.dart:33-193` vs `195-356`), which is why the comments have drifted apart.
- **Recommendation**: Pick one radius ladder (e.g. 8 controls / 12 cards / 16 sheets / full for avatars only) and route every `circular(n)` through `AppRadius`. Put finance and status colours in a `ThemeExtension<FinancePalette>` with light and dark values. Build both themes from one `_build(ColorScheme)` function.
- **Suggested command**: `/impeccable document` (to write DESIGN.md), then `/impeccable polish`

**[P1] Hard-coded violet second accent ignores the user's colour choice**
- **Location**: `lib/app/shell/app_drawer.dart:118-124, 169-173, 370-373, 388-391`
- **Category**: Theming
- **Impact**: The drawer's sweep-gradient avatar ring, the greeting name, the "TYF" brand text and the heart all blend in a fixed violet (`#8B5CF6`, `#A78BFA`). With Coral or Green selected, the drawer stays purple-ish, which breaks the Settings promise that the accent "changes the whole mood". A violet-to-accent gradient is also a stock generated-UI flourish.
- **Recommendation**: Use `scheme.primary` only, with no gradient ring: a plain `CircleAvatar` with initials on `primaryContainer`.
- **Suggested command**: `/impeccable colorize`

**[P1] Text-scale support is defeated by `FittedBox`, and orientation is locked**
- **Location**: `calendar_screen.dart:409-410, 469-480`; `calendar_screen.dart:293-301`; `analytics_screen.dart:483-492, 305-312`; `budgets_screen.dart:132-141`; `lib/main.dart:28`; `AndroidManifest.xml:13`
- **Category**: Adaptivity / Accessibility
- **Impact**: At 130–200 % system font size, `FittedBox(fit: BoxFit.scaleDown)` shrinks the amounts back down, so the user's setting is undone exactly where it matters (money). Portrait is forced in both Dart and the manifest, so landscape keyboards, tablets and foldables get a letterboxed phone UI, and Android 16 ignores the lock on large screens anyway, which leaves an untested layout.
- **Guideline**: Material: sp units follow the system font size; adapt layouts by window size class.
- **Recommendation**: Let amounts wrap or drop to a second line, using compact formats (`Money.compact`) as a *layout* decision at narrow widths rather than a scale-down. Remove the orientation lock, and add one `LayoutBuilder` breakpoint (≥600 dp: `NavigationRail` + two-column calendar/day list).
- **Suggested command**: `/impeccable adapt`

### P2 Minor

**[P2] The same KPI tile, four times over**
- **Location**: `calendar_screen.dart:241-320` (`_StatCard`), `analytics_screen.dart:427-500` (`_TotalTile`), `budgets_screen.dart:103-117`, `analytics_screen.dart:113-180` (`_Panel`, which duplicates `HeroCard`)
- **Category**: Theming (AI tell)
- **Impact**: Icon-in-circle + small label + big number, gradient tinted, in four private copies with different radii (16/18/20) and paddings. The icons (↙ ↗, wallet, receipt) repeat what the label and colour already say.
- **Recommendation**: One shared `StatTile` without the icon. Label in `labelMedium`, value in `titleLarge`, colour carried by the value text. On the calendar, a single row reading "Income ₹X · Spent ₹Y · ₹Z/day" would be calmer and more scannable than three cards.
- **Suggested command**: `/impeccable distill`

**[P2] Analytics shows income in the accent colour; everywhere else it's green**
- **Location**: `lib/features/analytics/analytics_screen.dart:63-66`
- **Category**: Theming
- **Impact**: "Total Income" uses `colorScheme.primary`, so with a Coral or Pink accent, income turns red-pink right next to "Total Expenses" in red. `FinanceColors` says income has "a fixed meaning, the same in every accent".
- **Recommendation**: `color: FinanceColors.income`.
- **Suggested command**: `/impeccable polish`

**[P2] Savings hero always shows a rising-trend icon, and negative amounts lose their sign**
- **Location**: `analytics_screen.dart:291-296, 308-311`; `budgets_screen.dart:136-140`
- **Category**: Accessibility / Clarity
- **Impact**: The icon is `trendingUpRounded` even when savings fell; only its colour changes, which colour-blind users can't read. "Overspent" and "over budget" show `saved.abs()` / `left.abs()`, so ₹4,000 overspent looks the same as ₹4,000 saved, apart from the label.
- **Recommendation**: Switch to `trendingDownRounded` when `!up`, and show a minus sign (`−₹4,000`) for negative values, as `top_bar.dart:126` already does.
- **Suggested command**: `/impeccable clarify`

**[P2] Hero card on Settings and Profile with a fake number**
- **Location**: `lib/features/settings/screens/settings_screen.dart:48-95`; `lib/features/account/screens/profile_screen.dart:53`
- **Category**: Conformance (AI tell)
- **Impact**: The accent "Preview" is a glowing hero with a made-up "₹24,500 saved this month". Settings is a task surface. A preview helps, but the hero styling and the invented figure make it feel like a marketing mock.
- **Recommendation**: Show the swatch row by itself (each swatch already previews live), or a small sample button + chip. Move Profile's hero to a plain `ListTile` header.
- **Suggested command**: `/impeccable distill`

**[P2] Template copy in the drawer and welcome screen**
- **Location**: `app_drawer.dart:160-187` ("Hello there" / "Good to see you again!"), `app_drawer.dart:344-397` (brand card "Track Your Finances. Live Better." + heart), `welcome_screen.dart:103-110` (`'TRACK  YOUR  FINANCES'` with double spaces and letter-spacing), `welcome_screen.dart:112-126` (three-feature list), `top_bar.dart:97-104` (`BALANCE` eyebrow), `calendar_screen.dart:499` (👋)
- **Category**: Clarity (AI tell)
- **Impact**: Generic warmth that every generated app has. The drawer spends its top third and its footer on greeting and slogan instead of navigation. Double spaces in a string fake letter-spacing, and screen readers read them out oddly.
- **Recommendation**: Drawer: name + email/sync status as a compact header, then destinations, version at the bottom. No brand card. Welcome: keep the wordmark; replace the three features with one sentence that only TYF could say (e.g. "Every rupee, on the day you spent it."), and drop the eyebrow. Use real `letterSpacing` rather than double spaces, if caps are kept at all.
- **Suggested command**: `/impeccable clarify`

**[P2] Wordmark uses an unbundled weight in the wrong family**
- **Location**: `lib/features/account/screens/welcome_screen.dart:241-246`
- **Category**: Theming
- **Impact**: The `TextStyle` has no `fontFamily`, so it inherits Inter, and `FontWeight.w900` isn't bundled (Inter ships 400–700, `pubspec.yaml`). Flutter synthesises a faux-bold. The brand's own mark ends up in the body face, faked, while the headline face (Manrope 800) sits unused.
- **Recommendation**: `fontFamily: 'Manrope', fontWeight: FontWeight.w800`, or start from `textTheme.displayLarge`.
- **Suggested command**: `/impeccable typeset`

**[P2] Small touch targets in the top bar and nav**
- **Location**: `top_bar.dart:135-158` (hide-balance eye, about 26 dp), `top_bar.dart:70` (balance pill `GestureDetector` with no semantics or ripple), `floating_nav_bar.dart:38-56` (`InkResponse` with no selected state)
- **Category**: Accessibility
- **Impact**: The eye toggle sits inside the balance pill's tap area, so a near miss opens Accounts instead of hiding the balance. The pill isn't announced as a button.
- **Recommendation**: Make the eye a 48 dp `IconButton` beside the pill, not inside it. Give the pill `InkWell` + `Semantics(button: true, label: 'Balance ₹X, open accounts')`.
- **Suggested command**: `/impeccable harden`

**[P2] History renders every row eagerly**
- **Location**: `lib/features/history/history_screen.dart:288, 379` (`ListView(children: [for (final (day, dayEntries) in groups) ...])`)
- **Category**: Performance
- **Impact**: A year of SMS-imported transactions builds hundreds of rows up front, along with `IntrinsicHeight` in analytics (`analytics_screen.dart:92`), which forces a double layout. Scrolling will jank on mid-range Android.
- **Recommendation**: `CustomScrollView` with one `SliverList.builder` per day group (or a flattened `ListView.builder` with header items). Replace `IntrinsicHeight` with fixed-height panels.
- **Suggested command**: `/impeccable optimize`

### P3 Polish

**[P3] Mixed icon sets**
- **Location**: `lib/features/settings/screens/settings_screen.dart:117-127` (Material `Icons.brightness_auto_rounded`, `light_mode`, `dark_mode`) vs Phosphor everywhere else (`app_icons.dart`)
- **Category**: Conformance
- **Recommendation**: Add `sun`, `moon` and `circleHalf` Phosphor entries to `AppIcons`. `app_icons.dart` also holds several duplicate aliases (`add`/`addRounded`, `chevronLeft`/`chevronLeftRounded`, `calendarMonth`/`calendarMonthRounded`) worth collapsing.
- **Suggested command**: `/impeccable polish`

**[P3] Comments describe a design that isn't there**
- **Location**: `app_theme.dart:44-46, 278-279, 334-336`; `calendar_screen.dart:240, 321`; `hero_card.dart:7-9, 22-23`; `round_icon_button.dart:5` vs `app_theme.dart:174-178`
- **Category**: Maintainability (AI tell)
- **Recommendation**: Delete or correct them when the token pass lands. Stale design comments mislead the next edit, human or AI.
- **Suggested command**: `/impeccable polish`

**[P3] Empty states use the stock icon-in-a-circle + emoji**
- **Location**: `lib/core/widgets/empty_state.dart:60-74`; callers `goals_view.dart:228` (🏁), `budgets_screen.dart:533` (🎯), `history_screen.dart:368` (🧾 / 🔍)
- **Category**: Theming
- **Recommendation**: Drop the 76 dp tinted circle. A Phosphor icon at 40 dp in `onSurfaceVariant`, or no icon at all, with copy that says what to do next. `bottomInset = 96` is a magic number that should come from `AppSpace.navBarClearance`.
- **Suggested command**: `/impeccable onboard`

---

## Patterns & Systemic Issues

- **Decoration as the design system.** Gradients (18), coloured `BoxShadow`s (13) and radial glows make up the visual identity. Take them away and there's no hierarchy left, because type scale and spacing were never asked to do that work.
- **Tokens declared, then ignored.** `AppSpace`/`AppRadius` exist, but there are 29 literal `fontSize:` values outside the theme, 47 raw hex colours in 14 files, and 14 distinct radii.
- **Private copies of shared components.** `_Panel` ≈ `HeroCard` ≈ `OptionPanel` ≈ `AppCard`; `_StatCard` ≈ `_TotalTile`; `_Ring` ≈ `GoalRing`. Each copy picks its own radius and alpha.
- **Accessibility treated as tooltips.** Only 5 `Semantics(` and 4 `semanticLabel` in the whole UI. Custom `GestureDetector`/`InkResponse` controls carry no roles.
- **Motion by default, never opt-out.** Every number and block animates on every visit, and nothing reads the system animation setting.

## Positive Findings

- **One icon source** (`app_icons.dart`), with Regular for idle and Fill for selected. Easy to keep consistent, and only three stray Material icons slipped through.
- **A real type pairing**: Manrope for numbers and titles, Inter for text, with tabular figures throughout (`app_theme.dart:359-396`). Amounts line up in lists. Keep this.
- **Sensible light-mode surfaces**: white cards with a hairline and a two-layer soft shadow (`surface.dart`) read as clean paper. That's a better base than the glows on top of it.
- **Thoughtful details**: a first-run hint instead of ₹0 cards (`calendar_screen.dart:483`), hide-balance remembered between launches, haptics on selection, `PopScope` on the welcome name step, and spending "heat" on calendar days, which is an idea that belongs to this app and could be its one signature visual.
- **Fixed finance colours** decoupled from the accent (`FinanceColors`); they just need contrast-safe text tones.

---

## Recommended Actions

1. **[P0] `/impeccable harden`**: Semantics on calendar day cells, balance pill and nav tabs; 48 dp eye toggle; contrast-safe text tones for income/expense; contrast-based `onPrimary`.
2. **[P1] `/impeccable quieter`**: Remove `AppBackground` glows, `HeroCard._Glow`, coloured shadows on hero/nav/FAB/tiles, and the drawer's violet gradients.
3. **[P1] `/impeccable adapt`**: M3 `NavigationBar` + standard FAB; `MaterialPageRoute` with predictive Back; drop the portrait lock; one ≥600 dp layout; replace `FittedBox` scale-downs with reflow.
4. **[P1] `/impeccable animate`**: Honour `disableAnimations`; stop counting money from zero; drop per-visit replays.
5. **[P1] `/impeccable document`**: Write DESIGN.md from what's worth keeping (type pairing, light surfaces, finance colours, heat map), fixing one radius ladder and a `FinancePalette` theme extension.
6. **[P2] `/impeccable distill`**: Merge `_StatCard`/`_TotalTile`/`_Panel`/`HeroCard` into one or two components without decorative icons; flat category tiles via `IconBadge`; remove hero cards from Settings and Profile.
7. **[P2] `/impeccable clarify`**: Drawer and welcome copy; signed negative amounts; correct trend icon; per-tab FAB tooltip.
8. **[P2] `/impeccable typeset`**: Wordmark in Manrope 800; replace literal `fontSize`s with text-theme roles.
9. **[P2] `/impeccable optimize`**: Sliver-based History list; remove `IntrinsicHeight`.
10. **[P3] `/impeccable polish`**: Phosphor icons in Settings, collapse icon aliases, fix stale comments, empty-state icon, and a final consistency pass.

You can ask me to run these one at a time, all at once, or in any order you prefer.

Re-run `/impeccable audit` after fixes to see your score improve.
