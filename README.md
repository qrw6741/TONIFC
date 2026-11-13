# Prime Football 27 — Ultimate XI

A playable football game with a full Ultimate Team–style mode (**Ultimate XI**), built as a modular HTML5/JavaScript project (a Godot 4.3 version lives in `godot/`).

**Player database:** real players from Europe's top 5 leagues — Premier League, LaLiga, Serie A, Bundesliga and Ligue 1 (96 clubs, 2025/26 squads, ~1,780 players) plus 25 Icons and 14 Heroes (retired legends). Ratings are the developer's own estimates, not official game ratings. Squads reflect the 2025/26 season and may miss later transfers. Portraits are illustrated placeholders and club badges are original colour-matched designs, not official crests. Real names, clubs and leagues are trademarks of their owners — this is a personal, non-commercial project; don't sell or publicly distribute it without the relevant licences. Music and sound effects are synthesized in code, and there are no real-money transactions.

Card tiers: Bronze < 71, Silver 71–75, Gold 76+ (rare variants and special cards on top).

## Run it

**Easiest:** open `dist/index.html` in Chrome, Edge or Firefox (double-click it). It runs fully offline.

**From source (for development):**

```bash
node tools/build.mjs          # bundles src/ → dist/index.html (single self-contained file)
# or open src/dev.html to load the modules individually
```

Requirements: any modern desktop browser. Node.js 18+ is needed only to rebuild. Progress is saved automatically in the browser's local storage. Use **Settings → Export save** to back it up or move it to another PC.

## Controls

| Action | Keyboard | Controller |
|---|---|---|
| Move | WASD / Arrow keys | Left stick / D-pad |
| Sprint | Shift | RT |
| Short pass / header | J | A |
| Through ball | I | Y |
| Shoot (hold to charge power, ↑/↓ picks the corner) | K | X |
| Finesse shot (hold) | O | RB + X |
| Lob pass / cross | L | B |
| Skill move (with direction) | E | Right-stick flick |
| Standing tackle (defending) | J | B |
| Slide tackle (defending) | K | X |
| Switch player | Q | LB |
| Pause / substitutions / camera | Esc or P | Start |
| Hide controls overlay | H | — |
| **Menus:** navigate / select / back / switch tab | Arrows · Enter · Esc · Q/E | D-pad · A · B · LB/RB |

The mouse works in all menus. Drag and drop cards in the Squad Builder.

## Project structure

```
src/
  core/      util.js (RNG, DOM, modal) · save.js (versioned save system) · audio.js (synth music/SFX) · input.js (keyboard+gamepad, spatial nav)
  data/      world.js (nations, leagues, clubs, flags, crests) · players.js (deterministic DB generator, portraits, values)
  systems/   squad.js (formations, chemistry, squads, club) · economy.js (wallet, XP, packs + odds, transfer market)
             progression.js (objectives, SBCs, Rivals, Champions, Draft, Squad Battles rules)
  ui/        app.js (router, chrome) · components.js (cards, pitch, pickers) · background.js (animated stadium/clubhouse)
             menu.js (main menu, Kick Off, Career, Clubs, Tournaments, Settings, Customize, Profile)
             ut.js (Home, Objectives, Club, Squad Builder, Store, pack opening) · ut2.js (SBC, Transfers, Play + all modes, results)
  match/     engine.js (11v11 simulation, AI, set pieces, rules) · view.js (broadcast renderer, HUD, pause/subs)
  main.js · styles.css · index.html
tools/build.mjs   bundler → dist/index.html
```

Pack odds are configurable in `PACKS` (`systems/economy.js`) and shown in-game under **Store → Pack Odds**. Objectives, SBCs, difficulty levels and rewards are plain data tables in `systems/progression.js`.

## Completed features

