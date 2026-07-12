## v2.0.0 — downed-actor rework, prisoners, executions, follower slavery, creature pipeline overhaul

The biggest update to this mod since it started. Comparing against **v1.9.0** (the last stable
published release — v1.9.1 was an experimental pose-system drop): a full rework of how downed
actors are handled, an entire creature-encounter pipeline overhaul, a new tied-prisoner system,
executions, follower slavery, and a large reliability/performance pass.

## New: downed-victim actions are now first-class

The downed/defeated menu's options are no longer bundled behind one "Escalate" action — each is now
its own action the LLM can call directly and reason about individually:

- **PinHelpless, ChokeHelpless, GropeHelpless, FeelBreasts, FeelPrivates, KissHelpless** — acting on a
  helpless target, grouped under a new **Down** category.
- **HelpUp** — stand a downed actor back up (works whether they were downed by Baka itself or by an
  external system like Acheron Integration). Plays a real crouch-and-lift animation now (see Fixes).
- **Execute** — a defeated actor doesn't have to just lie there: a captor can finish them off
  directly. Also reachable from the interact/target menu as a guaranteed "Kill" button, independent
  of whether a weapon hit happens to land (see **Downed = vanilla mortality + executions** below).
- **TieUp** and **Untie** — bind a defeated victim as a long-term prisoner, or cut them loose (see
  **New: tied prisoners** below).
- **Capture** and **SellToSlavery** — take a defeated victim prisoner, or sell them off (see the new
  Simple Slavery Plus Plus requirement below).
- **EnslaveFollower** — hand a downed **follower** (not the player) off to the Follower Slavery Mod
  (see **New: follower slavery** below). Deliberately a separate action from `SellToSlavery` — the
  two target disjoint victims (player-only vs. follower-only) specifically so the LLM can't confuse
  them and misfire the wrong one.
- **CreatureEscalate** — a creature acting on a downed or vulnerable human, with its own struggle
  animation matched to the creature type, entirely independent of the LLM (creatures can't reliably
  choose actions on their own, so this runs as a direct Papyrus pipeline instead).
- **Escalate** — the action to force a downed/defeated victim into sex, kept distinct from `StartNewSex`
  in its description so the LLM doesn't confuse the two. Every cue and description was updated to match.

## New: tied prisoners

A captor can now **bind a defeated victim** instead of resolving the moment immediately — `TieUp`
leaves them helpless on the ground for an MCM-configured number of game hours (default 12), and
they cannot get up, struggle free, or auto-recover while bound. Only three things end a tie:

- **Untie** — someone cuts them loose. This isn't full freedom by itself: it drops them back to a
  *normal* downed state (fresh recovery timer, normal rules), not standing.
- **HelpUp** — the full liberation in one step: cuts the bindings *and* stands them up.
- **The bindings lapse on their own** after the configured duration, also dropping to a normal down.

Tied victims can still be escalated on (interrogation, ransom, or worse) and return to their bound
pose afterward — the pose survives struggles, scenes, and QTE losses via the same down-pose storage
HelpUp and recovery already use. Being bound doesn't grant safety, either: a tied prisoner is still
*defeated*, so the same weapon-hit execution rule below applies to them exactly as it would to any
other downed victim.

