## v1.9.2 — reliability & recovery-rules pass

A focused bugfix/reliability release: no new action categories, just a set of fixes to how downed
actors recover, how creatures get recognized, and a couple of positioning/state bugs that could break
immersion mid-scene.

## Recovery is now strictly 3 conditions, no exceptions

Getting up from being downed now happens **only** via: someone Helps you up, nobody's around for a
while, or you win the struggle. A hidden time-based safety valve used to also stand a victim up after
a few minutes regardless of what was happening around them — including while their attacker was still
standing right there, mid-decision. That's gone. If nothing ever resolves the encounter and someone
stays nearby, the victim now stays down for real, the way it's supposed to.

## Creature detection now checks the actual race, not just the name

Creature-aware behavior (escalation, animation selection) used to match purely on the actor's display
name (e.g. looking for "Troll" in "Frost Troll"). A renamed or reskinned creature from another mod
(e.g. a "Sewer Troll" that's still a Troll underneath) could fall through undetected. Detection now
also checks the actor's actual race, so it recognizes the creature by its real skeleton regardless of
what its display name says, falling back to the name check for anything that doesn't match a known
race.

## Fixes

- **Positioning drift**: paired takedown positioning no longer drifts off if an actor moves slightly
  mid-sequence — both participants' final position is now read fresh right before locking them in
  place, instead of reusing a stale position from a moment earlier.
- **Downed actors can no longer initiate anything.** A beaten/pinned character won't suddenly grope,
  choke, or otherwise act on someone else while down.
- **Post-scene re-aggro fixed for player victims.** An attacker used to resume full hostile combat
  almost immediately after a sex scene ended — this protection already existed for NPC victims, it now
  also applies when the player was the victim.
- **Duplicate "downed" narration fixed** — the "X is down" cue no longer fires twice for the same
  event.
- **One downed actor no longer blocks another's recovery.** Multiple defeated actors near each other
  no longer count each other as "someone's still here."
- **Creature sex scenes fixed for both backends.** Creature pairings on SexLab and OStim now use the
  creature-aware animation search instead of the human-only one, which used to silently return nothing
  usable for a creature partner and made scenes fail to start.

## Works with Acheron Integration

This release integrates more closely with **SkyrimNet Acheron Integration**: when Acheron's downed-
state system is about to free a victim because the area cleared out except for a lingering creature,
it now gives this mod's own creature-escalation pipeline (the same non-LLM struggle-then-scene flow
used everywhere else) one extra chance to act on that victim first, instead of just calming the
creature and standing them up. This is controlled from **Acheron Integration's own MCM** ("Creature
Pounce On Recovery"), not this mod's — Baka's own creature-escalation switches (`Enable Creature
Escalation`, `Can Target the Player`) still fully gate whether anything happens either way.

Acheron Integration is optional — everything above (recovery rules, creature detection, the other
fixes) works with or without it installed. The extra handoff behavior specifically needs a recent
Acheron Integration build with a matching fix on its side; older versions will just skip it silently.

## Notes / known caveats

- Creature escalation success is still governed by Baka's own `iCreatureSuccessPct` chance roll in the
  MCM — a creature can still just fail to act, especially against the player (who gets a real QTE
  instead of a dice roll). That's the intended difficulty knob, not a bug.
- When a lingering creature is calmed instead of escalating, that uses vanilla Skyrim's Calm spell,
  which only affects targets up to level 8 — it will not pacify something like a giant or troll, so
  standing up doesn't mean it's safe to stick around.

## Install

- Install / overwrite with your mod manager, after the SexLab / SkyrimNet frameworks and the Baka
  Motion Data Pack, same as before.
- No DLL or action-config changes in this release — a save reload is enough, no full Skyrim restart
  needed.
