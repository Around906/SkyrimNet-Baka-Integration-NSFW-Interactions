## v2.0.2 — PinHelpless/Struggle dispatch fix, new categories, event-driven bleedout detection

## Fixed: PinHelpless and Struggle silently failing for LLM/NPC-initiated calls

SkyrimNet's action dispatcher validates the YAML `parameterMapping` count against the target
Papyrus function's *total* parameter count — it doesn't know about Papyrus default values the way a
direct script-to-script call does. `Struggle_Execute(Actor akInitiator, Actor akTarget, Bool
abFromHit = False)` has 3 parameters; both `down_pin.yaml` (**PinHelpless**) and `struggle.yaml`
(**Struggle**) only declared 2. Every LLM/NPC-initiated call to either action was silently rejected
at dispatch (`Parameter mapping count (2) doesn't match function parameter count (3)`) — invisible
from the player's own menu, since that calls the function directly in Papyrus, bypassing SkyrimNet's
dispatcher entirely.

Fixed with a dedicated 2-parameter wrapper, `PinHelpless_Execute`, that both YAML actions now point
at — exact signature match, no dependency on undocumented YAML "constant parameter" syntax.

## New: SNBaka_Pose and SNBaka_Creature categories

Two of Baka's nine action categories were referenced by an action (`Pose`, `CreatureEscalate`) but
never actually defined anywhere — DLL or YAML — meaning the LLM was seeing category-less orphaned
entries for both. Both are now properly registered:

- **`SNBaka_Pose`** — DLL-native (matching six of the other eight categories), covering solo body
  poses/gestures with no target and no physical contact. Also the shared home for
  **SkyrimNet_AnimationsGS**'s 12 GSPoser pose actions (Dance, Seduce, Stretch, and so on) — one
  registration, referenced by two mods, same "hold a solo pose" concept regardless of which
  animation backend actually plays it.
- **`SNBaka_Creature`** — YAML-defined (`cat_snbaka_creature.yaml`), deliberately combat-permissive
  like `SNBaka_Downed` — `CreatureEscalate`'s own description explicitly covers a victim "mid-fight,
  clearly losing," so a DLL category-level combat gate would have hidden it exactly when it's
  supposed to apply.

Also tightened the `SNBaka_Display` and `SNBaka_Pose` descriptions, which had drifted into
overlapping language ("pose," "show off," "strut" in both) once Pose was properly defined —
category descriptions are shown to the LLM at category-selection time, before it ever sees the
actions inside, so ambiguous wording there costs real accuracy. Display is now anchored on "a beat
performed for a watching target" (both its member actions are paired); Pose is anchored on "solo, no
target, held until stopped" — each description now explicitly points at the other for the case it
doesn't cover.

## New: event-driven untracked-bleedout detection (native)

Not a Baka-visible feature by itself, but ships in this DLL: `HitEventSink.cpp` already detects the
vanilla bleedout life-state synchronously on every hit (zero lag) for the execution feature. That
detection is now also forwarded as a `SNBaka_ActorBleedingOut` mod event the instant it fires — a
companion mod (Acheron Integration) can use this to adopt an untracked bleedout immediately instead
of waiting on a several-second poll, closing a race where a fast bleedout-then-vanilla-recovery
cycle could complete unseen. A no-op with no listener registered, so this ships safely regardless of
which version of the companion mod (or whether it's installed at all) is present.

## Notes

- No new hard requirements. Restart Skyrim once so SkyrimNet picks up the corrected action configs
  and the new category registrations.