Two animation-reliability fixes landed alongside this: the binder/cutter now **sheathes their weapon**
before the kneel-down beat (the animation graph was silently rejecting the idle with a weapon drawn —
this was the cause of "no animation played" on Tie/Untie/HelpUp), and the **player is forced to
third-person** for the beat (idles never render on your own body in first-person, which read as "no
animation" for exactly the same reason). The tied pose itself deliberately uses **only base-game and
Baka Motion Data Pack animations** — an earlier build tried rolling a random ZaZ Animation Pack hogtie
pose when ZaZ was detected on disk, but a mod folder being present doesn't mean its animations are
built into the behavior graphs, and an unbuilt event T-poses the actor. Kept simple and reliable
instead.

## New: downed = vanilla mortality + executions

No artificial invulnerability while defeated: **any weapon-delivered hit** (melee, fists, arrows,
bolts — never spells or stray magic) on a defeated, non-essential actor is now a killing blow, same
as it would be on their feet. On top of the passive hit-based path, the **Execute** action (menu and
LLM) gives a guaranteed way to finish a downed victim without depending on a hit actually landing
and registering. Essential/protected actors are unaffected either way, and victims mid-struggle or
mid-scene are untouchable — every exit also carries a short post-escape mercy window so nobody gets
killed the instant protection drops.

## New: follower slavery, alongside player slavery

`SellToSlavery` (defeated **player** → Simple Slavery++) now has a follower counterpart:
**`EnslaveFollower`** hands a downed **follower** off to the Follower Slavery Mod (FSM) via its
documented `fsm_enslavefollower` mod event, offering the captor as the new master. Gated on FSM
actually being installed and initialized, an MCM toggle (**default OFF** — it permanently removes the
follower from the party until freed through FSM), and a rule that it can only happen while the player
is themselves downed or farther away than an MCM-configurable distance, so it can never trigger right
under your nose. The action is removed from the LLM's menu entirely whenever FSM is absent or the
toggle is off.

## Creature pipeline overhaul

The whole creature-encounter system got rebuilt on more reliable primitives:

- **Loaded-area discovery** (powerofthree's Papyrus Extender) replaces every ad-hoc cell sweep this
  mod used to run — creature scanning, follower/companion grouping, nearby-ally protection, all of it.
  po3 is now effectively a **core requirement**, not just a nice-to-have.
- **Struggle vs. escalate split** — a new **"Escalate to Sex After Win"** MCM toggle. OFF gives pure
  predator struggles: a beast mauling its prey in a QTE, no scene ever starts, no adult creature
  animation pack needed at all.
- **Group scenes** — up to two same-type companions can join a claimed victim (3v1 / 2v1), with an
  automatic fallback: 3 → 2 → pair, dropping companions one at a time until your installed animation
  library actually has a scene for that group size and creature type. A creature type with no usable
  pair animation at all gets a clean refusal and a 5-minute backoff instead of retrying every few
  seconds.
- **Optional LLM gate** — a strict yes/no prompt (`snbaka_escalation_gate.prompt`) SkyrimNet's model
  can be asked to answer before a downed-victim claim proceeds, so the narrator itself can pace when
  creature escalations are allowed to happen. Off by default; fails open (a slow/failed LLM call never
  blocks the encounter).
- **Already-downed victims get the full drawn-out struggle** instead of a shortcut resolution — a
  creature closing in on someone already beaten plays out the same as catching them fresh.
- **Escape is now genuine liberation.** Winning the struggle fully releases the victim: any Acheron
  hold is lifted, the calm effect is dispelled, and lover-rank relationship bonds the encounter set
  (including stale ones left over from an earlier failed rescue) are swept clean. The aggressor
  re-aggros after a short grace window instead of standing there confused.
- **Creature detection now checks the actual race**, not just the display name — a renamed or
  reskinned creature from another mod (e.g. a "Sewer Troll" that's still a Troll underneath) used to
  fall through undetected; it now also matches on race, falling back to the name check for anything
  that doesn't match a known one.
- **Skeleton-type guard** — actors that carry a creature skeleton (falmer, giants, draugr, etc., even
  though they're technically `ActorTypeNPC`) can never receive or be made to execute human paired
  actions; they're routed to the creature pipeline or excluded entirely, instead of silently T-posing
  through a human animation that doesn't fit their skeleton.

## New: NPC solo poses & body language, defeat-pose variety

*(Carried forward from the v1.9.1 experimental drop, now mainlined.)* A new **`SNBaka_Pose`** category
gives NPCs 15 solo poses SkyrimNet can use on its own — kneeling, sleeping, meditating, idle gestures,
an aroused idle, and more, several of which are women-only (a passed-out-drunk stupor, eating
reactions). Knocked-down victims also now collapse into one of several random defeat poses instead of
always the same one.

## Mid-scene actors are now off-limits everywhere

An actor already participating in a sex scene — from **any** mod, SexLab or OStim, not just one Baka
itself started — is now ineligible for paired animations, the interact power, and the get-up key
across the board. Previously this guard only covered scenes Baka knew it had started itself.

## Recovery, precisely

Getting up from a downed state happens via: someone **Helps you up**, or **winning a struggle QTE**.
There used to be a hidden time-based safety valve that stood a victim up after a few minutes
regardless of what was happening around them — including while their attacker was still standing
right there, mid-decision. That's gone. **A third path — an unattended auto-get-up timer, gated so it
never fires while anyone able-bodied is nearby — exists only when SkyrimNet Acheron Integration is
also installed**, since that's the mod that actually ticks the clock; Baka on its own only ever seeds
the timer's starting value for Acheron to pick up if present. Running Baka standalone, a downed victim
recovers only by being helped up or winning the struggle — nobody times out on their own.

## Works with Acheron Integration — but doesn't need it, and now shares a defeat all the way through

**SkyrimNet Acheron Integration is a separate, fully optional companion addon.** Baka Integration
handles its own QTE-based defeats and downed-state entirely by itself and works completely standalone.
When Acheron Integration is *also* installed, the two now coordinate far more tightly than before —
the **park design**: a victim who loses a struggle rides Acheron's protected defeat state seamlessly
through scene prep and the scene itself (an OSimpleDefeat-style handoff), instead of dropping through
an unprotected gap where an attacker could re-aggro mid-transition. NPC victims get a "keep-pacified"
rescue immediately before a scene starts, since OStim rejects actors Acheron still has marked
defeated. Acheron only lifts the hold at a genuine stand-up: a won struggle, HelpUp, the get-up key,
or an NPC's own auto-timer. Creature encounters still hand off between the two mods automatically, and
neither one requires the other.

## Performance pass

Per-tick sweeps and trace storms are gone — creature scanning, group companion handling, and nearby-
ally protection all moved to on-demand loaded-area lookups instead of running continuously. Every
`Debug.Trace` call (roughly 250 of them) now sits behind an MCM **Enable Debug Logging** toggle
(default reflects normal play; turn it on when reporting an issue), and corner-of-screen notifications
have their own separate toggle. Scene watchdogs are capped at 15 minutes so a stuck scene can't hang
forever. A fair amount of dead/unused code was found and deleted during an audit pass.

## Havok capsule fix tightened

Both actors' Havok bumper capsules already shrank during paired animations to stop partners physically
shoving each other out of alignment mid-pose (introduced earlier); the shrink factor is now tightened
from 15% to **5%** of vanilla size for a noticeably cleaner alignment. Cached per actor and restored
exactly afterward — never a shrink applied on top of an existing shrink.

## Fixes

- **`GetRelationshipRank` compile-stub signature fixed** — it was silently mismatched against the
  actual runtime signature, throwing an incompatible-arguments error for every loaded actor on every
  liberation and quietly breaking relationship-bond reverts without ever surfacing an obvious symptom.
- **Tie/Untie/HelpUp animations now actually play** — see the sheathe-weapon and first-person fixes
  under **New: tied prisoners** above; this was the root cause of several "no animation happened"
  reports across different actions, not just Tie/Untie.
- **Positioning drift** on paired takedowns when an actor moves slightly mid-sequence.
- **Downed actors can no longer initiate anything** — a beaten/pinned character won't suddenly act on
  someone else while down.
- **Post-scene re-aggro fixed for player victims** — an attacker used to resume full hostile combat
  almost immediately after a sex scene ended when the player was the victim (NPC victims were already
  protected).
- **Duplicate "downed" narration fixed.**
- **One downed actor no longer blocks another's recovery.**
- **Creature sex scenes fixed on both SexLab and OStim** — creature pairings now use the creature-aware
  animation search instead of the human-only one, which used to silently find nothing usable.
- **The get-up key is now ignored while an interaction owns the player** (struggle, scene, or menu
  action in progress) — it used to be usable mid-animation, letting you stand up out of a struggle you
  were actively supposed to be losing.
- Menu/positioning/QTE fixes carried over from the v1.9.1 experimental branch.

## New requirement: Simple Slavery Plus Plus

**`SellToSlavery` needs Simple Slavery Plus Plus (SS++) to actually do anything.** This mod hands off
to SS++ via its own "SSLV Entry" mod event; without SS++ installed, the action just narrates the
capture and nothing mechanical happens — no crash, no error, just no auction. Treat it as required if
you want that action to function. (The follower counterpart, `EnslaveFollower`, needs the separate
Follower Slavery Mod instead — see above.)

## Notes / known caveats

- Creature escalation success is still governed by Baka's own `iCreatureSuccessPct` chance roll — a
  creature can fail to act, especially against the player (real QTE instead of a dice roll). That's
  the intended difficulty knob, not a bug.
- Some poses need Nemesis specifically (Meditate, hand/head gestures, Sleep, Autograph, Pickpocket) —
  see the Baka Motion Data Pack's Nemesis patch.
- Executions currently rely primarily on the hit-detection path plus the guaranteed Execute button;
  if you find weapon hits on a defeated actor aren't registering as kills in your setup, use Execute
  as the reliable fallback and report the case.
- powerofthree's Papyrus Extender moved from a soft dependency to an effectively required one this
  release — the creature pipeline, group scenes, and nearby-ally protection all depend on its
  loaded-area actor enumeration.

## Install

- Install / overwrite with your mod manager, after the SexLab / SkyrimNet frameworks and the Baka
  Motion Data Pack.
- **Restart Skyrim once** — this version adds new action categories and updates the SkyrimNet action
  configs, both of which load at launch.
