; Papyrus stub for SkyrimNet_BakaIntegration.dll (SKSE plugin).
; If the DLL is absent all three functions are no-ops / return false,
; so the quest script falls back to vanilla Message.Show() menus.
Scriptname SNBakaUI

; Read one paired-anim offset from Data/SKSE/Plugins/SNBaka_Offsets.ini (line "asKey.asAxis = value",
; e.g. "struggle.x = -15"). asAxis is "x" (right+/left-), "y" (front+/back-), "z" (up+/down-) or "rot"
; (victim facing). Returns afDefault if the file/key is missing — so with no .ini, the built-in default
; (co-located + the action's facing) is used. Lower-cased on both sides.
Float Function GetOffset(String asKey, String asAxis, Float afDefault) Global Native

; Re-read SNBaka_Offsets.ini. Called on game load so edits to the file apply without restarting Skyrim.
Function ReloadOffsets() Global Native

; Returns true when PrismaUI is loaded and the menu view is ready.
Bool Function IsAvailable() Global Native

; Show the interact menu panel.  The result is returned asynchronously via
; the SKSE mod event "SNBaka_MenuChoice" (strArg="interact", numArg=choiceId).
;   0=BackHug  1=FrontHug  2=Kiss  3=Flirt
;   4=GrabHold 5=Struggle  6=Choke  7=WombHit
;   8=ForcedKiss 9=Spank 10=TouchChest 11=Examine
;  12=ShowOffBody 13=DrunkExploit 14=DrugFood 15=Fondle
;  -1=Cancel
Function ShowInteractMenu(Actor akCaster, Actor akTarget) Global Native

; Resolves the NPC the player is targeting (crosshair, then nearest-actor fallback).
; Returns None if nobody is targeted.  Used because the interact power is self-delivered,
; so the magic effect's akTarget is always the player.
Actor Function GetInteractTarget() Global Native

; Disable/restore character-to-character collision on an actor (havok layer swap).
; Called for both participants at animation start and restored in _CleanupPair so
; actors can be positioned overlapping without the physics solver shoving them.
Function SetNoCollision(Actor akActor, Bool abDisable) Global Native

; True if the furniture is an alchemy lab or enchanting table.  Used to make a
; female bent over one of those a high-temptation spank target for SkyrimNet.
Bool Function IsCraftingTemptation(ObjectReference akFurniture) Global Native

; Opens the multi-step SexLab encounter setup wizard (Roles -> Intensity ->
; Flavor -> Type).  The player's picks come back as "role;intensity;flavor;type"
; (or "cancel") and are passed to SkyrimNet_BakaIntegration._StartSexLabScene
; together with these two actors.  Only call when the player is involved.
Function ShowEncounterMenu(Actor akAggressor, Actor akVictim) Global Native

; Opens the downed-victim menu (Escalate / Investigate / Inspect / Stand Back),
; shown when the power is used on a defeated victim still on the ground. The pick
; comes back to SkyrimNet_BakaIntegration._DispatchDownedAction(choice, caster, victim):
;   0 = Escalate, 1 = Investigate, 2 = Inspect, 3 = Stand Back, <0 = cancel/stay down.
Function ShowDownedMenu(Actor akCaster, Actor akVictim) Global Native

; Show the sex-spank menu panel.  json must be:
;   {"names":["Lydia","Serana"],"playerInScene":true}
; Result via "SNBaka_MenuChoice" (strArg="sexspank", numArg=choiceId).
;   0/1/2   = spank sceneNPCs[0/1/2]
;   10/11/12 = sceneNPCs[0/1/2] spank player
;   13      = player self-spank
;  -1       = cancel
Function ShowSexSpankMenu(String json) Global Native

; Ground truth for who just hit akTarget, cached natively at the exact moment TESHitEvent fired.
; GetCombatTarget() is reliable enough for a follower victim (real AI targeting) but not necessarily
; for the player, so OnCreatureHitFollower uses this instead when the victim is the player.
; Returns None if nobody hit akTarget recently enough to still be cached.
Actor Function GetLastHitAggressor(Actor akTarget) Global Native

; Updates the ambient "charging toward 3s" get-up-key HUD bar (a separate, non-modal overlay -- never
; pauses the game, unlike the menus above). afPct: 0.0 (just pressed) .. 1.0 (fully charged, releasing
; now starts the QTE). Any negative value hides the bar. Safe to call every tick while the key is held.
Function SetGetUpCharge(Float afPct) Global Native