- **Main menu:** animated 3D stadium with running players, floodlights, haze and a moving camera. Gold broadcast styling, synthesized music and SFX, keyboard/mouse/controller navigation, and an animated transition into Ultimate XI. Includes Kick Off, Career Mode, Clubs, Tournaments, Customize, Profile and Settings.
- **Ultimate XI hub:** Home (club overview, squad preview, promo cards, packs, objectives, competitions, balances, club level/XP), Objectives, Play, Club, SBC, Transfers and Store.
- **Player database:** ~1,780 real players across 96 clubs in the top 5 leagues, plus Icons, Heroes and special versions (TOTW, Nightfall, Foundations). Each card has a generated portrait, 6 stats (GK-specific labels for keepers), foot, height, skill moves, weak foot, work rates, age and alternate positions.
- **Card rarities:** Bronze, Silver and Gold (each with a rare variant), Team of the Week, Nightfall promo, Foundations, Heroes and Icons. Each has its own visual design.
- **Squad Builder:** 8 formations, drag-and-drop, click-to-swap (works on controller), captain, 7 substitutes, multiple squads with rename/delete/set active, auto-build and autosave.
- **Chemistry:** club, nation and league thresholds per player (0–3, max 33). Icons and Heroes have special rules, and out-of-position players get 0. Green/yellow/red link lines on the pitch.
- **Store:** 11 pack types plus 2 reward packs, with prices in coins or Prime Points. Guaranteed slots and weighted odds, with a transparent odds table. Cinematic opening with beams, sparks, and a walkout for big pulls (nation → position → club → rating). Afterwards: compare, Send to Club, Quick Sell, List on Market, and bulk actions for duplicates.
- **Economy:** coins and Prime Points (free fictional credits: a daily claim plus rewards). Purchase validation, full transaction history, 5% market tax and level-up rewards.
- **Transfer market:** search by name/position/league/nation/club/rating/rarity/max price, with sorting. Buy Now and bidding with coin escrow, outbid refunds and auction resolution. List your own tradeable players with an allowed price range; AI buyers and bidders act in real time. Remove/relist listings and view transfer history. Prices move with demand and a slow market cycle.
- **Objectives:** daily, weekly, season and milestone objectives, tracked automatically from gameplay events, with claimable rewards (coins, packs, players, XP).
- **SBCs:** 15 challenges in 4 categories. Requirement validation covers rating, chemistry, leagues, nations, rarity and tier. Includes auto-fill. Submitted cards are removed from the club, and challenges can be repeatable.
- **Game modes:**
  - **Squad Battles:** 8 weekly opponents, 7 difficulties, points and a weekly leaderboard with rank rewards.
  - **Division Rivals:** 10 divisions with promotion and relegation.
  - **Champions:** tickets, 10 matches and tiered rewards.
  - **Draft:** formation pick, captain, 5-choice picks, 4-round knockout and rewards.
  - **Friendlies:** Classic, Golden Goal, Long Shots (goals from outside the box count double), Headers & Volleys, and No Rules.
- **Football gameplay (11v11):**
  - **Ball physics:** height, bounce and curl.
  - **Player actions:** dribbling, sprinting with stamina, passes, through balls, lobs, crosses, power and finesse shots, headers, volleys and skill moves.
  - **Defending:** standing and slide tackles, fouls and yellow cards.
  - **Set pieces and restarts:** kick-offs, throw-ins, corners, goal kicks, free kicks with walls, and penalties (you aim, the keeper commits to a side).
  - **Goalkeeping:** positioning, rushing out, diving saves, catches and parries.
  - **Team play:** shape and pressing AI, plus player switching (manual and automatic).
  - **Presentation:** posts and crossbar, referee, crowd that reacts to play, goal celebrations, clock and scoreboard, minimap, and full match stats.
  - **Pause menu:** substitutions (5), camera switching, simulate the rest of the match, or forfeit.
- **Club management:** collection with search, filters and sort, duplicates, card inspector with full stats, comparison, club statistics and club history. Customize club name, badge, home/away kits, stadium name, seat colour, tifo and pitch pattern. These appear in your matches.
- **Persistence:** everything is saved, including club, balances, collection, squads, market, objectives, SBC progress, match history, competitions, career, tournaments and settings. Includes export/import and reset.

## Simplified / remaining features (architecture ready for expansion)

- **Online multiplayer:** Rivals and Champions opponents are AI squads simulated locally. Matches run through `runMatch(cfg)`, which takes two team descriptors, so a network layer can supply the second team later.
- **Career Mode** is a simplified 14-matchday league season. There are no transfers, youth, or contract management.
- **Clubs** is a club and squad explorer with friendlies, not online Pro Clubs.
- **Offside** is not implemented. There are no red cards, and refereeing is simplified.
- **Penalty shootouts** in knockout ties are resolved from shooter and keeper ratings rather than taken interactively. In-match penalties are fully playable.
- **Graphics** are 2.5D canvas (a broadcast-perspective camera with stylized animated players), not 3D models with motion capture.
- **Player portraits** are illustrated placeholders, not real likenesses; official photos and crests would need licences.
- **Not yet built:** Evolutions, player loans and consumables (fitness, chem styles) are natural next systems.
