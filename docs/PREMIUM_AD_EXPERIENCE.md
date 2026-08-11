# Premium Ad Experience Specification

## Goal

Monetize without interrupting combat or making ads the primary progression system. The player must always choose rewarded ads, understand the reward before watching, and be able to progress without ads.

## Core principles

- Never show an ad during combat, the tutorial, an active revive flow, app exit, or immediately after app launch.
- Rewarded ads are opt-in and must state the exact reward before the player taps.
- Ads accelerate progress; they must not be required to unlock normal progression.
- One rewarded completion grants one reward. Never grant a reward from both a client callback and a server callback.
- Persist counters and cooldowns. Also configure server-side AdMob frequency caps.
- Keep banners outside gameplay and hide them when any full-screen UI or full-screen ad is active.

## Placement rules

### Rewarded revive

- Offer only after a genuine player death.
- Limit: one ad revive per level. Keep the existing crystal revive as an alternative.
- Reward: one life, short invulnerability, and no reset of earned level rewards.
- Do not show an interstitial after death, whether or not the player declines revive.

### Double mission rewards

- Offer once after a completed level, on the results screen.
- Reward: double only the unclaimed mission reward displayed on that screen.
- Do not allow it after the player has left the results screen or already collected the reward.
- This should be the highest-priority rewarded placement because the value is clear and the timing is a natural break.

### Shop currency offers

- Show only when the player cannot afford the currently selected upgrade.
- Reward: 30-50% of the next upgrade's coin cost, rounded to a clean value.
- Do not use a fixed reward equal to a full upgrade cost.
- Cap: 3-5 watches per day across all shop currency offers.
- Prefer a visible "Watch ad for +X coins" button over a generic ad button.

### Fortune wheel

- Give one free daily spin.
- Offer 1-3 rewarded spins per day after the free spin is used.
- Display the possible reward range before the player watches.
- Do not combine a wheel reward with another automatic ad immediately afterwards.

### Interstitials

- Optional at natural transitions only: after every 2-3 completed missions, never after a failed mission.
- Initial cap: maximum two per 30 minutes and four per day.
- Never show on app launch, app exit, tutorial flow, map opening, shop opening, or before a level begins.
- If the player watched a rewarded ad in the previous two minutes, suppress the interstitial.

### Banners

- Allowed only on passive screens such as map, shop, and menus.
- Hide in gameplay, game-over revive UI, level-complete double-reward UI, wheel UI, tutorial overlays, and every full-screen ad.

## Reward economy safeguards

- Keep ad rewards below the value of direct premium-currency purchases.
- Do not give both crystals and void shards for a basic shop-currency ad unless the economy explicitly supports that bundle.
- Tune rewards from data, not assumptions. Start with conservative rewards and raise them only if offer acceptance is too low.
- Maintain separate reward definitions for `revive`, `level_double`, `shop_coins`, `shop_crystals`, and `wheel_spin`.

## Frequency and cooldown configuration

Use two layers of protection:

1. Local persisted counters for immediate UI feedback and offline behavior.
2. AdMob app-level and ad-unit-level frequency caps for server-side enforcement.

Suggested initial limits:

| Placement | Limit |
| --- | --- |
| Ad revive | 1 per level |
| Double rewards | 1 per completed level |
| Shop ads | 3-5 per day |
| Wheel ads | 1-3 per day |
| Interstitials | 2 per 30 min, 4 per day |

## Analytics requirements

Track a unique event for every step in each placement funnel:

- `ad_offer_shown` with `placement`, `reward_type`, and `reward_amount`
- `ad_offer_tapped`
- `ad_load_failed` with an error code
- `ad_started`
- `ad_completed`
- `ad_reward_granted`
- `ad_dismissed_without_reward`
- `post_reward_action` such as upgrade purchased, level retried, or wheel spun

Review weekly by placement:

- offer-to-tap rate
- completion rate
- reward-grant failure rate
- revenue per daily active user
- retention after ad exposure
- upgrade or revive conversion after a reward

Disable or reduce any placement that materially lowers retention, produces repeated load failures, or feels disruptive.

## Reward integrity

- Client callbacks are acceptable during early development.
- Before launch with accounts, cloud saves, premium currency, or competitive progression, validate rewarded completions with AdMob Server-Side Verification.
- A server must treat AdMob's transaction identifier as idempotent so retries never grant duplicate rewards.
- Store the placement, reward type, user identifier, timestamp, and transaction identifier with every granted reward.

## AI implementation constraints

When changing the ad system, an AI must:

1. Preserve explicit player consent for every rewarded ad.
2. Never add interstitials to combat, tutorial, app launch, app exit, death, or a rewarded-ad follow-up.
3. Keep caps configurable instead of hard-coding them in UI scripts.
4. Separate reward-grant logic from UI presentation.
5. Prevent duplicate rewards with a request nonce or transaction identifier.
6. Show a clear loading/failure state and re-enable the offer when loading fails.
7. Add analytics events for every new placement.
8. Test offline, ad-load failure, ad dismissal, duplicate callback, scene transition, and app-resume cases.

## Sources

- Google AdMob: [Rewarded ads](https://support.google.com/admob/answer/7372450?hl=en)
- Google AdMob: [Frequency caps](https://support.google.com/admob/answer/6244508?hl=en)
- Google AdMob: [Interstitial guidance](https://support.google.com/admob/answer/6066980?hl=en)
- Google AdMob: [Server-side verification](https://developers.google.com/admob/android/ssv?authuser=2)
