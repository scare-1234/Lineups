# LineupLab

Browse real club and international football matches, read confirmed lineups with
per-player match ratings, nationalities and ages — and build fully customisable dream XIs
from any player in the API-Football database.

The repository holds two native apps that share the same design, data source and logic:

| App | Where it lives | Platform | Build it with |
| --- | --- | --- | --- |
| **LineupLab for Windows** | [`desktop/`](desktop/) | Windows 10/11 desktop | Node.js — [setup guide](desktop/README.md) |
| **LineupLab for iOS** | [`LineupLab/`](LineupLab/) | iOS 17+ | Xcode 16 (a Mac is required) |

**Want an app you can click on from your desktop?** Follow
[`desktop/README.md`](desktop/README.md) — `npm install && npm run dist:win` produces an
installer that puts LineupLab on your desktop and in the Start menu.

The rest of this file documents the iOS app.

---

# LineupLab for iOS

- **Platform:** iOS 17.0+
- **Tooling:** Xcode 16, SwiftUI, Swift Package Manager (no third-party dependencies)
- **Architecture:** MVVM + repository, `async/await` everywhere, `@Observable` view models

---

## 1. Getting started

```bash
git clone https://github.com/scare-1234/Lineups.git
cd Lineups
cp Config/Configuration.example.plist LineupLab/Resources/Configuration.plist
open LineupLab.xcodeproj
```

Then paste your API key into `LineupLab/Resources/Configuration.plist`:

```xml
<key>APIFootballKey</key>
<string>PASTE_YOUR_KEY_HERE</string>
```

Get a free key (100 requests/day) at <https://dashboard.api-football.com/register>.

`LineupLab/Resources/Configuration.plist` is listed in `.gitignore`, so the key never
gets committed. **No API key is ever hardcoded in Swift source.** For CI, set the
`API_FOOTBALL_KEY` environment variable instead — it takes precedence over the plist.

Without a key the app still launches and every screen shows setup instructions rather
than a crash or an empty screen.

Build and test from the command line:

```bash
xcodebuild -project LineupLab.xcodeproj -scheme LineupLab \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test
```

The Xcode project uses Xcode 16 file-system synchronized groups, so adding a file to a
folder adds it to the target automatically. `project.yml` is a fallback that regenerates
the same project with [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`xcodegen generate`)
if the project file is ever damaged.

---

## 2. Features

### Matches (tab 1)
- Horizontally scrolling date strip: seven days back, today, seven days forward.
- League filter chips: All, Premier League, La Liga, Serie A, Bundesliga, Ligue 1,
  Champions League, World Cup, International.
- Fixtures grouped by league with crest, score or kick-off time, venue and a status
  badge — including a pulsing red dot while a match is live.
- Pull to refresh.

### Match detail
Four tabs, with **Lineups** first:

| Tab | Contents |
| --- | --- |
| Lineups | Both formations, both starting elevens on one pitch positioned from the API `grid` coordinates, colour-coded rating badges, substitutes with ratings, coach |
| Stats | Possession split bar plus shots, shots on target, corners, fouls, cards, offsides and pass accuracy |
| Events | Chronological timeline of goals ⚽️, cards 🟨🟥 and substitutions 🔄 |
| Info | Referee, venue, city, round, season and status |

Tapping any player opens the player sheet.

### Player detail (sheet)
Large photo, full name, **nationality flag + country the player represents**, **age**,
position, height, weight, club, the **latest match rating** in colour, season stats
(appearances, goals, assists, minutes, average rating) and the per-match statistics for
the fixture you came from. "Add to Custom Lineup" jumps straight into the builder with
that player ready to place.

### Lineup builder (tab 2)
1. **Choose a formation** — 4-3-3, 4-4-2, 4-2-3-1, 3-5-2, 3-4-3, 5-3-2, 4-1-4-1, 4-5-1,
   each with a mini-pitch preview. The formation can be changed at any time and players
   are re-assigned to the nearest compatible slot; anyone who no longer fits is kept in
   an "unplaced" strip rather than being dropped.
2. **Fill positions** — tap an empty slot (labelled GK, LB, LCB, CAM, ST…) to open the
   player picker.
3. **Player picker** — searches `/players?search=` across the entire database: any
   player, any league, any nationality. Filter by position, nationality and minimum
   rating. Quick Fill auto-fills the remaining slots with the highest-rated compatible
   players discovered in this session.
4. **Customise** — drag and drop players between slots to swap them, or tap/long-press a
   filled slot for Replace, Remove and View Player Details.
5. **Save** — name it, and it is stored in Core Data. Saved lineups show a mini-pitch
   preview, swipe to delete, duplicate from the context menu, and share as a rendered
   image.

Each lineup shows its average rating, total age, average age and nationality breakdown
(for example "5 Brazil, 3 France").

### International (tab 3)
World Cup, Euro, Copa América, AFCON, Asian Cup, Nations League, World Cup qualifiers
and friendlies, with recent fixtures per competition and national team squads by country
(each player with age, club and rating).

---

## 3. Project layout

```
LineupLab/
├── App/            LineupLabApp, AppConfig (API key loading), AppContainer (composition root)
├── Models/         Player, Team, Fixture, League, Lineup, CustomLineup, Standing
├── Services/       APIClient (generic networking), FootballAPIService (+ DTOs), CacheManager
├── ViewModels/     MatchList, MatchDetail, PlayerSearch, LineupBuilder, PlayerDetail, International
├── Views/          Matches/, Lineups/, Builder/, International/, Players/, Components/
├── Persistence/    CoreDataStack, managed objects, CustomLineupStore
├── Utilities/      FormationParser, NationalityFlag, RatingScale, Theme, Strings, Haptics, dates
└── Resources/      Assets, Configuration.plist (gitignored)
LineupLabTests/     Decoding, formation, rating, flag, validation, client and view-model tests
Config/             Info.plist and Configuration.example.plist
```

