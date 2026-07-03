## v2.0.0 — downed-actor rework, new actions, reliability pass

The biggest update to this mod since it started: a full rework of how downed actors are handled, a
round of new actions, a big reliability/bugfix pass, and a new companion-integration point. Comparing
against **v1.9.0** (the last stable published release — v1.9.1 was an experimental pose-system drop),
this release rolls that experimental work into the mainline and adds a great deal more on top.

## New: downed-victim actions are now first-class

The downed/defeated menu's options are no longer bundled behind one "Escalate" action — each is now
its own action the LLM can call directly and reason about individually:

- **PinHelpless, ChokeHelpless, GropeHelpless, FeelBreasts, FeelPrivates, KissHelpless** — acting on a
  helpless target, grouped under a new **Down** category.
- **HelpUp** — stand a downed actor back up (works whether they were downed by Baka itself or by an
  external system like Acheron Integration).
- **Capture** and **SellToSlavery** — take a defeated victim prisoner, or sell them off (see the new
  Simple Slavery Plus Plus requirement below).
- **CreatureEscalate** — a creature acting on a downed or vulnerable human, with its own struggle
  animation matched to the creature type, entirely independent of the LLM (creatures can't reliably
  choose actions on their own, so this runs as a direct Papyrus pipeline instead).
- **Escalate renamed to Rape** — same behavior, but the name no longer risks being confused with
  `StartNewSex` or read as ambiguous by the LLM. Every cue and description was updated to match.

## New: NPC solo poses & body language, defeat-pose variety

*(Carried forward from the v1.9.1 experimental drop, now mainlined.)* A new **`SNBaka_Pose`** category
gives NPCs 15 solo poses SkyrimNet can use on its own — kneeling, sleeping, meditating, idle gestures,
an aroused idle, and more, several of which are women-only (a passed-out-drunk stupor, eating
reactions). Knocked-down victims also now collapse into one of several random defeat poses instead of
always the same one.

## Recovery is now strictly 3 conditions, no exceptions

Getting up from being downed now happens **only** via: someone Helps you up, nobody's around for a
while, or you win the struggle. A hidden time-based safety valve used to also stand a victim up after
a few minutes regardless of what was happening around them — including while their attacker was still
standing right there, mid-decision. That's gone.

## Creature detection now checks the actual race, not just the name

Creature-aware behavior (escalation, animation selection) used to match purely on the actor's display
name. A renamed or reskinned creature from another mod (e.g. a "Sewer Troll" that's still a Troll
underneath) could fall through undetected. Detection now also checks the actor's actual race, falling
back to the name check for anything that doesn't match a known race.

## SexLab bridge isolated

All SexLab-specific script types now live in their own bridge script
(`Scripts/Source/SkyrimNet_BakaSL.psc`), so the mod loads and runs cleanly on an OStim-only setup with
no SexLab installed at all — no errors, just a clean no-op on the SexLab-specific paths.

## Fixes

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
- Menu/positioning/QTE fixes carried over from the v1.9.1 experimental branch.

## New requirement: Simple Slavery Plus Plus

**`SellToSlavery` needs Simple Slavery Plus Plus (SS++) to actually do anything.** This mod hands off
to SS++ via its own "SSLV Entry" mod event; without SS++ installed, the action just narrates the
capture and nothing mechanical happens — no crash, no error, just no auction. Treat it as required if
you want that action to function.

## Works with Acheron Integration — but doesn't need it

**SkyrimNet Acheron Integration is a separate, fully optional companion addon.** Baka Integration
handles its own QTE-based defeats and downed-state entirely by itself and works completely standalone.
If Acheron Integration is *also* installed, the two coordinate: Acheron's own combat-defeat handling
delegates to Baka's downed actions, and — new this release — when Acheron's recovery timer is about to
free a victim because only a creature is left nearby, it now gives Baka's creature-escalation pipeline
one extra chance to act first instead of just letting them up. Neither mod requires the other.

## Notes / known caveats

- Creature escalation success is still governed by Baka's own `iCreatureSuccessPct` chance roll — a
  creature can fail to act, especially against the player (real QTE instead of a dice roll). That's
  the intended difficulty knob, not a bug.
- Some poses need Nemesis specifically (Meditate, hand/head gestures, Sleep, Autograph, Pickpocket) —
  see the Baka Motion Data Pack's Nemesis patch.

## Install

- Install / overwrite with your mod manager, after the SexLab / SkyrimNet frameworks and the Baka
  Motion Data Pack.
- **Restart Skyrim once** — this version adds new action categories and updates the SkyrimNet action
  configs, both of which load at launch.
