## v2.0.1 — downed-victim menu merged, ground-window interact fix, QTE-fallback fix

A small follow-up to v2.0.0: one real bug fix and one menu simplification, both found and fixed
from live-testing reports.

## Fixed: interact power refusing a downed victim forever ("NPC is busy")

When you win a struggle, the victim intentionally goes into a "ground window" — pinned, locked on
purpose, waiting for the aggressor to decide Escalate / HelpUp / Release / Execute / Tie Up. A hard
guard added in v2.0.0 (meant to stop the interact power from yanking apart an actively-*playing*
animation) checked only "is this actor locked," with no exception for that deliberate pinned state
— so it refused to even open the downed menu, reading as the NPC being permanently busy with
nothing able to clear it. Most noticeable running **without** the AEL Struggle QTE addon or Acheron
Integration installed, since a struggle you initiate then always resolves as a win rather than a
coinflip, so every struggle hit this.

Fix: the interact power now reuses the same ground-window-owner carve-out `LockBoth` already used
internally — a locked **sex scene** still always blocks (you shouldn't interrupt a running scene),
but a locked **ground window** now lets the aggressor who actually owns it back in. A third party
trying to butt in still gets refused.

## New: downed-victim menu merged with the regular interact menu

Pressing the interact power on a downed victim used to open a completely separate, smaller menu
(Escalate/HelpUp/etc. only) — the *only* way to reach grope/struggle/spank-type actions on a downed
target was through the LLM, not the player's own menu. Both menus are now **one menu**: a **"Down"
tab shown first** (Choke Down, Investigate, Inspect, Stand Back, Help Up, Execute, Tie Up, Untie —
unchanged), followed by the same Affection / Forced / Sexual tabs used for a standing target. From
any downed actor, any action is now reachable in one place. Nothing changes for a target that isn't
downed — same menu as always.

## Fixed: grope-type holds without the QTE addon always read as "resisted"

A few actions (`BackHugMolest` and similar) use a different resist-fallback path than
Struggle/ChokeHug. Without AEL Struggle installed, that path ran the timed hold correctly but never
flagged the outcome as a defeat even when the hold completed uninterrupted — so those specific
actions always resolved as "the victim broke free," regardless of what actually happened. Now a
completed, uninterrupted hold correctly counts as a defeat, same as Struggle/ChokeHug already did.

## Notes

- No new requirements, no Skyrim restart needed — Papyrus + PrismaUI view changes only.
- If you spot the same downed-victim action (e.g. Investigate/Inspect) appearing in both the Down
  tab and a regular tab now that they're visible together, that's pre-existing overlap between the
  two menus' option sets, not new breakage — flag it if you'd like one side trimmed.