---

## 4. API integration

Base URL `https://v3.football.api-sports.io`, authenticated with the
`x-apisports-key` header.

| Endpoint | Used for |
| --- | --- |
| `GET /fixtures?date=` | Match list |
| `GET /fixtures?id=` | Single fixture |
| `GET /fixtures?league=&season=&last=` | Recent international fixtures |
| `GET /fixtures/lineups?fixture=` | Formations, starting XI, substitutes, grid positions |
| `GET /fixtures/players?fixture=` | **`games.rating`** and the full per-player match statistics |
| `GET /fixtures/events?fixture=` | Events timeline |
| `GET /fixtures/statistics?fixture=` | Team match statistics |
| `GET /players?id=&season=` | Profile: **age**, **nationality**, photo, height, weight, season stats |
| `GET /players?search=&season=` | Player search for the builder (4+ characters) |
| `GET /players/squads?team=` | National team squads |
| `GET /leagues?id=&season=` | League metadata |
| `GET /standings?league=&season=` | League tables |
| `GET /teams?country=` | National teams for a country |

### Living inside 100 requests a day

`APIClient` is built around the free tier:

- **Freshness-aware cache.** Live data (fixtures, lineups, in-match stats) is reused for
  5 minutes; player profiles, leagues and standings for 24 hours. A fresh cache hit never
  touches the network, so it costs no quota.
- **`URLCache`** is configured on the session (32 MB memory / 256 MB disk) for HTTP-level
  revalidation, alongside LineupLab's own TTL store.
- **429 handling.** Retries with exponential backoff (honouring `Retry-After`), then
  serves the cached copy behind a "Daily limit reached. Cached data shown." banner.
- **Offline.** Falls back to cached data with an "Offline" banner; Core Data keeps the
  last fetched fixtures and player profiles as a second layer.
- **Client-side filtering.** The league chips filter a single day's response rather than
  issuing one request per league.
- **API quirks handled:** `errors` arrives as `[]` *or* as a dictionary; numbers arrive as
  `85`, `"85"` or `null`; the season stats field really is spelled `appearences`.

Error mapping: 401/403 and a `token` error payload become "set up your API key" with
instructions, 429 becomes the rate-limit banner, connectivity errors become the offline
banner, and anything else gets a retry button.

---

## 5. Design

Dark-mode first, light mode fully supported; every colour is dynamic.

| Token | Dark | Light |
| --- | --- | --- |
| Primary | `#1B5E20` | `#1B5E20` |
| Accent | `#00C853` | `#00C853` |
| Background | `#121212` | `#F5F5F5` |
| Card | `#1E1E1E` | `#FFFFFF` |
| Pitch | `#2E7D32` with white markings and a subtle gradient | same |

Rating colours: 9.0+ dark green · 8.0–8.9 green · 7.0–7.9 light green · 6.0–6.9 yellow ·
5.0–5.9 orange · below 5.0 red · missing "—" in grey.

Type uses the semantic text styles (large title 34 / title 22 / body 17 / caption 12) so
Dynamic Type works everywhere. Loading states are shimmer skeletons rather than spinners,
empty states use `ContentUnavailableView`, slot changes animate with springs, and player
selection fires `.impact(.medium)` haptics. Interactive elements carry VoiceOver labels
and values (a pitch token reads out the player's name and rating).

Every user-facing string goes through `L10n` in `Utilities/Strings.swift` using
`String(localized:)`, so the app is ready for localisation and has no scattered literals.

---

## 6. Persistence

Core Data (`CoreDataStack`) with a model defined in code — reviewable in a diff and free
of codegen ambiguity — plus automatic lightweight migration, background contexts for
writes, the main context for reads and `NSMergeByPropertyObjectTrumpMergePolicy`.

Entities: `CustomLineup`, `CustomLineupPlayer`, `FavoriteTeam`, `CachedPlayer`,
`CachedFixture`.

---

## 7. Tests

`LineupLabTests` covers the logic that is easy to get wrong:

- **Decoding** against sample payloads shaped like real API responses: fixtures, lineups,
  per-player ratings, player profiles, events, statistics, both shapes of `errors`, and
  the loose number/string primitives.
- **`FormationParser`**: all eight formations, slot labels and uniqueness, grid parsing,
  pitch coordinates, re-assignment when the formation changes, best-slot selection.
- **`RatingScale`**: every tier boundary, colour mapping, "—" for missing ratings, averages.
- **`NationalityFlag`**: flags, aliases, diacritics, the home-nation subdivision flags and
  `nil` for unknown countries.
- **`CustomLineupValidator`**: duplicate players, wrong player count, unknown or duplicate
  slots, missing names, squad statistics.
- **`APIClient`** with a `URLProtocol` stub: 401, 404, 429 retry-then-cache, offline
  fallback, service error payloads and the fresh-cache-skips-the-network guarantee.
- **View models**: match list grouping and filtering, banners, builder assignment rules,
  drag-to-swap, Quick Fill, formation changes and saving to an in-memory Core Data stack.

---

## 8. Notes and limitations

- Quick Fill draws from the players discovered during the current session (the pool grows
  with every search); with an empty pool it opens the search sheet instead. API-Football
  has no "top rated players" endpoint, and scanning leagues for one would burn the daily
  quota in a single tap.
- The Info tab shows referee, venue, city, round, season and status. Attendance and
  weather are not part of the API-Football v3 fixtures payload, so they are not shown.
- Player search requires at least four characters — an API-Football rule, surfaced in the
  UI as a hint rather than an error.
- Ratings only exist once a match is under way; before kick-off the app shows "—" and
  explains that lineups appear roughly an hour before kick-off.
