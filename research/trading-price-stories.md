# How trading games make prices tell a story

Research for [#156](https://github.com/pkopczynski/lunar-lander/issues/156), under the map [#148 Commodities market](https://github.com/pkopczynski/lunar-lander/issues/148). It feeds three later decisions: **how market prices move**, **what the player knows about prices elsewhere**, and **market events and News**. Scope: mechanics that fit a small game with 4 trading places (the station, Valley, Mine, Metropolis) and about 5–7 Commodities.

Researched 2026-11-22. Each section names its sources and how far to trust them.

## Source reliability

| Game | Source | Trust |
|---|---|---|
| Elite (1984) | Mark Moxon's annotated disassembly of the original BBC Micro source ([bbcelite.com deep dive](https://elite.bbcelite.com/deep_dives/market_item_prices_and_availability.html)) | High: it reads the shipped code |
| Drug Wars (1984) | *dopewars*, Ben Webb's open-source remake ([src/dopewars.c](https://github.com/benmwebb/dopewars/blob/master/src/dopewars.c), [src/serverside.c](https://github.com/benmwebb/dopewars/blob/master/src/serverside.c)) | High for dopewars; it is a remake, not John E. Dell's original code, though it keeps the original's event messages and structure |
| Taipan! (1982) | Jay Link's C port of the Apple II game ([ebassett/taipan taipan.c](https://github.com/ebassett/taipan/blob/master/taipan.c)) | Medium-high: a port, but the numbers match the BASIC original as players know it |
| Offworld Trading Company (2016) | Soren Johnson's design doc "[Offworld Rules](https://mohawkgames.com/2014/06/16/offworld-rules/)" (Mohawk Games, 2014) | High for intent, but written two years before release; details may have changed |
| X4: Foundations (2018) | Egosoft's official manual, [Trading and Mining](https://wiki.egosoft.com/X4%20Foundations%20Wiki/Manual%20and%20Guides/X4%3A%20Foundations%20Manual/Trading%20And%20Mining/) | High |
| Elite Dangerous (2014–) | Frontier quote via [PC Gamer](https://www.pcgamer.com/elite-dangerouss-trading-systems-detailed-by-frontier/); otherwise Frontier forum threads (players) | Low-medium: Frontier never published the formulas; the official wiki/forum pages refused automated fetches, so community findings are reported as such |
| Patrician III / Port Royale | Player forum threads ([Steam](https://steamcommunity.com/app/33570/discussions/0/135507855755812062)) | Low: manuals could not be fetched; treat as player observation |

## 1. How prices move

Three families of models show up, from simplest to richest.

### A. Re-rolled on arrival, no memory (Elite 1984, Drug Wars, Taipan)

Prices are drawn fresh each time the player arrives. Nothing the player did before matters.

- **Elite**: `price = (base_price + (random AND mask) + economy × economic_factor) × 4`, and availability is `(base_quantity + (random AND mask) − economy × economic_factor) mod 64`. The random byte is rolled "each time we arrive in a new system". The **mask sets each commodity's volatility**: narcotics (mask `&78`) "will vary wildly in price, while food and textiles will be relatively stable" (food's mask is `&01`). The **economic factor** ties the price to a place's character: food (factor −2) is cheap in agricultural systems, computers dear there. ([bbcelite](https://elite.bbcelite.com/deep_dives/market_item_prices_and_availability.html))
- **Drug Wars**: each drug has a `MinPrice..MaxPrice` band; a location shows only a random subset of drugs (`MinDrug..MaxDrug`, so some places don't trade everything). Prices are a uniform pick inside the band. ([serverside.c `GenerateDrugsHere`](https://github.com/benmwebb/dopewars/blob/master/src/serverside.c))
- **Taipan**: `price = base_price[good][port] / 2 × (1..3) × base_price[good][0]`, so each port has a fixed bias per good (Opium is cheapest in one port, dearest in another) times a 0.5/1/1.5 roll, re-rolled on each arrival. ([taipan.c `set_prices`](https://github.com/ebassett/taipan/blob/master/taipan.c))

What works: a **per-place bias** makes geography matter ("buy food at the farm world") and a **per-commodity volatility** gives each good a personality (safe staple vs. gamble). What's missing: the market has no memory, so the player can't saturate it, and nothing persists to become a story.

### B. Stock drives price, the player's own trades move it (Offworld, X4, Patrician, Elite Dangerous)

The price is a function of a stock (or supply/demand level) that trades change and that drifts back.

- **Offworld**: "each time a resource is bought or sold, the price goes up or down accordingly", so buying 100 Food at $20 costs over $2 000. There is also a slow constant demand. ([Offworld Rules §8.1](https://mohawkgames.com/2014/06/16/offworld-rules/))
- **X4**: "Ware prices vary a lot depending on the quantity of the ware the station has in its reserves", within each ware's fixed min/max; menus "show the average price of a ware to give a trader an idea of how good a price is." ([X4 manual](https://wiki.egosoft.com/X4%20Foundations%20Wiki/Manual%20and%20Guides/X4%3A%20Foundations%20Manual/Trading%20And%20Mining/))
- **Patrician III** (players' account): a town consumes goods weekly; price is set by stock relative to consumption. With a big stock the price climbs slowly as you buy, then shoots up once stock nears about two weeks' consumption (beer went 36 → 38–39 slowly, then fast past 40); a town completely out of fish paid about 700. Buy and sell prices move together with a spread (the manual reportedly suggests ~10%). ([Steam thread](https://steamcommunity.com/app/33570/discussions/0/135507855755812062))
- **Elite Dangerous**: Frontier: "As in today's world, supply and demand drive prices" on a "server-based background trading simulation" ([PC Gamer](https://www.pcgamer.com/elite-dangerouss-trading-systems-detailed-by-frontier/)). Players observe that supply and demand have an equilibrium they return to gradually after trading (estimates of days), and that the "galactic average" is a fixed reference price per commodity from which station prices are computed (Frontier forum threads, unconfirmed by Frontier).

What works: **saturation is the player's own footprint**. Dumping a hold into one market visibly lowers its price, which pushes the player to spread sales, and the recovery makes a place "remember" the player for a while. A **reference/average price** shown beside the local one lets the player judge a deal at a glance.

### C. Prices moved by a world simulation (Elite Dangerous states, Patrician events)

Elite Dangerous layers faction states over markets: Boom raises supply of produced goods (community data: roughly +80% supply, often cheaper), Famine raises food prices, Outbreak raises medicine demand; states end after a while and the market returns. Players often drive these states themselves. (Frontier forum guides, low-medium trust.) Patrician's sieges and similar events shift what a town needs (player reports).

This is the richest story generator but too big for us: we have no factions or population to simulate.

## 2. Events: the moment a price becomes a story

Every one of these games makes the big swing **an announced event, with a reason in words**, not just a number.

- **Drug Wars**: on 70% of arrivals one drug gets a special price; 40% of those get a second, 5% of those a third. Each drug is marked as able to go `Cheap` (price ÷ 4) or `Expensive` (× 4), and each comes with a line: "The Marrakesh Express has arrived!" (cheap hashish), "Rival drug dealers raided a pharmacy and are selling cheap ludes!", "Cops made a big *X* bust! Prices are outrageous!", "Addicts are buying *X* at ridiculous prices!" ([dopewars.c](https://github.com/benmwebb/dopewars/blob/master/src/dopewars.c), [serverside.c](https://github.com/benmwebb/dopewars/blob/master/src/serverside.c))
- **Taipan**: on arrival, a 1-in-9 "Comprador's Report": "Taipan!! The price of Opium has dropped to …" (÷ 5) or "has risen to …" (× 5–9). ([taipan.c `good_prices`](https://github.com/ebassett/taipan/blob/master/taipan.c))
- **Offworld**: shortages and surpluses act on the market; a surplus works "as if someone sells units of the affected resource every second for 30 seconds" (fan wiki). Weather events (Dust Storm, Solar Flare) change *production*, and prices follow. Players can fake shortages and surpluses with the Hacker Array, and these "look the same as natural random events"; one HQ type learns of them early. ([Offworld Rules §7.6](https://mohawkgames.com/2014/06/16/offworld-rules/))
- **Elite Dangerous**: Galnet news and system states (Boom, Famine, Outbreak, War) explain why a market is odd, and they last days.

Patterns worth copying:

1. **Few, big, explained swings beat constant noise.** Drug Wars' ×4 / ÷4 and Taipan's ÷5 / ×5–9 are huge, rare and named. Normal prices only wobble inside a band, so the event stands out.
2. **The event names a cause in the world** (a freighter, a bust, a pharmacy raid). The cause is what turns a number into a story; the player retells "the Coast Guard got dusted, weed bottomed out".
3. **Commodities have a direction.** Drug Wars marks which drugs can crash and which can spike; a good's events fit its nature (staples glut, luxuries spike).
4. **Events act on the market, not on the price directly** (Offworld's surplus = simulated selling; Elite Dangerous states change supply/demand). The price then recovers through the normal model, so the event fades on its own instead of snapping back.
5. **Hearing early is an advantage** (Offworld's Scavenger HQ). News that arrives before the price moves creates a decision: act now on a rumour, or wait.

## 3. What the player knows about remote prices

| Game | Remote prices | Story effect |
|---|---|---|
| Elite 1984, Drug Wars, Taipan | None: you see prices only where you are. Elite shows each system's economy and government, so you **infer** prices from the place's character | Every arrival is a small reveal; risk and surprise |
| X4 | Only while a ship or satellite is near, or by buying a faction's Trade Subscription; known offers "become out of date over time" once the source stops ([manual](https://wiki.egosoft.com/X4%20Foundations%20Wiki/Manual%20and%20Guides/X4%3A%20Foundations%20Manual/Trading%20And%20Mining/)) | Information is a thing you build and pay for |
| Elite Dangerous | In-game galaxy map trade data mainly for visited systems; players lean on third-party sites fed by other players' uploads (forum threads) | Stale data is normal; arriving to find the price gone is a known disappointment |
| Offworld, Patrician | Offworld: one shared market, all visible. Patrician: price lists of other towns (player reports) | Full information shifts the game to timing and volume, not discovery |

Patterns:

1. **Last-seen prices, stamped with their age**, are the middle ground: the player remembers what they saw, but the market moves on. Elite Dangerous and X4 both show that stale data is itself tension.
2. **A place's character as a hint** (Elite's economy type, Taipan's per-port bias) gives the player something to reason with even without live prices.
3. **Paid or earned information** (X4's Trade Subscription, Offworld's early warning) is a natural upgrade. Our map already parks "market intel" as a later upgrade ([#157](https://github.com/pkopczynski/lunar-lander/issues/157)).

## 4. What makes price changes read as a story

Across the games, prices read as a story when:

- **Places have a character** that sets their normal prices (farm cheap food, mine cheap ore, city dear luxuries). Deviations from that character are news.
- **Each commodity has a temperament**: a stable staple and a volatile gamble, as Elite's masks and Drug Wars' Cheap/Expensive flags give.
- **Big changes are rare, named and caused**: an event with a line of text, a place and a commodity.
- **Changes persist and fade** rather than vanish on the next roll, so the player can plan a trip around one and see it end.
- **The player leaves a footprint**: selling a full hold lowers the price, and it climbs back over time.
- **Information lags**: the player acts on news or on what they last saw, and the arrival confirms or betrays it.

## What this suggests for our game

Initial assumptions for the later decision tickets, to be tuned by playtesting:

1. **Price = base × place bias × event modifiers × saturation, inside a band.** Each Commodity has a base price and a volatility; each of the 4 places a fixed bias per Commodity (Mine: ore cheap; Metropolis: food and luxuries dear; Valley: food cheap; the station: the hub, middling, maybe dear on fuel-like goods). Small random drift inside a narrow band keeps it alive, never large.
2. **Saturation from the player's own trades, recovering over time**: each unit bought raises that place's price, each unit sold lowers it (Offworld, X4), recovering toward normal over in-game time or trips. With 4 places and no NPC traders this is the only thing that stops one route being farmed forever.
3. **A buy/sell spread** (Patrician's ~10%) so a round trip in one place never profits.
4. **Market events from a hand-written pool**, each naming a cause, a place, one or two Commodities and a direction (glut or shortage), with a strong effect (×2–×4, like Drug Wars and Taipan) that fades over several trips. Give each Commodity a likely direction (staples glut, luxuries and medicine spike). Roughly one active event at a time keeps 4 places legible.
5. **Events act through the market, not by overwriting the price**: an event shifts the place's target, and the normal recovery fades it, so ending an event needs no special code path.
6. **News leads the price**: the News line appears on the Terminal when the event starts, possibly a trip before the effect peaks, so reading News is how a player profits. Chained events (map's "possibly chained") read like a story: a mine accident, then an ore shortage, then cheap ore when it reopens.
7. **Remote prices: last-seen, with age**, plus each place's known character. Live remote prices are an upgrade later ([#157](https://github.com/pkopczynski/lunar-lander/issues/157)). Since every trip passes the station, the station could show last-seen surface prices from the player's own visits.
8. **Avoid** Drug Wars-style full re-rolls on every arrival (no memory, no saturation) and Elite Dangerous-scale simulation (factions, states): both miss the scale of 4 places and 5–7 Commodities.
