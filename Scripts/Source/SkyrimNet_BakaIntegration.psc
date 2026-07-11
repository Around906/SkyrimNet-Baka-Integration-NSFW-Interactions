Scriptname SkyrimNet_BakaIntegration extends Quest

; ============================================================
; Settings — wired via MCM or CK defaults
; ============================================================
Bool  Property bEnabled              = True  Auto
Bool  Property bPlayerCanBeTarget    = True  Auto
; iTargetSex restricts which target sex ALL actions allow: 0 = both/any, 1 = female only, 2 = male only.
; Anatomically-specific actions (breasts, privates) are always female-only regardless of this.
Int   Property iTargetSex            = 0 Auto
Float Property fHugLoopDuration      = 8.0   Auto
Float Property fMolestLoopDuration   = 8.0   Auto
Float Property fKissLoopDuration     = 6.0   Auto
Float Property fTouchLoopDuration    = 6.0   Auto
Float Property fSequenceStageTimer   = 4.0   Auto
Float Property fSoloPoseDuration     = 30.0  Auto  ; how long an LLM-driven solo pose (SNBaka_Pose) holds
Int   Property iDrinkBlackoutChance  = 30    Auto  ; % chance PoseDrink ends in a passed-out-drunk blackout
Float Property fPlayerCooldown       = 0.5   Auto  ; cooldown after player-initiated actions
Float Property fNPCCooldown          = 8.0   Auto  ; per-NPC cooldown after NPC-initiated actions (was 20)
; After any NPC-initiated action completes, all further NPC actions are blocked for this
; long. Prevents the AI from chaining multiple NPCs in rapid succession.
Float Property fNPCGlobalCooldown    = 20.0  Auto  ; global anti-spam (was 60 — blocked interactions too much)
; Maximum distance (Skyrim units) between initiator and target for an animation to start.
; ~150 = conversation range, ~300 = same small room, ~600 = large hall.
; This value applies when the PLAYER is involved (crosshair-range targeting).
Float Property fMaxInteractionDistance = 500.0 Auto
; NPC-vs-NPC reach. Much larger than the player gate: two NPCs can drift apart between the LLM
; deciding to act and the action actually firing, so a tight gate makes ~half of them fail.
Float Property fNPCInteractionDistance = 1000.0 Auto
; When False, only the player can trigger Escalate. True (default) allows NPCs to chain
; a defeat into escalation. The 60s global cooldown (fNPCGlobalCooldown) is the primary
; spam guard — set this False only if you want to disable NPC escalation entirely.
Bool  Property bNPCCanEscalate       = True  Auto

; ╔══════════════════════════════════════════════════════════════════════════╗
; ║  POSITIONING TUNING — every paired-animation spacing offset is HERE.       ║
; ║  Edit these to change how far apart the two actors stand in each scene.    ║
; ║  (Also editable on the quest's script in the Creation Kit — no recompile.) ║
; ╠══════════════════════════════════════════════════════════════════════════╣
; ║  HOW TO READ A VALUE                                                       ║
; ║    • Units  : Skyrim units (~1.4 cm each), measured along the victim's     ║
; ║               facing direction.                                            ║
; ║    • Sign   : +value = partner placed IN FRONT,  -value = placed BEHIND.   ║
; ║    • Size   : bigger magnitude = farther apart;  0 = co-located (let the   ║
; ║               animation position them — best for Babo paired anims).       ║
; ╠══════════════════════════════════════════════════════════════════════════╣
; ║  NAME SUFFIX = which actor is the player (separate so one never affects    ║
; ║  another):                                                                 ║
; ║    _NPC   = NPC on NPC            _PC    = player involved (either role)    ║
; ║    _PCAtk = player is attacker    _PCVic = player is the victim            ║
; ╠══════════════════════════════════════════════════════════════════════════╣
; ║  WHICH ACTION EACH GROUP DRIVES                                            ║
; ║    fStruggleSep_*  Struggle grapple   (victim stands ahead of attacker)    ║
; ║    fBackHugSep_*   Back-hug molest    (attacker stands behind victim)      ║
; ║    fEscalDist_*    Choke escalation   (attacker over the downed victim)    ║
; ║    fFondleSep_*    Fondle privates    (attacker behind, victim facing away)║
; ║    fChokeHugSep_*  Back choke / hug   (attacker directly behind victim)    ║
; ╚══════════════════════════════════════════════════════════════════════════╝
; NOTE (2026-06-10 model change): every paired anim now uses _SetupPair — the attacker is the
; origin (0,0,0), the NPC attacker teleports onto the victim, and the VICTIM is placed at
; xLocal=RIGHT(+)/LEFT(-), yLocal=FRONT(+)/BACK(-). Most anims are CO-LOCATED (0,0) and the Babo
; clip self-separates; tune any of them straight off the "[Baka] ... victim vs attacker(0,0,0)" log.
; Struggle (PlayPairedSequence) — victim sits FRONT-LEFT of the attacker.
Float Property fStruggleSep_NPC   = 20.0  Auto  ; NPC vs NPC      — how far in FRONT of the attacker
Float Property fStruggleSep_PCAtk = 20.0  Auto  ; player attacker — how far in FRONT
Float Property fStruggleSep_PCVic = 20.0  Auto  ; player victim   — how far in FRONT
Float Property fStruggleLeft      = -15.0 Auto  ; all cases — how far to the attacker's LEFT (negative = left)
; Back-hug molest (PlayPairedLoopAnim) — how far BEHIND (negative) the attacker stands.
Float Property fBackHugSep_NPC    = -50.0 Auto  ; NPC vs NPC (targets ~50 dist)
Float Property fBackHugSep_PC     = -50.0 Auto  ; player involved (now -50)
; Choke escalation (_DoEscalation MoveTo) — attacker's gap in front of the victim.
Float Property fEscalDist_NPC     = 0.0   Auto  ; NPC victim — co-located; the Babo defeat anim
                                                ; spaces the pair itself (5 double-spaced -> too far)
Float Property fEscalDist_PCVic   = 4.0   Auto  ; player victim (A1 placed 4 units in front)
; Fondle privates (PlayPairedSimpleAnim) — attacker directly BEHIND the victim, same facing
; (victim's back to the attacker). More-negative = further behind.
Float Property fFondleSep_NPC     = -40.0 Auto  ; NPC vs NPC (was -20 — read weird/too close)
Float Property fFondleSep_PC      = -20.0 Auto  ; player involved (unchanged)
; Choke-hug / back choke (PlayPairedSequence) — attacker stands BEHIND the victim, one directly
; behind the other (no lateral shift). More-negative = victim further ahead (avoids clipping).
Float Property fChokeHugSep_NPC   = -8.0  Auto  ; NPC vs NPC (0 -> -8: victim was clipping in)
Float Property fChokeHugSep_PCVic = -15.0 Auto  ; player victim — push the attacker further back
; Forced kiss (PlayPairedLoopAnim, face-to-face) — 0 = the anim's own spacing; negative pulls the
; pair closer (the SLAP kiss anim leaves a person-width gap).
Float Property fForcedKissSep_NPC = 0.0   Auto  ; NPC vs NPC      (X axis = front-to-back gap)
Float Property fForcedKissSep_PC  = 10.0  Auto  ; player involved (X axis ~15cm gap, face-to-face; flip sign if back-to-back)
; Base Flirt (Babo_Flirt paired) — the anim leaves the partner too far back; pull them forward
; along the X axis (front-to-back for this anim family) so the victim lines up with the arm.
Float Property fFlirtSep_NPC       = -20.0 Auto  ; NPC vs NPC      (flip sign if it goes the wrong way)
Float Property fFlirtSep_PC        = 0.0   Auto  ; player involved (0 = the spacing that already worked; tune if needed)
; DEBUG: position tuning — on-screen offsets + final coords per scene. OFF by default now that
; spacing is mostly dialed in; flip True (or tick in the CK) when you need to retune positions.
Bool  Property bDebugPositions    = True  Auto
; DEBUG: action/power logging — a concise on-screen line + a detailed log line for each action
; (interaction name, aggressor, target) and each interact-power press (target, or "no target on
; crosshair"). Left ON so you can see what's firing; untick to silence.
Bool  Property bDebugLog          = True  Auto

; === Resist minigame (powered by Flash Games - Struggling QTE) ===
Bool  Property bResistEnabled    = True Auto
; Escape difficulty 0–100. Higher = easier for victim to escape. Default 70.
; Keys are configured in AEL's own Settings.json (WASD / gamepad d-pad by default).
; NOTE: this is the PLAYER's QTE difficulty only. NPC-vs-NPC fights auto-resolve with
; fNPCEscapeChance below (kept separate so tuning one never changes the other).
Float Property fResistDifficulty    = 70.0 Auto
; NPC-vs-NPC struggle: the victim's % chance to break free (no QTE — it's auto-rolled).
; Lower = the attacker wins more often (which leads into the overpower/escalation content).
Float Property fNPCEscapeChance     = 35.0 Auto
; The MERCY window: a few extra seconds of untouchability (ghost held) whenever a victim exits the
; protected interaction pipeline -- a won struggle (player QTE, NPC escape roll, the bridge's get-up
; key) or the end of a sex scene -- so nobody gets spawn-killed the exact frame the protection drops.
; Confirmed from testing: the ghost used to drop the instant cleanup ran, and a third falmer attacked
; the player literally that moment. 0 disables.
Float Property fEscapeGraceDuration = 2.0 Auto
; NPC-vs-NPC forced anims: how long each stage is held before advancing. The fight plays its
; shared middle stages at this rate, then the deciding stage (attacker-victor or break-free).
Float Property fNPCStageTime        = 5.0 Auto
; Seconds of animation to play before the QTE overlay appears. Lets the start
; animation finish and the actors settle before the minigame is shown.
Float Property fQTEStartDelay       = 4.0  Auto
; Escalation window and QTE difficulty after QTE defeat
Float Property fEscalationWindow     = 20.0 Auto  ; how long the downed victim waits for escalate before recovering
Float Property fEscalationDifficulty = 70.0 Auto
; SexLab is now reached ONLY through the SkyrimNet_BakaSL bridge (global funcs), so this script holds
; no SexLab script types and the mod loads/runs without SexLab installed.
; Which sex framework to drive escalation scenes: 0 = auto (SexLab if installed, else OStim),
; 1 = SexLab, 2 = OStim.  Set in MCM.  SexLab is resolved at runtime so SexLab.esm need not be a master.
Int Property iSexBackend = 0 Auto
; ── Creature escalation (OPT-IN bestiality content — every toggle defaults OFF/restrictive) ──
Bool Property bCreatureEscalation  = False Auto  ; master switch: creatures may escalate on humans
Bool Property bCreatureOnPlayer    = False Auto  ; allow creatures to escalate on the PLAYER
; Struggle vs escalate split (explicit spec): the STRUGGLE (pin/QTE — "a wolf mauling a person")
; can be enabled on its own; the sex SCENE that follows a creature win is the separate, kinkier
; step. OFF = a creature win just leaves the victim downed, no scene ever starts.
Bool Property bCreatureSceneAllowed = True Auto
; Ask SkyrimNet's LLM a one-word YES/NO before a downed-victim creature escalation commits (the
; proximity pipeline only — on-hit mid-combat grapples stay instant, an LLM round-trip is too slow
; for a live melee exchange). Fail-open on any LLM error. See snbaka_escalation_gate.prompt.
Bool Property bLLMGateEscalation   = False Auto
; Corner-message master switch: all player-facing Debug.Notification messages route through _Notify,
; so turning this off gives a clean HUD. Papyrus log traces are unaffected.
Bool Property bShowNotifications   = True Auto
Bool Property bCreatureCombatAllowed = True Auto ; True = also mid-combat; False = only once the victim is downed
; A creature's own melee hit on a follower can attempt escalation directly, without waiting for the
; follower to go down first (see HitEventSink.cpp / OnCreatureHitFollower below). AND-gated with
; bCreatureCombatAllowed above (both must be on) plus the existing master switch/sex filter that
; _DoCreatureEscalation already enforces -- turn any one of them off and this simply never fires.
Bool Property bCreatureEscalateFollowersOnHit = False Auto
; A hit landing doesn't mean the creature actually TRIES -- confirmed feedback from testing: with no
; gate here, almost every melee hit guaranteed a struggle attempt, which gets old fast. Rolled once per
; hit (after the 3s per-victim throttle already in OnCreatureHitFollower), independent of the outcome
; roll below (iCreatureSuccessPct decides who WINS an attempt that's already happening; this decides
; whether the creature even bothers this time).
Int  Property iCreatureHitEngageChance = 25 Auto
; ===== Humanoid mid-combat escalation (on-hit) =====
; Same idea as the creature pair above, for HUMANOID aggressors: an enemy human who just landed a melee
; hit on a follower/the player can attempt a Struggle right there mid-combat. Routed through the same
; native hit event and the same per-victim throttle as the creature path; dispatches to the ordinary
; Struggle action (QTE for the player, timed roll for NPCs), so every existing Struggle gate (master
; switch, sex filter, player-target permission, locks) still applies on top of these two.
Bool Property bHumanEscalateOnHit = False Auto  ; opt-in, default OFF like the creature version
Int  Property iHumanHitEngageChance = 25 Auto   ; chance per (throttled) hit that the humanoid bothers
Int  Property iCreatureVictimSex   = 0     Auto  ; allowed victim sex (same scheme as iTargetSex): 0=both, 1=female, 2=male
Bool Property bSellToSlavery       = True  Auto  ; allow the Sell-to-Slavery action (no-ops unless Simple Slavery Plus Plus is installed)
; NPCs may enslave a DOWNED FOLLOWER via Follower Slavery Mod — deliberately separate from
; bSellToSlavery (that one auctions the PLAYER via SS++); the two actions have disjoint targets so
; the LLM can't confuse them. Default OFF: it permanently removes a follower from the party.
Bool  Property bFollowerSlavery       = False  Auto
Float Property fSlaveryPlayerDistance = 1500.0 Auto  ; player must be at least this far (or downed too) for EnslaveFollower to fire
Int  Property iCreatureBackend     = 0     Auto  ; creature sex backend: 0=auto, 1=SexLab, 2=OStim
Int  Property iCreatureSuccessPct  = 50    Auto  ; NPC-victim escape chance, both while not yet downed AND already downed
; How long a not-yet-downed NPC struggle holds the shared pose before rolling the outcome -- confirmed
; feedback from testing: the old 2-stage x1.5s (3s total) read as far too quick to be a real struggle.
; Not used for the player (real interactive QTE) or an already-downed victim (a quick roll, no drawn-out
; struggle to hold a pose through).
Float Property fCreatureStruggleDuration = 12.0 Auto
; A struggle LOSS (victim defeated, by a creature or a human) starts this grace window on the victim:
; no new passive creature attempt (on-hit roll or the downed-victim scan) will pick them again until it
; expires, UNLESS they end up back in real combat first (a live combat target ends the grace early) --
; confirmed feedback: back-to-back struggles on the same victim the instant one ends "grows old fast."
Float Property fPostDefeatGraceDuration = 100.0 Auto
; Nobody gets pulled into a struggle for this many seconds after a genuinely fresh down (see
; SNAcheron.FreshDownRT) -- lets the bleedout/collapse animation actually settle first. Confirmed real
; bug from testing: engaging too early can break the down animation and leave the victim stuck
; perpetually "downing" instead of settling into a normal held/bleedout state.
Float Property fFreshDownGraceDuration = 3.0 Auto
; Once a victim is confirmed down and the scene is actually about to start, look for up to this many
; OTHER creatures of the SAME type nearby to join in (a 2v1/3v1 group scene) -- computed only at that
; point, never earlier, so a struggle that fails or a combat-not-clear outcome never wastes the scan.
; 1 = current single-creature behavior; 3 is the practical ceiling most animation packs support.
Int Property iCreatureGroupMaxSize = 3 Auto
; ===== Spank system =====
Bool  Property bPlayerCanBeSpanked     = True Auto
Bool  Property bSpankFurnitureTriggers = True Auto
Bool  Property bSpankMaleTargets       = False Auto
Float Property fSpankCooldown          = 0.5  Auto
Float Property fSpankCooldownSex       = 0.3  Auto
Int   Property SpankTatIntensity       = 2    Auto
Int   Property SpankHealFactor         = 2    Auto
Float Property SpankTatFadeRate        = 2.0  Auto Hidden
Float Property _lastSpankFadeTime      = 0.0  Auto Hidden
Sound Property SpankImpactSound        Auto
Sound Property SpankBreastSlapSound    Auto
Sound Property SpankFaceSlapSound      Auto
Sound Property SpankMoanSound          Auto
Spell Property SpankPartnerPower       Auto
Spell Property ButtReactionSpell       Auto
Spell Property BreastReactionSpell     Auto
Spell Property TearSpell               Auto
Bool  Property bAnimatedTearsEnabled   = True  Auto
Bool  Property bExpressionsEnabled      = True  Auto  ; master toggle for facial expressions
Float Property fExpressionIntensity     = 0.50  Auto  ; 0.0-1.0 scale on all expression morphs (lower = subtler)
Bool  Property bMatchHeight             = True  Auto  ; height-match paired-anim actors (DOM ScaleActorToOther) so tall/short pairs align

; === Sounds (assign in CK to Baka sound descriptors) ===
Sound Property PanicSoundF  Auto
Sound Property SmackSound   Auto

; === Sex framework soft deps (assign factions in CK, leave None if unused) ===
Faction Property SexLabAnimatingFaction Auto
Faction Property OStimExcitementFaction Auto

; A condition-free "do nothing" AI package, force-applied to scene NPCs so their AI
; can't re-evaluate and yank them out of the held animation (SexLab's LockActor trick).
; Assign in CK to a package with NO conditions (e.g. duplicate SexLab's DoNothing and
; delete its faction condition).  If left None, _HoldActorAI is a safe no-op.
Package Property SNBakaDoNothing Auto

; === Player powers (assign in CK) ===
Spell Property EscalatePower Auto
Spell Property InteractPower  Auto

; Escalation (forced sex) is the ONLY combat-gated action: it won't start while any actor within this
; radius of the victim is still in combat. MCM-tunable.
Float Property fCombatOverRadius = 3000.0 Auto

; OPTIONAL robust combat-stop. Assign in CK to a Calm-archetype spell (high magnitude, long
; duration) in the Baka ESP. When set, pacify casts it on the captor's side so combat truly ends
; instead of relying on aggression-0 alone. Left as None -> we fall back to the aggression/rank path.
Spell Property SNBakaCalm Auto

; === Interact menu messages (assign in CK to SNBaka_InteractMenu* records) ===
Message Property InteractMenuMain         Auto
Message Property InteractMenuAffectionate Auto
Message Property InteractMenuAggressive   Auto
Message Property InteractMenuAggPhysical  Auto
Message Property InteractMenuAggSexual    Auto

; === Sex-spank menus (create in CK, assign here) ===
; SNBaka_SexSpankWho:    5 buttons — "Person 1" | "Person 2" | "Person 3" | "You" | "Cancel"
; SNBaka_SexSpankByWhom: 5 buttons — "Person 1" | "Person 2" | "Person 3" | "Yourself" | "Cancel"
; Button indices are fixed; the notification shown just before the menu maps numbers to names.
Message Property SexSpankWhoMenu    Auto
Message Property SexSpankByWhomMenu Auto

; === Internal ===
Actor Property PlayerRef    Auto Hidden
Form  Property XMarkerBase  Auto Hidden

; === AEL QTE state (never saved — safe to reset on load) ===
Bool _bAELStruggleComplete  = False
Bool _bAELVictimEscaped     = False
Bool _bCooldownActive       = False
; Set by Play* helpers when a QTE completes with the attacker winning (victim dominated).
; Cleared by LockBoth at the start of every new animation.
Bool _bQTEDefeated          = False
; Optional Babo down-pose anim event for the NEXT NPC defeat (e.g. "BaboFaintF" after a choke).
; Read + cleared by _Bleedout. Empty => default Babo_DefeatTraumaLie.
String _sDownPose           = ""
; Set by Escalate_Execute during the ground window to signal _DefeatGroundWindow.
Bool _bEscalateRequested    = False
; Set by Release_Execute during the ground window to free the victim early without escalating.
Bool _bReleaseRequested     = False
; Debounce so the "escalate or back down" decision cue isn't fired twice for one action (e.g. by both
; _RecoveryPeriod and UnlockBoth). Real-time seconds of the last baka_opportunity we fired.
Float _fLastOpportunityRT   = 0.0
; Downed-victim menu requests, polled by _DefeatGroundWindow's wait loop:
;   _iDownedReplay 1 = Investigate, 2 = Inspect — play the inspection anim, then re-down + reset timer.
;   _bStandBack = the player chose "Stand Back" — exit the window into the normal stand-up/recover path.
Int  _iDownedReplay         = 0
Bool _bStandBack            = False
; Set by LLM-driven aggressive actions (inspect/escalate/etc.) when they act on a DOWNED victim, so
; the _DefeatGroundWindow loop resets its countdown — the victim stays protected/down while the
; aggressor keeps interacting, and only recovers once interactions STOP.
Bool _bResetDownWindow      = False
; True when player is A2 (victim) for the current QTE — determines how afNumArg maps to escape.
Bool _bPlayerIsVictim       = False
; --- LLM escalation gate (bLLMGateEscalation) transient state: one ask in flight at a time ---
Bool  _bGatePending  = False
Float _fGateSentRT   = 0.0
Actor _gateCreature  = None
Actor _gateVictim    = None

; Corner-message wrapper — every player-facing Debug.Notification in this script routes through here
; so the MCM "Show Notifications" toggle can silence the lot for a clean HUD. Traces are unaffected.
Function _Notify(String msg)
    If bShowNotifications
        Debug.Notification(msg)
    EndIf
EndFunction

; Trace wrapper — every Debug.Trace in this script routes through here, gated on the bDebugLog MCM
; toggle. The string concatenation at each call site still runs (Papyrus evaluates arguments first),
; but the synchronized log-file WRITE — the expensive part on a starved VM — is skipped when off.
; Keep it ON while actively debugging/stabilizing; turn OFF for clean high-performance play.
Function _Log(String msg)
    If bDebugLog
        Debug.Trace(msg)
    EndIf
EndFunction
; Set by DrugFood_Execute before calling _DefeatGroundWindow so _DoEscalation
; can trigger an unconscious-victim SexLab scene instead of a generic rape scene.
; Cleared by _DoEscalation after the scene is started.
Bool _bDruggedEscalation    = False
; Game time of the last completed NPC-initiated action.  Compared against
; fNPCGlobalCooldown in IsEligible to throttle AI-driven action frequency.
Float _fLastNPCActionTime   = 0.0
; Per-action extra Z nudge for the PLAYER's pin-marker (on top of the global -2 vehicle-lift fix).
; Set by an Execute fn before PlayPairedSequence when a specific anim seats the player too high/low,
; then reset to 0. Negative = lower the player.
Float _fPlayerZAdjust       = 0.0
; Tracked for periodic tear re-application inside _WaitOrAbort.
Actor _TearVictim           = None

; PrismaUI async menu state — set before showing the HTML panel,
; read back in OnSNBakaMenuChoice when the player picks an option.
Actor _pendingTarget   = None
Actor _pendingCaster   = None
Actor _pendingSexCaster = None
Actor _pendingSexNPC0  = None
Actor _pendingSexNPC1  = None
Actor _pendingSexNPC2  = None

; ============================================================
; Init
; ============================================================
Event OnInit()
    PlayerRef   = Game.GetPlayer()
    XMarkerBase = Game.GetFormFromFile(0x0E, "Skyrim.esm")
    Setup()
EndEvent

Event OnPlayerLoadGame()
    PlayerRef      = Game.GetPlayer()
    XMarkerBase    = Game.GetFormFromFile(0x0E, "Skyrim.esm")
    _bAELStruggleComplete = False
    _bAELVictimEscaped    = False
    _bCooldownActive      = False
    _bQTEDefeated         = False
    _bEscalateRequested   = False
    _bReleaseRequested    = False
    _bPlayerIsVictim      = False
    _bDruggedEscalation   = False
    _fLastNPCActionTime   = 0.0
    ; Any in-progress animation is gone after a load — always safe to clear player locks.
    If PlayerRef
        StorageUtil.SetIntValue(PlayerRef, "SNBaka.Locked",        0)
        StorageUtil.SetIntValue(PlayerRef, "SNBaka.StopRequested", 0)
        StorageUtil.SetIntValue(PlayerRef, "SNBaka.OnGround",      0)
        Game.EnablePlayerControls()
    EndIf
    Setup()
EndEvent

Function Setup()
    ; Confirmed real bug from testing: THIS is the actual primary re-registration path (called from
    ; SkyrimNet_BakaIntegration_MCM's OnGameReload on every single load -- see that script's own comment;
    ; the OnUpdateGameTime heartbeat in this quest is only a secondary backup), yet it never refreshed
    ; PlayerRef before calling _RegisterModEvents(), which only sets SNBaka.Present behind an "If
    ; PlayerRef" guard. If PlayerRef was stale/None at this exact point, the flag silently never got set
    ; -- Acheron's own creature-handoff check reads that flag and skips every roll forever, even though
    ; Baka was actually alive and listening (its own SNBaka_TryCreatureOnDowned handler fired fine).
    If !PlayerRef
        PlayerRef = Game.GetPlayer()
    EndIf
    UnregisterForAllModEvents()
    _RegisterDecorators()
    ; Acheron-downed handoff (creature pounce) + AEL/menu events. Re-asserted from OnUpdateGameTime too,
    ; as a backup in case this path is ever skipped.
    _RegisterModEvents()
    ; Re-read SNBaka_Offsets.ini so edits to the offsets file apply on game load (no restart needed).
    SNBakaUI.ReloadOffsets()
    ; Persist the "Sell to Slavery disabled" choice across loads: the YAML re-registers the action every
    ; game load, so if the player has it switched off we pull it back out of the action menu here. (The
    ; exec also no-ops when off, so it's functionally disabled regardless of registration timing.)
    If !bSellToSlavery
        SkyrimNetApi.UnregisterAction("SellToSlavery")
    EndIf
    If !bFollowerSlavery || !IsFollowerSlaveryInstalled()
        SkyrimNetApi.UnregisterAction("EnslaveFollower")
    EndIf
    _Log("[SNBaka] Setup: SexLab installed=" + SkyrimNet_BakaSL.Installed())
    ; Spank system
    SpankTatFadeRate = SpankHealFactor as Float
    If SpankTatFadeRate < 0.1
        SpankTatFadeRate = 0.1
    EndIf
    If _lastSpankFadeTime <= 0.0
        _lastSpankFadeTime = Utility.GetCurrentGameTime()
    EndIf
    RegisterForSingleUpdateGameTime(SpankTatFadeRate)
    If fSpankCooldownSex <= 0.0 || fSpankCooldownSex > 5.0
        fSpankCooldownSex = 1.0
    EndIf
    ; Force-resolve all properties every Setup() call.
    ; This clears zombie references left by ESL FormID compaction — zombie forms are
    ; non-None in Papyrus so a plain !Property guard would miss them.
    Spell  _sp
    Message _m
    If !EscalatePower
        EscalatePower = Game.GetFormFromFile(0x000D69, "SkyrimNet_BakaIntegration.esp") as Spell
    EndIf
    _sp = Game.GetFormFromFile(0x00080E, "SkyrimNet_BakaIntegration.esp") as Spell
    If _sp
        InteractPower = _sp
    EndIf
    _m = Game.GetFormFromFile(0x00080A, "SkyrimNet_BakaIntegration.esp") as Message
    If _m
        InteractMenuMain = _m
    EndIf
    _m = Game.GetFormFromFile(0x00080B, "SkyrimNet_BakaIntegration.esp") as Message
    If _m
        InteractMenuAffectionate = _m
    EndIf
    _m = Game.GetFormFromFile(0x00080C, "SkyrimNet_BakaIntegration.esp") as Message
    If _m
        InteractMenuAggressive = _m
    EndIf
    _m = Game.GetFormFromFile(0x000803, "SkyrimNet_BakaIntegration.esp") as Message
    If _m
        InteractMenuAggPhysical = _m
    EndIf
    _m = Game.GetFormFromFile(0x000804, "SkyrimNet_BakaIntegration.esp") as Message
    If _m
        InteractMenuAggSexual = _m
    EndIf
    _Log("[SNBaka] Setup: InteractMenuMain=" + InteractMenuMain + " InteractPower=" + InteractPower)

    ; Emotional Tears Effect SE — optional soft dependency, no master needed.
    ; Resolved at runtime; no-ops silently if EmoTears4NPCs.esp is not installed.
    If bAnimatedTearsEnabled
        ; STABLE: keep whatever valid spell is already set (from the CK property or a
        ; previous good load).  ONLY re-resolve when it has been lost (None) — that
        ; recovers the saved-None left by an older build, without ever clobbering a
        ; working value.  This is why tears kept breaking: prior code re-resolved
        ; (and sometimes nulled) the spell every single load.
        ; zzNPCTearsTestApplySelf = local 0x000802 in EmoTears4NPCs.esp (CK 03000802).
        If !TearSpell
            TearSpell = Game.GetFormFromFile(0x000802, "EmoTears4NPCs.esp") as Spell
        EndIf
        _Log("[SNBaka] Setup: TearSpell using=" + TearSpell)
    Else
        TearSpell = None
        _Log("[SNBaka] Setup: TearSpell cleared (disabled)")
    EndIf

    ; EscalatePower is no longer added to the player — Interact_ShowMenu handles escalation
    ; automatically when the target is on the ground (SNBaka.OnGround=1). The spell record
    ; is kept in the ESP so existing saves aren't broken, but it is no longer granted.
    If InteractPower && !PlayerRef.HasSpell(InteractPower)
        PlayerRef.AddSpell(InteractPower)
    EndIf

    ; Sell-to-Slavery availability, resolved at every load (Setup runs per-load via the MCM's
    ; OnGameReload): the YAML re-registers the action on load, so pull it back OUT of the LLM's menu
    ; whenever it can't actually work -- Simple Slavery++ missing, or the user's MCM toggle off (the
    ; toggle's own handler already does this live; this covers the re-registration on the NEXT load).
    ; Execute() carries the same plugin check as a belt-and-suspenders for direct calls.
    If !IsSimpleSlaveryInstalled()
        SkyrimNetApi.UnregisterAction("SellToSlavery")
        _Log("[SNBaka] Setup: SimpleSlavery.esp not installed — SellToSlavery action unregistered")
    ElseIf !bSellToSlavery
        SkyrimNetApi.UnregisterAction("SellToSlavery")
        _Log("[SNBaka] Setup: bSellToSlavery is OFF — SellToSlavery action unregistered")
    EndIf
    ; Same gate for the FOLLOWER slavery action (Follower Slavery Mod) — unregistered when the mod
    ; isn't ready or the toggle is off, so the LLM never even sees it. Keeping the two slavery
    ; actions' availability independent is what stops wrong-target calls breaking roleplay.
    If !IsFollowerSlaveryInstalled()
        SkyrimNetApi.UnregisterAction("EnslaveFollower")
        _Log("[SNBaka] Setup: Follower Slavery Mod not installed/initialized — EnslaveFollower action unregistered")
    ElseIf !bFollowerSlavery
        SkyrimNetApi.UnregisterAction("EnslaveFollower")
        _Log("[SNBaka] Setup: bFollowerSlavery is OFF — EnslaveFollower action unregistered")
    EndIf
EndFunction

; Plugin-presence probe for Simple Slavery Plus Plus -- GetFormFromFile is the only detection primitive
; this compile environment's Game.psc has (no SKSE GetModByName here), and it's the same pattern this
; file already uses for EmoTears4NPCs. 0x00492E = SS++'s own main QUST record, read directly from the
; plugin binary (not guessed). Returns None (with a harmless engine log line) when the esp is absent.
; Shared by Setup(), SellToSlavery_Execute, and the MCM (via the Main property).
Bool Function IsSimpleSlaveryInstalled()
    Return Game.GetFormFromFile(0x00492E, "SimpleSlavery.esp") != None
EndFunction

; Follower Slavery Mod readiness probe — FSM's own documented gate: this global StorageUtil flag is
; set only once the player has opened FSM's MCM and clicked Install (before that its quests aren't
; running and its enslave queue isn't listening). Shared by Setup(), EnslaveFollower_Execute and the MCM.
Bool Function IsFollowerSlaveryInstalled()
    Return StorageUtil.GetIntValue(None, "fsm_bIsMCMInstalled", 0) == 1
EndFunction

; ============================================================
; Guards
; ============================================================
; abAllowMidCombat: relaxes ONLY the attacker-in-combat gate below -- used by the on-hit humanoid
; escalation path (see Struggle_Execute's abFromHit), where the attacker being in combat is the whole
; premise. Every other gate (enabled, dead, downed initiator, creatures, distance, player-target
; permission, sex filter) still applies unconditionally.
Bool Function IsEligible(Actor akA1, Actor akA2, Bool abAllowMidCombat = False)
    If !bEnabled || !akA1 || !akA2
        Return False
    EndIf
    If akA1.IsDead() || akA2.IsDead()
        Return False
    EndIf
    ; A downed/defeated actor can only be acted ON (akA2), never act themselves (akA1).
    If _IsDownedAny(akA1)
        Return False
    EndIf
    ; Creatures (Draugr, Falmer, Giant, wolves, etc.) get ONLY CreatureEscalate — never the human action
    ; set (Struggle, ChokeHug, Escalate, HelpUp, etc.), which plays human Babo animations and narrates them
    ; as a person. CreatureEscalate_Execute has its own separate gate and never calls IsEligible, so this
    ; doesn't affect it. BOTH tests are required: _IsCreatureActor alone let falmers/giants/draugr
    ; through (Bethesda tags those races ActorTypeNPC, the same keyword humans carry — confirmed
    ; report: falmers and giants picking Inspect and other humanoid animations their skeletons can't
    ; play). _CreatureAnimKey matches by actual race and isn't fooled by the keyword.
    If _IsCreatureActor(akA1) || _IsCreatureActor(akA2) || _CreatureAnimKey(akA1) != "" || _CreatureAnimKey(akA2) != ""
        _Log("[SNBaka] IsEligible: blocked — creature-skeleton actor in a humanoid action (" + akA1.GetDisplayName() + " -> " + akA2.GetDisplayName() + ")")
        Return False
    EndIf
    ; An actor mid SEX SCENE (OStim/SexLab — ours OR another mod's; SNBaka.Locked only covers ours)
    ; is never a valid paired-animation participant — yanking them out of a running thread breaks
    ; both systems (explicit spec).
    If IsInSexAnimation(akA1) || IsInSexAnimation(akA2)
        _Log("[SNBaka] IsEligible: blocked — an actor is mid sex scene (" + akA1.GetDisplayName() + " -> " + akA2.GetDisplayName() + ")")
        Return False
    EndIf
    ; Player-involved uses the crosshair-range gate; NPC-vs-NPC gets the larger reach.
    Float maxDist = fMaxInteractionDistance
    If akA1 != PlayerRef && akA2 != PlayerRef
        maxDist = fNPCInteractionDistance
    EndIf
    If maxDist > 0.0 && akA1.GetDistance(akA2) > maxDist
        _Log("[SNBaka] IsEligible: blocked — distance " + akA1.GetDistance(akA2) + " > " + maxDist)
        Return False
    EndIf
    ; Attacker-in-combat normally blocks an action — EXCEPT against a downed/bleeding-out victim. That
    ; is the defeat case: the fight may still be live around them, but the target is already beaten and
    ; helpless, so choke/pin/grope/escalate/etc. are valid. LockBoth then Calms the attacker out of
    ; combat so the held anim plays, and _ShouldAbort re-breaks it only if the attacker is actually hit.
    If akA1.IsInCombat() && !_IsDownedAny(akA2) && !abAllowMidCombat
        Return False
    EndIf
    ; "Player Can Be Target" gates only the player being the VICTIM (akA2) — NOT the player
    ; initiating on an NPC (akA1). The old check also blocked akA1==player, so unchecking this
    ; disabled every player-started action and made the whole mod look "off".
    If !bPlayerCanBeTarget && akA2 == PlayerRef
        Return False
    EndIf
    ; Content-preference filter (what the LLM/an NPC should be allowed to pick), not a technical
    ; constraint -- only gates a non-player initiator, same as bNPCCanEscalate/_DoEscalation. The
    ; player targeting whoever they want, via any action, is their own deliberate choice.
    If akA1 != PlayerRef && !_TargetSexAllowed(akA2)
        Return False
    EndIf
    If IsActorLocked(akA1) || IsActorLocked(akA2)
        Return False
    EndIf
    If _bCooldownActive && akA1 == PlayerRef
        Return False
    EndIf
    If akA1 != PlayerRef
        Float now = Utility.GetCurrentGameTime()
        ; Per-initiator cooldown — same NPC can't act again too soon.
        Float lastTime = StorageUtil.GetFloatValue(akA1, "SNBaka.LastActionTime", 0.0)
        If now - lastTime < (fNPCCooldown / 86400.0)
            Return False
        EndIf
        ; Global NPC cooldown — blocks all NPC actions for fNPCGlobalCooldown seconds
        ; after any NPC-initiated action. Prevents AI from chaining multiple actors.
        If now - _fLastNPCActionTime < (fNPCGlobalCooldown / 86400.0)
            Return False
        EndIf
    EndIf
    If IsInSexAnimation(akA1) || IsInSexAnimation(akA2)
        Return False
    EndIf
    Return True
EndFunction

; Returns True if the actor has a female body (sex == 1).
; Used to gate anatomically-specific actions at the function level.
Bool Function HasFemaleBody(Actor akActor)
    If !akActor
        Return False
    EndIf
    Return akActor.GetActorBase().GetSex() == 1
EndFunction

; iTargetSex gate, shared by IsEligible (the ~24 "initiate an interaction" actions) AND Escalate_Execute
; directly — Escalate doesn't call IsEligible (it acts on an already-downed victim, not a fresh
; interaction, so the distance/combat/cooldown checks don't apply), so without this call it was NOT
; sex-gated at all: iTargetSex had zero effect on who Escalate could target, regardless of the setting.
; HelpUp/Release deliberately do NOT call this — recovering or releasing a downed victim should never be
; blocked by target sex.
Bool Function _TargetSexAllowed(Actor akTarget)
    If iTargetSex == 1 && !HasFemaleBody(akTarget)
        Return False
    ElseIf iTargetSex == 2 && HasFemaleBody(akTarget)
        Return False
    EndIf
    Return True
EndFunction

; Same technique AcheronIntegration already uses to tell creatures (Draugr, Falmer, Giant, wolves,
; trolls, etc.) apart from humanoid actors: the ActorTypeNPC keyword is on every human/humanoid race,
; not on creature races. Cached like _OStimSceneFaction below — resolved once, reused after. If the
; keyword somehow fails to resolve, fail OPEN (treat as humanoid) so a lookup hiccup can't silently
; disable every human action instead of just skipping the (rarer) creature-exclusion check.
Keyword _kwActorTypeNPC
Bool Function _IsCreatureActor(Actor ak)
    If !ak
        Return False
    EndIf
    ; Race-name match first — Falmer and Draugr are creature-behaving races that Bethesda still tags
    ; with ActorTypeNPC (the same keyword every human uses), so the keyword check below alone
    ; misclassifies them as humanoid. That let them slip through IsEligible into human-only actions
    ; (Struggle, ChokeHug, Escalate, HelpUp, Capture — anything gated by IsEligible or this function
    ; directly) using human Babo animations their skeleton can't actually play. Any actor _CreatureAnimKey
    ; recognizes is unambiguously a creature for our purposes, whatever keyword it happens to carry.
    If _CreatureAnimKey(ak) != ""
        Return True
    EndIf
    If !_kwActorTypeNPC
        _kwActorTypeNPC = Game.GetFormFromFile(0x00013794, "Skyrim.esm") as Keyword
    EndIf
    If !_kwActorTypeNPC
        Return False
    EndIf
    Return !ak.HasKeyword(_kwActorTypeNPC)
EndFunction

; OStim "in a scene" faction = OStimActorCountFaction (OStim.esp 0xECA), resolved at runtime so OStim
; stays optional (no master).  This is membership in an active OStim thread — NOT OStimExcitementFaction
; (that's arousal, lingers outside scenes, and was never assigned since OStim isn't a master).
Faction _ostimFac
Faction Function _OStimSceneFaction()
    If !_ostimFac
        _ostimFac = Game.GetFormFromFile(0x000ECA, "OStim.esp") as Faction
    EndIf
    Return _ostimFac
EndFunction

Bool Function IsInSexAnimation(Actor akActor)
    If SexLabAnimatingFaction && akActor.GetFactionRank(SexLabAnimatingFaction) >= 0
        Return True
    EndIf
    Faction osFac = _OStimSceneFaction()
    If osFac && akActor.GetFactionRank(osFac) >= 0
        Return True
    EndIf
    ; Fallback: neither faction assigned in CK — get SexLab's animating faction via the bridge.
    Faction slf = SkyrimNet_BakaSL.AnimFaction()
    If slf && akActor.GetFactionRank(slf) >= 0
        Return True
    EndIf
    Return False
EndFunction

; ============================================================
; Actor locking — prevents double-triggering on busy actors
; ============================================================
Bool Function IsActorLocked(Actor akActor)
    Return StorageUtil.GetIntValue(akActor, "SNBaka.Locked", 0) == 1
EndFunction

; True if akA1/akA2 are the exact aggressor+victim pair of a currently-open Baka ground window — i.e.
; the SAME aggressor who owns this victim's window trying a follow-up action (PinHelpless, GropeHelpless,
; etc.) on them. The victim is deliberately kept locked for the whole window (see _UnlockAttackerOnly's
; own comment: "the victim remains locked during the ground window") to stop unrelated third parties
; grabbing them mid-window — but that same lock was silently blocking the window's OWN aggressor from
; ever using those actions on their own victim, since LockBoth refused unconditionally. This carve-out
; only ever matches the specific pair that opened the window, so a third party still gets refused.
Bool Function _IsGroundWindowOwner(Actor akA1, Actor akA2)
    If (StorageUtil.GetFormValue(akA2, "SNBaka.GroundWindowAggressor") as Actor) == akA1
        Return True
    EndIf
    If (StorageUtil.GetFormValue(akA1, "SNBaka.GroundWindowAggressor") as Actor) == akA2
        Return True
    EndIf
    Return False
EndFunction

Bool Function LockBoth(Actor akA1, Actor akA2)
    Bool alreadyLocked = IsActorLocked(akA1) || IsActorLocked(akA2)
    Bool windowOwner    = alreadyLocked && _IsGroundWindowOwner(akA1, akA2)
    If alreadyLocked && !windowOwner
        _Log("[SNBaka] LockBoth: refused — " + akA1 + "/" + akA2 + " already locked (A1=" + IsActorLocked(akA1) + " A2=" + IsActorLocked(akA2) + "), not the ground-window owner pair")
        Return False
    EndIf
    If windowOwner
        _Log("[SNBaka] LockBoth: ground-window-owner carve-out used for " + akA1 + " -> " + akA2)
    EndIf
    StorageUtil.SetIntValue(akA1, "SNBaka.Locked", 1)
    StorageUtil.SetIntValue(akA2, "SNBaka.Locked", 1)
    _bQTEDefeated      = False
    _bAELVictimEscaped = False
    ; Locking onto a DOWNED actor = an interaction with them. Reset _bResetDownWindow so Baka's own
    ; ground window (when it's the one holding them) keeps them down while the aggressor keeps engaging.
    ; Acheron's hold is unaffected by this — it tracks presence independently (_AnyLiveActorNear), not
    ; a Baka interaction timestamp.
    _MarkDownInteractionIfDowned(akA1)
    _MarkDownInteractionIfDowned(akA2)
    ; If we're locking mid-fight (a defeat/escalation while combat is still live), drop the participants
    ; out of combat NOW so the held anim can play — otherwise _ShouldAbort sees the attacker already
    ; IsInCombat and breaks the scene on the very first poll. We use ONLY the Calm spell here (it self-
    ; expires and breaks the instant the actor is actually hit), so there's no permanent aggression flag
    ; to leak and no restore to manage: after this, _ShouldAbort trips only on a genuine hit. Gated on
    ; IsInCombat so every out-of-combat interaction behaves exactly as before.
    If akA1.IsInCombat() || (akA2 && akA2.IsInCombat())
        _CalmForAnim(akA1, akA2)
    EndIf
    Return True
EndFunction

; Calm-spell-only combat drop for an in-combat defeat anim (see LockBoth). No-op without the spell or
; out of combat. Skips the player (controlled by DisablePlayerControls, not calm).
Function _CalmForAnim(Actor akA1, Actor akA2)
    If !SNBakaCalm
        Return
    EndIf
    If akA1 && akA1 != PlayerRef && akA1.IsInCombat()
        akA1.StopCombat()
        SNBakaCalm.Cast(akA1, akA1)
    EndIf
    If akA2 && akA2 != PlayerRef && akA2.IsInCombat()
        akA2.StopCombat()
        SNBakaCalm.Cast(akA2, akA2)
    EndIf
    ; Let StopCombat + Calm settle so the first _ShouldAbort poll doesn't catch a stale combat flag.
    Utility.Wait(0.3)
EndFunction

Function _MarkDownInteractionIfDowned(Actor ak)
    If ak && _IsDownedAny(ak)
        _bResetDownWindow = True
        _Log("[SNBaka] _MarkDownInteractionIfDowned: " + ak + " is downed — _bResetDownWindow=True")
    EndIf
EndFunction

Function UnlockBoth(Actor akA1, Actor akA2)
    StorageUtil.SetIntValue(akA1, "SNBaka.Locked",        0)
    StorageUtil.SetIntValue(akA2, "SNBaka.Locked",        0)
    StorageUtil.SetIntValue(akA1, "SNBaka.StopRequested", 0)
    StorageUtil.SetIntValue(akA2, "SNBaka.StopRequested", 0)
    If akA1 == PlayerRef || akA2 == PlayerRef
        Game.EnablePlayerControls()
    EndIf
    _StartCooldown(akA1)
    ; After an INTERMEDIATE action (grope/choke/pin/fondle/kiss) the victim is still downed — re-prompt
    ; the aggressor with the escalate-or-back-down decision, mirroring Baka's own post-takedown window.
    ; RESOLVING actions (Escalate/Capture/HelpUp/Release/SellToSlavery) clear the down state before they
    ; unlock, so this gate (victim still downed) skips them automatically and won't loop a resolution.
    _CueDecisionIfDowned(akA1, akA2)
EndFunction

; Fire the "escalate / help / release" decision cue when, after an action, the VICTIM is still downed —
; i.e. the aggressor did something that didn't resolve the encounter. Debounced so it can't double-fire
; with _RecoveryPeriod, and it pushes the down window so the victim stays put for the decision. Fires
; regardless of who owns the hold (Baka window or Acheron): this is the IMMEDIATE per-action nudge,
; separate from Acheron's slower ~20s ambient "still down" reminder — the two serve different moments
; (right after an action vs. nothing has happened in a while) and both are wanted.
; abResetWindow: True (default) for a REAL interaction (via UnlockBoth) — the aggressor just acted on
; the victim, so keep them down for the decision. False for a PASSIVE periodic reminder (the
; _DefeatGroundWindow "don't go silent" re-cue) — nobody actually did anything, so this must NOT reset
; the recovery clock, or "nobody's around -> recover after fEscalationWindow" could never fire; only
; the 240s hard cap would ever save a truly abandoned victim. Found this the hard way: the periodic
; re-cue was unconditionally resetting the window every ~15s regardless of presence.
Function _CueDecisionIfDowned(Actor akInitiator, Actor akVictim, Bool abResetWindow = True)
    If !akVictim || !akInitiator || akVictim == akInitiator
        Return
    EndIf
    If !_IsDownedAny(akVictim)
        Return
    EndIf
    Float now = Utility.GetCurrentRealTime()
    If now - _fLastOpportunityRT < 5.0
        _Log("[SNBaka] _CueDecisionIfDowned: skipped — debounced (" + (now - _fLastOpportunityRT) + "s since last, need 5.0s), abResetWindow=" + abResetWindow + " still applied" )
        If abResetWindow
            _bResetDownWindow = True   ; the window-keep-alive effect still applies even when the cue itself is debounced
        EndIf
        Return
    EndIf
    _fLastOpportunityRT = now
    If abResetWindow
        _bResetDownWindow = True   ; keep them down for the decision — Baka's own ground window keys off this
    EndIf
    _Log("[SNBaka] _CueDecisionIfDowned: firing baka_opportunity for " + akInitiator + " -> " + akVictim + " (abResetWindow=" + abResetWindow + ")")
    ; Bare fact only (no action list) — this "content" arg is SkyrimNet's own narrator/history line,
    ; separate from whatever the baka_opportunity.yaml trigger renders for the same eventType. The YAML's
    ; content already names Escalate/HelpUp/Release plus the talk/demand framing; repeating it here just
    ; produced two different-looking lines for the same moment (confirmed via a screenshot of doubled text).
    SkyrimNetApi.RegisterEvent("baka_opportunity", \
        akVictim.GetDisplayName() + " is still down in front of " + akInitiator.GetDisplayName() + ".", \
        akInitiator, akVictim)
EndFunction

Function _StartCooldown(Actor akInitiator = None)
    If akInitiator && akInitiator == PlayerRef
        _bCooldownActive = True
        RegisterForSingleUpdate(fPlayerCooldown)
    ElseIf akInitiator
        Float now = Utility.GetCurrentGameTime()
        StorageUtil.SetFloatValue(akInitiator, "SNBaka.LastActionTime", now)
        _fLastNPCActionTime = now
    EndIf
EndFunction

Event OnUpdate()
    _bCooldownActive = False
EndEvent

; Console/MCM safety valve: clears player locks and cooldown when an animation
; gets stuck and leaves the player unable to trigger new actions.
; Usage: CGF "SkyrimNet_BakaIntegration.EmergencyReset" 0
Function EmergencyReset()
    If PlayerRef
        StorageUtil.SetIntValue(PlayerRef, "SNBaka.Locked",        0)
        StorageUtil.SetIntValue(PlayerRef, "SNBaka.StopRequested", 0)
        StorageUtil.SetIntValue(PlayerRef, "SNBaka.OnGround",      0)
    EndIf
    _bCooldownActive      = False
    _bQTEDefeated         = False
    _bEscalateRequested   = False
    _bReleaseRequested    = False
    _bAELStruggleComplete = False
    _bAELVictimEscaped    = False
    _bPlayerIsVictim      = False
    _bDruggedEscalation   = False
    _fLastNPCActionTime   = 0.0
    ; Undo any leftover height-match scaling (e.g. an NPC stuck resized after a bad exit).
    _RestoreAllScaledActors()
    PlayerRef.SetDontMove(False)   ; safety: release any leftover player pin
    UnregisterForAllModEvents()
    RegisterForModEvent("AEL_GameEnd", "OnAELGameEnd")
    Game.EnablePlayerControls()
EndFunction

; Signal any ongoing animation involving akTarget to stop cleanly.
; Safe to call even if the actor is not currently in an animation.
Function RequestStop(Actor akTarget)
    If akTarget
        StorageUtil.SetIntValue(akTarget, "SNBaka.StopRequested", 1)
    EndIf
EndFunction

Bool Function _StopRequested(Actor akA1, Actor akA2)
    Return StorageUtil.GetIntValue(akA1, "SNBaka.StopRequested", 0) == 1 \
        || StorageUtil.GetIntValue(akA2, "SNBaka.StopRequested", 0) == 1
EndFunction

; ============================================================
; Sounds
; ============================================================
Function PlayPanicSound(Actor akTarget)
    If PanicSoundF && akTarget && HasFemaleBody(akTarget)
        PanicSoundF.Play(akTarget)
    EndIf
EndFunction

Function PlaySmackSound(Actor akTarget)
    If SmackSound && akTarget
        SmackSound.Play(akTarget)
    EndIf
EndFunction

; ============================================================
; Animation state tracking / SkyrimNet decorator
; ============================================================
Function RecordAnimation(Actor akActor, String animTag, String partnerName)
    If !akActor
        Return
    EndIf
    StorageUtil.SetStringValue(akActor, "SNBaka.LastAnim",    animTag)
    StorageUtil.SetStringValue(akActor, "SNBaka.LastPartner", partnerName)
EndFunction

; Global — called by SkyrimNet to decorate actor context.
; Must be Global because SkyrimNet calls it by name reflection.
SkyrimNet_BakaIntegration Function GetMain() Global
    Return Game.GetFormFromFile(0x000D62, "SkyrimNet_BakaIntegration.esp") as SkyrimNet_BakaIntegration
EndFunction

String Function GetBakaState(Actor akActor) Global
    If !akActor
        Return "{}"
    EndIf
    Bool   locked   = StorageUtil.GetIntValue(akActor,    "SNBaka.Locked",      0) == 1
    ; Downed = our own defeat OR any external bleedout (Surrender, combat defeat) OR the Acheron bridge
    ; holding them down. The Acheron case is CRUCIAL: when the integration owns the down we clear
    ; SNBaka.OnGround, so without this the decorator would report the held victim as NOT downed and the
    ; LLM would never surface Escalate/HelpUp/etc. This is how the LLM learns a held actor is helpless.
    Bool   downed   = _IsDownedAny(akActor)
    String lastAnim    = StorageUtil.GetStringValue(akActor, "SNBaka.LastAnim",    "")
    String lastPartner = StorageUtil.GetStringValue(akActor, "SNBaka.LastPartner", "")
    String lockedStr   = "false"
    String groundStr   = "false"
    If locked
        lockedStr = "true"
    EndIf
    If downed
        groundStr = "true"
    EndIf
    String json = "{"
    json += "\"in_baka_animation\":"      + lockedStr   + ","
    json += "\"on_ground\":"              + groundStr   + ","
    json += "\"downed_and_vulnerable\":"  + groundStr   + ","
    json += "\"last_baka_animation\":\""  + lastAnim    + "\","
    json += "\"last_baka_partner\":\""    + lastPartner + "\""
    json += "}"
    Return json
EndFunction

; Global — simple bool decorator: is this actor currently in a Baka animation?
; Returns "true" / "false" string for SkyrimNet decorator injection.
String Function IsInBakaAnimation(Actor akActor) Global
    If !akActor
        Return "false"
    EndIf
    If StorageUtil.GetIntValue(akActor, "SNBaka.Locked", 0) == 1
        Return "true"
    EndIf
    Return "false"
EndFunction

; ============================================================
; Resist minigame
;
; Key registration and polling are split:
;   _PollResist  — self-contained wait loop used by PlayPairedLoopAnim
;                  and PlayPairedSimpleAnim. Registers the key, polls,
;                  and cleans up. Returns True if the player escaped.
;
;   PlayPairedSequence inlines its own polling so it can interleave
;   animation stage events between ticks without a nested Wait.
;
; Both paths write to the same _iResistPresses / _bResistActive
; instance variables. OnKeyDown increments _iResistPresses while
; _bResistActive is True.
; ============================================================
; Fired by AEL MakeGame() when the flash minigame ends.
; afNumArg > 0 = player won. _bPlayerIsVictim determines what "player won" means.
Event OnAELGameEnd(string asEventName, string asStringArg, float afNumArg, form akSender)
    Bool playerWon = afNumArg > 0
    If _bPlayerIsVictim
        _bAELVictimEscaped = playerWon
    Else
        _bAELVictimEscaped = !playerWon
    EndIf
    _bAELStruggleComplete = True
    _Log("[SNBaka] OnAELGameEnd: afNumArg=" + afNumArg + " playerIsVictim=" + _bPlayerIsVictim + " victimEscaped=" + _bAELVictimEscaped)
    SPE_Interface.CloseCustomMenu()
EndEvent

; Handles the resist window for one animation segment.
; NPC-NPC (or bResistEnabled off, or AEL not installed): waits out duration.
; Player involved: launches AEL QTE via MakeAnimation, polls until done or duration expires.
;
; akA2 = victim (plays sResistA2), akA1 = aggressor (plays sResistA1).
; Returns True if the victim escaped. Sets _bQTEDefeated = True when attacker wins.
; sHoldA1/sHoldA2 = the anim each actor should be holding during the QTE — re-asserted on a tick so a
; PC-NPC actor can't drift off / stop animating mid-minigame (was the "NPC freezes during PC-NPC" bug).
Bool Function _PollResist(Actor akA1, Actor akA2, Float duration, \
        String sResistA1 = "Babo_DefeatResist_A1_S1", \
        String sResistA2 = "Babo_DefeatResist_A2_S1", \
        String sHoldA1 = "", String sHoldA2 = "")
    Bool a1IsPlayer = (akA1 == PlayerRef)
    Bool a2IsPlayer = (akA2 == PlayerRef)
    If (!a1IsPlayer && !a2IsPlayer) || !bResistEnabled
        Return _HoldAnim(akA1, akA2, sHoldA1, sHoldA2, duration)
    EndIf

    ; Let the animation play for fQTEStartDelay seconds before the QTE overlay appears.
    ; Subtract from duration so total animation time stays constant.
    If fQTEStartDelay > 0.0
        Float delay = fQTEStartDelay
        If delay >= duration - 1.0
            delay = duration - 1.0  ; always leave at least 1s for the QTE
        EndIf
        If delay > 0.0
            _Log("[SNBaka] _PollResist: pre-QTE delay " + delay + "s")
            If _HoldAnim(akA1, akA2, sHoldA1, sHoldA2, delay)
                Return False
            EndIf
            duration = duration - delay
        EndIf
    EndIf

    _Log("[SNBaka] _PollResist: starting QTE. A1=" + akA1.GetDisplayName() + " A2=" + akA2.GetDisplayName() + " diff=" + fResistDifficulty + " window=" + duration + "s")
    _bAELStruggleComplete = False
    _bAELVictimEscaped    = False
    _bPlayerIsVictim      = a2IsPlayer
    RegisterForModEvent("AEL_GameEnd", "OnAELGameEnd")

    Bool ael_ok = AELStruggle.MakeGame(fResistDifficulty)
    _Log("[SNBaka] _PollResist: MakeGame returned " + ael_ok)
    If !ael_ok
        _Log("[SNBaka] _PollResist: MakeGame failed — timed wait")
        UnregisterForModEvent("AEL_GameEnd")
        Return _HoldAnim(akA1, akA2, sHoldA1, sHoldA2, duration)
    EndIf

    Float elapsed = 0.0
    Float tick    = 0.1
    Float sinceRe = 0.0
    While elapsed < duration && !_bAELStruggleComplete && !_ShouldAbort(akA1, akA2)
        Utility.Wait(tick)
        elapsed += tick
        sinceRe += tick
        ; Re-assert the held pose ~every 2s so the actors don't drift off-anim during the QTE.
        If sinceRe >= 2.0
            sinceRe = 0.0
            If sHoldA1 != ""
                Debug.SendAnimationEvent(akA1, sHoldA1)
            EndIf
            If sHoldA2 != ""
                Debug.SendAnimationEvent(akA2, sHoldA2)
            EndIf
        EndIf
    EndWhile
    ; If the Flash QTE is still running (poll timed out), force-close the menu so
    ; the player is not left stuck. Wait briefly in case the close triggers AEL_GameEnd.
    If !_bAELStruggleComplete
        SPE_Interface.CloseCustomMenu()
        Utility.Wait(0.3)
    EndIf
    UnregisterForModEvent("AEL_GameEnd")

    Bool victimEscaped = _bAELStruggleComplete && _bAELVictimEscaped
    _Log("[SNBaka] _PollResist: complete=" + _bAELStruggleComplete + " escaped=" + victimEscaped)
    If _bAELStruggleComplete && !victimEscaped
        _bQTEDefeated = True
    EndIf
    Return victimEscaped
EndFunction

; ============================================================
; Core animation helpers
;
; All-All design:
;   A1 always receives the "M" / "A01" / "A1" role animation (initiator).
;   A2 always receives the "F" / "A02" / "A2" role animation (target).
;   The M/F suffix in Baka's naming is ROLE-based, not sex-based.
;   Any gender combination works for the base animations.
;
;   Anatomically-specific actions (breasts, privates) gate on
;   HasFemaleBody(akA2) inside their Execute functions, NOT here.
;
; Positioning formula (Baka FNIS local-space → world):
;   worldX = refX + (yLocal * Sin(angZ)) + (xLocal * Cos(angZ))
;   worldY = refY + (yLocal * Cos(angZ)) - (xLocal * Sin(angZ))
;   a1AngZ = angZ + rotOffset  (0 = same dir as A2, 180 = facing A2)
; ============================================================

; Returns True if the animation should be cut short.
Bool Function _ShouldAbort(Actor akA1, Actor akA2)
    ; NO per-tick protection re-assert here anymore — under the park design the victim is either
    ; Acheron-DEFEATED (native protection, nothing to re-assert) or keep-pacified, and the sweep +
    ; pacify + traces every poll measurably clogged the starved Nolvus Papyrus VM (confirmed report:
    ; "many seconds between the teleport and the struggle beginning"). Protection is applied once at
    ; each transition (_SetupPair / scene start); that's where it belongs now.
    ; A2 entering combat is expected (victim wants to fight back) — do not abort for that.
    ; Only abort if either actor dies/disabled, attacker enters combat,
    ; actors are too far apart (cell leave / teleport), or stop requested.
    If akA1.IsDead() || akA2.IsDead()
        _Log("[SNBaka] _ShouldAbort: dead actor — breaking scene")
        Return True
    EndIf
    If akA1.IsDisabled() || akA2.IsDisabled()
        _Log("[SNBaka] _ShouldAbort: disabled actor — breaking scene")
        Return True
    EndIf
    If akA1.IsInCombat()
        ; Combat state alone is NOT enough to break the animation anymore -- confirmed from testing:
        ; a faction ally attacking the pair's own victim (second falmer vs the player mid-struggle)
        ; flips the pacified aggressor's IsInCombat via the faction alarm, which aborted every struggle
        ; ~3s in, three times in one session, without anything ever touching the aggressor itself.
        ; Only a live fight against someone OTHER than this pair's own victim counts -- that's what a
        ; real hit on the aggressor produces (its combat target switches to whoever hit it), which
        ; preserves the "a hit to the aggressor stops the aggression" rule this check exists for.
        Actor a1t = akA1.GetCombatTarget()
        If a1t && a1t != akA2 && !a1t.IsDead() && !a1t.IsDisabled() && !_IsDownedAny(a1t)
            _Log("[SNBaka] _ShouldAbort: " + akA1.GetDisplayName() + " in combat against " + a1t.GetDisplayName() + " — breaking scene")
            Return True
        EndIf
        ; else: alarm-only combat state (target is the pair's own victim, downed, dead, or nobody) —
        ; not an interruption, the struggle continues.
    EndIf
    If akA1.GetDistance(akA2) > 1500.0
        _Log("[SNBaka] _ShouldAbort: actors too far apart — breaking scene")
        Return True
    EndIf
    Return _StopRequested(akA1, akA2)
EndFunction

; Waits duration seconds in tick-sized steps.
; Returns True if aborted early due to combat or death.
Bool Function _WaitOrAbort(Actor akA1, Actor akA2, Float duration, Float tick = 0.5)
    Float elapsed = 0.0
    While elapsed < duration
        Utility.Wait(tick)
        elapsed += tick
        If _ShouldAbort(akA1, akA2)
            Return True
        EndIf
    EndWhile
    Return False
EndFunction

; Holds both actors FROZEN on the given pose for `duration`: waits in ticks and RE-SENDS the pose
; anim every tick, so a one-shot/short Babo clip that ends — or an idle/OAR replacer — can't make
; them drift into another animation mid-scene. Re-sending the event an actor is already looping is a
; no-op, but it snaps a drifted actor straight back. Returns True if the scene aborted.
Bool Function _HoldAnim(Actor akA1, Actor akA2, String animA1, String animA2, Float duration, Float tick = 2.0)
    Float elapsed = 0.0
    While elapsed < duration
        ; (Re-)assert the pose at the start of every tick, then wait. Sending an event an actor is
        ; already in is a no-op; sending it to a drifted actor snaps them back onto the scene anim.
        If animA1 != ""
            Debug.SendAnimationEvent(akA1, animA1)
        EndIf
        If animA2 != ""
            Debug.SendAnimationEvent(akA2, animA2)
        EndIf
        ; Clamp the final step to land EXACTLY on duration (no overshoot — that was the extra ~2s hold).
        Float step = tick
        If elapsed + step > duration
            step = duration - elapsed
        EndIf
        If _WaitOrAbort(akA1, akA2, step)
            Return True
        EndIf
        elapsed += step
    EndWhile
    Return False
EndFunction

; True if the aggressor who owns this ground window is still within `radius` of the victim. Drives the
; presence-based hold in _DefeatGroundWindow: while they're around, the victim stays down; they only
; recover once the aggressor has truly left.
; Pure Yamete Redux style: GetDistance() against the ONE known reference (SNBaka.GroundWindowAggressor,
; set right before the wait loop starts — the only caller of this function), no scanning for unknowns.
; An unrelated bystander who isn't the tracked aggressor is an accepted blind spot of going this simple
; — matches Acheron's _NearbyThreat, same trade-off on both sides.
Bool Function _AnyActorNear(Actor akVictim, Float radius)
    If !akVictim
        Return False
    EndIf
    Actor aggressor = StorageUtil.GetFormValue(akVictim, "SNBaka.GroundWindowAggressor") as Actor
    ; A DOWNED aggressor doesn't count as "still here" — they can't threaten or witness anything.
    If !aggressor || aggressor == akVictim || aggressor.IsDead() || aggressor.IsDisabled() || _IsDownedAny(aggressor)
        Return False
    EndIf
    Return akVictim.GetDistance(aggressor) < radius
EndFunction

; True if a fight is still going on near the victim — the victim themselves, or any actor within
; `radius`, is in combat. Gates escalation (the only combat-gated step): no forced sex until this is
; false. Cell sweep covers the usual same-cell/nearby combatants.
Bool Function _CombatNear(Actor akCenter, Float radius)
    If !akCenter
        Return False
    EndIf
    If _HasLiveCombatTarget(akCenter)
        Return True
    EndIf
    Cell c = akCenter.GetParentCell()
    If c
        Int n = c.GetNumRefs(62)   ; 62 = kCharacter
        Int i = 0
        While i < n
            Actor a = c.GetNthRef(i, 62) as Actor
            If a && a != akCenter && !a.IsDead() && _HasLiveCombatTarget(a) && akCenter.GetDistance(a) < radius
                Return True
            EndIf
            i += 1
        EndWhile
    EndIf
    Return False
EndFunction

; IsInCombat() alone is known to linger stale with no live target (confirmed repeatedly in this file —
; see the creature-escalation "succeed but combatNear stuck true, scene never starts, QTE anim just
; re-plays on every retry" bug this was written to fix). A genuine ongoing fight has an actual live
; target; a stale flag with nothing to point at doesn't. Deliberately NOT a blanket StopCombat here —
; that would also pull the actor out of a fight with someone else entirely unrelated to this check.
Bool Function _HasLiveCombatTarget(Actor a) Global
    If !a.IsInCombat()
        Return False
    EndIf
    Actor target = a.GetCombatTarget()
    ; A DOWNED combat target doesn't count as a live fight -- confirmed real deadlock from testing:
    ; a falmer whose only remaining "combat target" was an already-downed victim kept reading as
    ; "still actively fighting someone else" on every single engagement attempt, blocking escalation
    ; on every downed victim around it indefinitely (combat state never resolves against a target
    ; that's helpless/ghosted and can neither die nor fight back).
    Return target && !target.IsDead() && !target.IsDisabled() && !_IsDownedAny(target)
EndFunction

; Called the instant a struggle resolves with the victim defeated (creature OR human attacker) --
; starts the post-defeat grace window (fPostDefeatGraceDuration) so passive creature paths leave this
; specific victim alone for a while instead of re-picking them the moment they're vulnerable again.
Function _StampDefeatGrace(Actor akVictim)
    If !akVictim
        Return
    EndIf
    StorageUtil.SetFloatValue(akVictim, "SNBaka.DefeatGraceUntilRT", Utility.GetCurrentRealTime() + fPostDefeatGraceDuration)
EndFunction

; True while akVictim is still within their post-defeat grace window AND hasn't already been dragged
; back into a real fight -- a live combat target means "some of them attacked somebody", which ends the
; grace early by design (see the property comment on fPostDefeatGraceDuration).
Bool Function _InDefeatGrace(Actor akVictim)
    If !akVictim || _HasLiveCombatTarget(akVictim)
        Return False
    EndIf
    Return Utility.GetCurrentRealTime() < StorageUtil.GetFloatValue(akVictim, "SNBaka.DefeatGraceUntilRT", 0.0)
EndFunction

; Delegate a down to Acheron if it's installed. No plugin probe needed: DefeatActor takes (IsDefeated
; becomes true) when Acheron is present, and is a harmless no-op when it isn't — so a false return means
; "Acheron absent, use Baka's own fallback window". Returns True if Acheron took ownership of the down.
; Ask the SkyrimNet Acheron INTEGRATION to defeat + hold this actor. We do NOT call Acheron ourselves —
; the integration owns downing (it defeats via Acheron, marks the hold, and fires the cue), exactly like
; a combat defeat flows through it. Returns True if the integration is present (so we skip Baka's own
; window); False when it isn't installed, so the caller runs Baka's fallback _DefeatGroundWindow.
Bool Function _DelegateDownToAcheron(Actor akVictim)
    If !akVictim || !PlayerRef
        Return False
    EndIf
    ; The integration stamps this flag on init + every self-heal; absent == integration not installed.
    If StorageUtil.GetIntValue(PlayerRef, "SNAcheron.Present", 0) != 1
        Return False
    EndIf
    ; Present means INSTALLED, not enabled -- the bridge's OnDownRequest gates on its own MCM master
    ; switch and silently DROPS queued victims while disabled. Delegating into that void cleared our
    ; local flags with nobody ever actually downing the victim (they'd just stand there). Check the
    ; same shared StorageUtil key its own MCM writes, so a disabled bridge routes us to the local
    ; fallback window instead, exactly like an absent one.
    If StorageUtil.GetIntValue(PlayerRef, "SNAcheron.Enabled", 1) != 1
        Return False
    EndIf
    ; Already held (e.g. Acheron's own combat-defeat consequence already picked this same takedown up)?
    ; Don't re-queue/re-cue — that fired a second, redundant "is down" narration for one event.
    If StorageUtil.GetIntValue(akVictim, "SNAcheron.Held", 0) == 1
        Return True
    EndIf
    StorageUtil.FormListAdd(PlayerRef, "SNBaka.AcheronDownQueue", akVictim)
    SendModEvent("SNBaka_RequestAcheronDown")
    Return True
EndFunction

; Single source of truth for "is this actor currently downed", covering all three ways a victim can
; be helpless: our own ground window (SNBaka.OnGround), a vanilla bleedout, OR a PURE Acheron hold
; (SNAcheron.Held) with neither of the other two flags set — e.g. a victim delegated to Acheron via
; _DelegateDownToAcheron never gets SNBaka.OnGround, and Acheron.DefeatActor does not reliably flip
; the vanilla IsBleedingOut() state either. Every action that gates on "is the target downed" (Escalate,
; Release, HelpUp, Capture, CreatureEscalate) must use this — a bare OnGround/IsBleedingOut check silently
; rejects a target the acheron_downed/acheron_opportunity cues just told the LLM to act on.
; Global (no instance state used) so GetBakaState — itself Global, called by reflection from SkyrimNet —
; can share this exact same check instead of carrying its own copy.
Bool Function _IsDownedAny(Actor ak) Global
    If !ak
        Return False
    EndIf
    Return StorageUtil.GetIntValue(ak, "SNBaka.OnGround", 0) == 1 \
        || ak.IsBleedingOut() \
        || StorageUtil.GetIntValue(ak, "SNAcheron.Held", 0) == 1
EndFunction

; Clears an external Acheron hold (bleedout AND/OR our own SNAcheron.Held flag) so a resolving action
; (HelpUp/Release/Capture/SellToSlavery/CreatureEscalate) can take the victim over cleanly. Safe to call
; on an actor Acheron never held (no-op). Deliberately NOT called by the human Escalate path — the calm/
; pacify hold must persist THROUGH the sex scene; _EscalationCleanup re-delegates back to Acheron after.
; abFullRescue=False skips Acheron's own RescueActor call (the dramatic "saved" event/stat-reset) and
; only clears the pacify hold via ReleaseActor -- used by Stand Back, which should let the victim get
; up locally without Acheron treating it as a full rescue (that's what "help up" is for).
Function _ClearAcheronHold(Actor ak, Bool abFullRescue = True, Bool abKeepPacified = False)
    If !ak
        Return
    EndIf
    If ak.IsBleedingOut() || StorageUtil.GetIntValue(ak, "SNAcheron.Held", 0) == 1
        ; Held cleared FIRST -- the Acheron bridge's OnActorRescued now redowns anyone rescued while
        ; still flagged Held (its "nobody recovers on their own" rule); clearing before RescueActor is
        ; what marks this rescue as sanctioned. RescueActor is documented as queued/async, so the event
        ; fires well after this line, but don't rely on that ordering by accident -- make it explicit.
        StorageUtil.SetIntValue(ak, "SNAcheron.Held", 0)
        ; Only touch Acheron's own rescue/release if Acheron still THINKS this actor is defeated --
        ; calling RescueActor/ReleaseActor on an actor it doesn't track as defeated is a call its native
        ; code was never meant to receive. Shared native API, no hard reference needed.
        If Acheron.IsDefeated(ak)
            If abKeepPacified
                ; INTERACTION TAKEOVER (a struggle/scene is about to own this actor): end the defeat
                ; but keep Acheron's native pacify ON through the handoff. Rescuing with abRelease=true
                ; + ReleaseActor (below) fully strips the protection, and every attempt to rebuild it by
                ; hand afterward lost a race with the QUEUED rescue task — confirmed live, repeatedly:
                ; "EVERY time somebody gets escalated, during the period we free from acheron, enemies
                ; aggro." abRelease=false is Acheron's own primitive for exactly this.
                Acheron.RescueActor(ak, false)
            Else
                If abFullRescue
                    Acheron.RescueActor(ak, true)
                EndIf
                ; OSimpleDefeat (a sibling mod doing the same Acheron+OStim defeat/release flow) always pairs
                ; RescueActor with an explicit ReleaseActor call. RescueActor is documented as QUEUED/async;
                ; ReleaseActor removes the pacify state immediately — belt-and-suspenders so pacify doesn't
                ; linger until Acheron's queued task gets around to it.
                Acheron.ReleaseActor(ak)
            EndIf
        Else
            _Log("[SNBaka] _ClearAcheronHold: Acheron no longer considers " + ak.GetDisplayName() + " defeated -- skipping RescueActor/ReleaseActor")
        EndIf
        _Log("[SNBaka] _ClearAcheronHold: cleared Acheron hold on " + ak.GetDisplayName() + " (abFullRescue=" + abFullRescue + " keepPacified=" + abKeepPacified + ")")
    EndIf
EndFunction

; The victim WON the struggle/QTE — they overpowered the attacker and are NOT downed. Clear any downed
; state and, if they were being held by Acheron (e.g. they struggled up from a prior down), ask the
; integration to RELEASE them so they leave Acheron and recover. They are fit to keep fighting — no calm,
; no pacify, no further handling.
Function _OnVictimWon(Actor akWinner, Actor akLoser)
    If !akWinner
        Return
    EndIf
    StorageUtil.SetIntValue(akWinner,    "SNBaka.Locked",   0)
    StorageUtil.SetIntValue(akWinner,    "SNBaka.OnGround", 0)
    StorageUtil.SetStringValue(akWinner, "SNBaka.DownPose", "")
    StorageUtil.SetIntValue(akWinner,    "SNBaka.Captive",  0)
    ; Hand the release to the integration (it owns the Acheron hold), same as we hand it the down.
    If StorageUtil.GetIntValue(PlayerRef, "SNAcheron.Present", 0) == 1 && Acheron.IsDefeated(akWinner)
        StorageUtil.FormListAdd(PlayerRef, "SNBaka.AcheronReleaseQueue", akWinner)
        SendModEvent("SNBaka_RequestAcheronRelease")
    EndIf
EndFunction

; Suppress an NPC's AI for the duration of a scene — this is how SexLab keeps actors
; from breaking out of a held pose (LockActor → AddPackageOverride DoNothing).  We were
; missing this: SetRestrained/SetDontMove stop walking but NOT package re-evaluation, so
; the NPC's AI reverted its animation after a few seconds.  Force a condition-free
; DoNothing package at high priority; remove it at cleanup.  Player is skipped (it uses
; DisablePlayerControls instead).  No-op if SNBakaDoNothing isn't assigned yet.
Function _HoldActorAI(Actor akActor, Bool hold)
    If !akActor || akActor == PlayerRef
        Return
    EndIf
    If !SNBakaDoNothing
        ; Loud on purpose: if this fires, the CK property isn't set and the SexLab-style
        ; hold can't work — explains an NPC dropping its pose.
        _Log("[SNBaka] _HoldActorAI: SNBakaDoNothing package is NONE — AI NOT suppressed for " + akActor.GetDisplayName() + " (set the property in CK)")
        Return
    EndIf
    If hold
        ActorUtil.AddPackageOverride(akActor, SNBakaDoNothing, 100, 1)
    Else
        ActorUtil.RemovePackageOverride(akActor, SNBakaDoNothing)
    EndIf
    akActor.EvaluatePackage()
    _Log("[SNBaka] _HoldActorAI: " + akActor.GetDisplayName() + " hold=" + hold + " (DoNothing override)")
EndFunction

; Pacify an NPC for the duration of an interaction so it can't enter/initiate combat (which
; broke the scene mid-animation). Sets Aggression 0 + stops combat; stores the original once
; (guarded by the SNBaka.Pacified flag so double-calls during the active anim AND the down
; window don't lose it). Never touches the player.
Function _PacifyActor(Actor ak, Bool on)
    If !ak || ak == PlayerRef
        Return
    EndIf
    If on
        If StorageUtil.GetIntValue(ak, "SNBaka.Pacified", 0) == 0
            StorageUtil.SetFloatValue(ak, "SNBaka.OrigAggr", ak.GetActorValue("Aggression"))
            StorageUtil.SetIntValue(ak, "SNBaka.Pacified", 1)
        EndIf
        ak.SetActorValue("Aggression", 0.0)
        ak.StopCombatAlarm()
        ak.StopCombat()
        ; Robust combat-stop (Surrender's trick): a Calm-archetype spell reliably drops the actor out
        ; of combat where aggression-0 alone can be re-triggered by faction hostility. No-op if unset.
        If SNBakaCalm
            SNBakaCalm.Cast(ak, ak)
        EndIf
        _Log("[SNBaka] _PacifyActor: calmed " + ak.GetDisplayName() + " (aggr->0, StopCombat, Calm cast; wasInCombat now=" + ak.IsInCombat() + ")")
    ElseIf StorageUtil.GetIntValue(ak, "SNBaka.Pacified", 0) == 1
        ak.SetActorValue("Aggression", StorageUtil.GetFloatValue(ak, "SNBaka.OrigAggr", 1.0))
        StorageUtil.SetIntValue(ak, "SNBaka.Pacified", 0)
        ; The Calm EFFECT cast on pacify does NOT end with the aggression restore — with any real
        ; duration it kept "liberated" aggressors becalmed and passive long after the struggle
        ; (confirmed: the giant Joylie broke free from attacked nobody). Dispel it explicitly.
        If SNBakaCalm
            ak.DispelSpell(SNBakaCalm)
        EndIf
        _Log("[SNBaka] _PacifyActor: restored " + ak.GetDisplayName() + " (aggr back to " + StorageUtil.GetFloatValue(ak, "SNBaka.OrigAggr", 1.0) + ", Calm dispelled)")
    EndIf
EndFunction

; Two-way "combat drops the victim" protection, with one critical exception: NEVER Acheron-pacify the
; PLAYER. Acheron's pacify on the player is native lockdown we can't partially undo from Papyrus, and
; it shipped a locked/stiff camera during struggles the build it was introduced (confirmed report).
; The player gets the stale-lock sweep only: hits whiff on ghost, and the struggle tick (_ShouldAbort)
; plus the scene wait loop re-clear any re-acquired lock every second.
Function _ProtectVictimTargeting(Actor akVictim)
    If akVictim == PlayerRef
        ; Surrender and SL Defeat both protect a fallen PLAYER the same way (confirmed by reading
        ; their sources): the Calm-archetype state goes ON THE VICTIM — combat AI treats a calmed
        ; actor as an invalid target and drops them, per-victim, without touching anyone else's
        ; fights. Magic-effect archetypes only drive AI, so the player's camera/controls are
        ; untouched — unlike Acheron's native player pacify (locked camera). Re-cast every tick by
        ; the struggle/scene polls, so duration doesn't matter.
        If SNBakaCalm
            SNBakaCalm.Cast(PlayerRef, PlayerRef)
            PlayerRef.StopCombatAlarm()
            _Log("[SNBaka] _ProtectVictimTargeting: Calm state cast on the player-victim (SL Defeat pattern)")
        Else
            _Log("[SNBaka] _ProtectVictimTargeting: WARNING — SNBakaCalm spell property is EMPTY, player-victim has no drop-target protection")
        EndIf
    ElseIf StorageUtil.GetIntValue(PlayerRef, "SNAcheron.Present", 0) == 1
        Acheron.PacifyActor(akVictim)
    EndIf
    _ClearStaleCombatLocks(akVictim)
EndFunction

; Acheron's pacify/defeat blocks NEW target acquisition but does NOT make attackers drop an
; already-locked combat target (confirmed live: giants kept swinging at an Acheron-defeated player;
; "after StopCombat(): IsInCombat()=TRUE" — the victim's own flag can't clear while others hold locks
; on them; the ATTACKERS' locks are what this clears). Only actors whose current combat target IS the
; victim are touched — an intercessor fighting the AGGRESSOR keeps its fight untouched.
Function _ClearStaleCombatLocks(Actor akVictim)
    Actor[] loaded = PO3_SKSEFunctions.GetActorsByProcessingLevel(0)
    Int i = 0
    While i < loaded.Length
        Actor atk = loaded[i]
        If atk && atk != akVictim && atk != PlayerRef && !atk.IsDead() && atk.GetCombatTarget() == akVictim
            atk.StopCombat()
            atk.EvaluatePackage()
            _Log("[SNBaka] _ClearStaleCombatLocks: " + atk.GetDisplayName() + " was still locked onto " + akVictim.GetDisplayName() + " — combat stopped")
        EndIf
        i += 1
    EndWhile
EndFunction

; End every "lover"-rank (4) anti-re-aggro link between this victim and any loaded CREATURE — our
; escalations always use rank 4 with a supported creature, so this signature can't hit a real spouse.
; Runs on every genuine liberation: repairs the CURRENT pair even if the caller lost track of it, and
; self-heals stale links baked into saves by builds that never reverted them (confirmed symptom: a
; giant that had previously beaten Joylie would never attack her again).
Function _ClearAggressorBonds(Actor akVictim)
    Actor[] loaded = PO3_SKSEFunctions.GetActorsByProcessingLevel(0)
    Int i = 0
    While i < loaded.Length
        Actor a = loaded[i]
        If a && a != akVictim && a != PlayerRef && !a.IsDead() && a.GetRelationshipRank(akVictim) == 4 && _CreatureAnimKey(a) != ""
            a.SetRelationshipRank(akVictim, 0)
            If akVictim != PlayerRef
                akVictim.SetRelationshipRank(a, 0)
            EndIf
            _Log("[SNBaka] _ClearAggressorBonds: cleared lover-rank link " + a.GetDisplayName() + " <-> " + akVictim.GetDisplayName())
        EndIf
        ; Stray-Calm sweep (same loop, essentially free): an actor still carrying our Calm effect
        ; while NOT flagged pacified is a leftover from an interrupted cycle — reported as actors
        ; "calmed even when they should not be anymore". Dispels only OUR spell; no-op otherwise.
        If a && a != PlayerRef && SNBakaCalm && StorageUtil.GetIntValue(a, "SNBaka.Pacified", 0) == 0
            a.DispelSpell(SNBakaCalm)
        EndIf
        i += 1
    EndWhile
EndFunction

; Pacify EVERYONE near the victim who is hostile to them (the captor's whole group), so a capture
; isn't instantly broken by other bandits in the camp re-opening fire. Reversible (each gets the
; standard SNBaka.Pacified flag, so a future release restores their aggression).
Function _PacifyNearbyHostiles(Actor akVictim, Float radius = 3000.0)
    If !akVictim
        Return
    EndIf
    Cell c = akVictim.GetParentCell()
    If !c
        Return
    EndIf
    Int total = c.GetNumRefs(62)
    Int i = 0
    Int pacified = 0
    While i < total
        Actor a = c.GetNthRef(i, 62) as Actor
        If a && a != akVictim && a != PlayerRef && !a.IsDead() && a.GetDistance(akVictim) < radius
            ; We do NOT try to identify "the captor's faction" — in a multi-faction brawl (bandits +
            ; Stormcloaks + whoever) that's unknowable. Instead we stand down everyone HOSTILE TO THE
            ; CAPTIVE: those are the only ones who threaten them. Anyone fighting a different enemy
            ; (other factions brawling each other) is left alone to keep fighting. IsHostileToActor is
            ; the precise test; "currently swinging at the captive" (GetCombatTarget) catches anyone
            ; attacking them for non-faction reasons (crime/assault). We deliberately do NOT calm on
            ; bare IsInCombat — that would silence unrelated factions fighting each other.
            If a.IsHostileToActor(akVictim) || a.GetCombatTarget() == akVictim
                _PacifyActor(a, True)
                a.StopCombat()
                a.StopCombatAlarm()
                a.SetRelationshipRank(akVictim, 4)   ; ally-level so they don't re-aggro the prisoner
                a.EvaluatePackage()
                pacified += 1
            EndIf
        EndIf
        i += 1
    EndWhile
    _Log("[SNBaka] _PacifyNearbyHostiles: pacified " + pacified + " hostile(s) near " + akVictim.GetDisplayName())
EndFunction

; Keeps the victim downed for duration seconds after a violent action.
; Fires baka_opportunity so nearby NPCs (and SkyrimNet) can react and escalate.
; Recovery is skipped if combat starts or a stop is requested.
Function _RecoveryPeriod(Actor akVictim, Actor akWitness, Float duration)
    If !akVictim || akVictim.IsDead() || akVictim.IsInCombat()
        _Log("[SNBaka] _RecoveryPeriod: skipped for " + akVictim.GetDisplayName() + " (dead=" + akVictim.IsDead() + " inCombat=" + akVictim.IsInCombat() + ")")
        Return
    EndIf
    Bool victimIsPlayer = (akVictim == PlayerRef)
    _Log("[SNBaka] _RecoveryPeriod: victim=" + akVictim.GetDisplayName() + " isPlayer=" + victimIsPlayer + " duration=" + duration)
    If victimIsPlayer
        Game.DisablePlayerControls(True, True, False, False, True, False, False, False)
        ; (No SetDontMove on the player — it locked the camera. The NPC is ghosted so it can't
        ; shove the player, and the player isn't ghosted so they won't fall; no pin needed.)
    EndIf
    StorageUtil.SetStringValue(akVictim, "SNBaka.DownPose", "")   ; fresh down -> re-roll the pose
    _Bleedout(akVictim, akWitness)
    Utility.Wait(0.5)
    If !victimIsPlayer
        akVictim.SetRestrained(True)
        akVictim.SetDontMove(True)
        _Log("[SNBaka] _RecoveryPeriod: Restrained+DontMove set on NPC")
    EndIf
    Utility.Wait(0.3)
    If !victimIsPlayer
        SkyrimNetApi.RegisterEvent("baka_opportunity", \
            akVictim.GetDisplayName() + " is helpless on the ground.", \
            akWitness, akVictim)
    EndIf
    ; Victim is in bleedout so IsDead()=True — _WaitOrAbort would abort on tick 1.
    ; Per design, the bleedout is the ONE thing that PERSISTS through combat: the downed
    ; loser stays helpless on the ground for the full window even if a fight breaks out
    ; around them (unlike the paired anim, which combat breaks).  So: plain timed wait,
    ; no combat early-exit.
    Float recElapsed = 0.0
    Float recTick    = 0.5
    Float recDur     = duration - 0.5
    Float recHold    = 0.0
    While recElapsed < recDur
        Utility.Wait(recTick)
        recElapsed += recTick
        recHold += recTick
        If recHold >= 3.0
            recHold = 0.0
            String rdp = StorageUtil.GetStringValue(akVictim, "SNBaka.DownPose", "")
            If rdp != "" && !victimIsPlayer
                Debug.SendAnimationEvent(akVictim, rdp)   ; hold the cached down pose
            EndIf
        EndIf
    EndWhile
    akVictim.SetRestrained(False)
    akVictim.SetDontMove(False)
    _Recover(akVictim)
    If victimIsPlayer
        Game.EnablePlayerControls()
        Debug.SendAnimationEvent(akVictim, "IdleForceDefaultState")
        _Log("[SNBaka] _RecoveryPeriod: player controls re-enabled")
    EndIf
    _Log("[SNBaka] _RecoveryPeriod: done for " + akVictim.GetDisplayName())
EndFunction

; Puts akVictim into the defeat down-pose. PURE ANIMATION — no Kill(), no vanilla bleedout,
; no Acheron, no HP manipulation, for EITHER player or NPC.
;
; The victim is held in place by the caller: DisablePlayerControls for the player (camera stays
; free — looking is left enabled), or SetRestrained+SetDontMove+pacify for NPCs. The Babo down
; idle is a cyclic 'b' animation, so it loops and holds the pose until _Recover stands them up
; with IdleForceDefaultState. With no AI/agency on the victim, escalation can still run on them.
; Weighted-random downed pose, for variety when no caller set _sDownPose. All options read as a
; collapse on the ground so they fit the pinned/restrained down state. KnockOut is a sequence whose
; Start transitions into a looping knocked-out pose; FaintF is female-only. Add Panting/Surrender to
; the pools if they read as ground poses in-game. (Outcome-specific poses: set _sDownPose before the
; ground window to force one — e.g. a brutal KO -> "BaboDefeatKnockOutStart".)
String Function _PickDownPose(Actor akVictim)
    Bool female = akVictim && akVictim.GetActorBase().GetSex() == 1
    ; Wire the pose to WHY they went down (their last Baka action). Unmapped motives -> random variety.
    ; (Choke already forces BaboFaintF via _sDownPose, which overrides this entirely.)
    String motive = StorageUtil.GetStringValue(akVictim, "SNBaka.LastAnim", "")
    If motive == "Struggle" || motive == "BackHugMolest" || motive == "ChokeHug"
        If female && motive == "ChokeHug"
            Return "BaboFaintF"               ; choked out -> faint
        EndIf
        Return "Babo_DefeatTraumaLie"         ; overpowered/grappled -> limp on the ground (STATIC: re-asserts cleanly, unlike the KnockOut sequence which restarts every re-assert and looks like it "rotates")
    ElseIf motive == "DrunkExploit" || motive == "DrugFood"
        Return "Babo_DefeatTraumaLie"         ; drunk/drugged -> limp on the ground
    EndIf
    Int r = Utility.RandomInt(1, 100)
    ; NOTE: only STATIC ground idles here. BaboDefeatKnockOutStart is a SEQUENCE — re-asserting it
    ; every few seconds restarts the sequence, which looks like the pose "rotating"/never settling.
    If female   ; female pool
        If r <= 40
            Return "BaboFaintF"
        EndIf
        Return "Babo_DefeatTraumaLie"
    EndIf
    ; male / other pool
    Return "Babo_DefeatTraumaLie"
EndFunction

Function _Bleedout(Actor akVictim, Actor akWitness)
    _Log("[SNBaka] _Bleedout: victim=" + akVictim.GetDisplayName() + " isPlayer=" + (akVictim == PlayerRef))
    ; Clear any looping paired animation still playing on the victim first.
    ; Without this, BaboBackHugMolestLoopF / Struggle loops etc. block the KnockDown event.
    Debug.SendAnimationEvent(akVictim, "IdleForceDefaultState")
    Utility.Wait(0.2)
    ; Same Babo down idle for BOTH player and NPC.
    String downAnim = _sDownPose
    If downAnim == ""
        ; Roll the random pose ONCE per down and cache it on the actor, so it can't visibly change
        ; if _Bleedout runs again (re-assert, or an Investigate/Inspect re-down) — it sticks for the
        ; whole downed state. The cache is cleared at the start of a fresh down (see below).
        downAnim = StorageUtil.GetStringValue(akVictim, "SNBaka.DownPose", "")
        If downAnim == ""
            downAnim = _PickDownPose(akVictim)   ; weighted variety; _sDownPose still overrides
        EndIf
    EndIf
    StorageUtil.SetStringValue(akVictim, "SNBaka.DownPose", downAnim)
    Debug.SendAnimationEvent(akVictim, downAnim)
    _Log("[SNBaka] _Bleedout: down pose = " + downAnim + " on " + akVictim.GetDisplayName())
    _sDownPose = ""
    _Log("[SNBaka] _Bleedout: bleedout triggered on " + akVictim.GetDisplayName())
    If bExpressionsEnabled
        _ApplyMoodExpression(akVictim, "pained")
    EndIf
EndFunction

; Recovers akVictim from the defeat down-pose placed by _Bleedout.
; Stands both player and NPC up with IdleForceDefaultState (no vanilla BleedoutStop, no Acheron).
; Only restores HP on an Essential NPC that was ever killed into bleedout (legacy guard).
; Caller must EnablePlayerControls after this for the player.
; Matching "stand up" transition for a known down pose, or "" if the pose is unrecognized/empty — the
; latter happens for a PURE Acheron-native combat defeat (no Baka QTE ever ran, so SNBaka.DownPose was
; never set), which is common and not an error. Global so Acheron's own _Recover can reuse the same
; mapping without a hard script reference (StorageUtil key only).
String Function _GetUpAnimFor(String downPose) Global
    If downPose == "Babo_DefeatTraumaLie"
        Return "Babo_DefeatTraumaStand"
    EndIf
    Return ""
EndFunction

; Borrowed from the Surrender mod's own proven technique (DBSurrenderActive.psc): while an actor is in
; OUR downed state, force them Essential — but ONLY if they weren't already Essential or Protected, and
; track that WE were the ones who did it, so recovery only ever undoes our own change, never someone
; else's existing protection. Confirmed real gap otherwise: nothing currently stops a downed/pinned
; victim from just dying to a stray follow-up hit while helpless, since restraining them (SetRestrained/
; SetDontMove) does nothing about incoming damage.
Function _ForceEssentialForDown(Actor ak, Bool abForce)
    If !ak
        Return
    EndIf
    ActorBase bse = ak.GetActorBase()
    If !bse
        Return
    EndIf
    If abForce
        ; NO forced protection anymore -- explicit spec change: a downed actor lives or dies by their
        ; own BASE flags. Base Essential/Protected keep their vanilla immunities; everyone else can be
        ; finished off while down by accumulated damage from anything (stray hits, fire, an NPC that
        ; keeps swinging), and a single PLAYER hit executes them outright (see OnPlayerHitActor).
        ; "It's life." The call sites are kept as the single policy point in case this changes again.
    Else
        If StorageUtil.GetIntValue(ak, "SNBaka.ProtectForcedByUs", 0) == 1
            bse.SetProtected(False)
            StorageUtil.SetIntValue(ak, "SNBaka.ProtectForcedByUs", 0)
            _Log("[SNBaka] _ForceEssentialForDown: restored non-Protected on " + ak.GetDisplayName())
        EndIf
        ; Backward-compat restores for state left by earlier builds of this guard: the brief
        ; Essential-forcing version, and the Ghost the bridge used to apply at down-time (the Ghost
        ; leak was a confirmed bug: permanently invulnerable player, unresolvable enemy combat).
        If StorageUtil.GetIntValue(ak, "SNBaka.EssentialForcedByUs", 0) == 1
            bse.SetEssential(False)
            StorageUtil.SetIntValue(ak, "SNBaka.EssentialForcedByUs", 0)
            _Log("[SNBaka] _ForceEssentialForDown: restored non-Essential on " + ak.GetDisplayName() + " (legacy build residue)")
        EndIf
        If StorageUtil.GetIntValue(ak, "SNAcheron.GhostForcedByUs", 0) == 1
            ak.SetGhost(False)
            StorageUtil.SetIntValue(ak, "SNAcheron.GhostForcedByUs", 0)
            _Log("[SNBaka] _ForceEssentialForDown: cleared legacy down-state Ghost on " + ak.GetDisplayName())
        EndIf
    EndIf
EndFunction

Function _Recover(Actor akVictim, Bool abFullRescue = True)
    _Log("[SNBaka] _Recover: victim=" + akVictim.GetDisplayName() + " isPlayer=" + (akVictim == PlayerRef))
    ; Force Essential FIRST, unconditionally, before checking/restoring health below. Every entry point
    ; we control (our own ground window, _CueDowned, RunConsequence) already forces this the moment
    ; something goes down — but _DispatchDownedAction's "external" branch (Stand Back / HelpUp / Escalate
    ; on a victim downed by something else entirely — SeverActions, vanilla combat, a mod with no Baka
    ; involvement) reaches this same function WITHOUT ever having forced it, on the assumption the actor
    ; was already protected somehow. A generic recruited follower usually isn't Essential by default, so
    ; that assumption killed one (confirmed: acting on a bleeding-out, non-Essential follower here left
    ; her with no safety net at all). _ForceEssentialForDown no-ops if already Essential/Protected, so
    ; this is safe to call unconditionally regardless of which path got here.
    _ForceEssentialForDown(akVictim, True)
    ; Restore health FIRST, while still Essential (ours or their own) — only THEN clear our forced flag.
    ; Reversing this order would mean an actor we made Essential, sitting at ~0 health from being down,
    ; could actually die the instant we un-flag them, before ever getting the health restored below.
    If akVictim.IsEssential() && akVictim.IsDead()
        ; (NPC only) restore HP if an Essential NPC was ever killed into bleedout.
        akVictim.RestoreActorValue("Health", 1000.0)
        Utility.Wait(0.1)
    EndIf
    _ForceEssentialForDown(akVictim, False)
    ; Play a stand-up transition first — IdleForceDefaultState alone just snaps the animation graph to
    ; idle with no visible transition, which is what made every recovery look instant/wrong. Use the
    ; exact matching clip when we know the down pose (Babo_DefeatTraumaLie -> ...Stand); otherwise fall
    ; back to "staggerStart" (the same generic get-up-with-a-stagger event already used by the "Stand
    ; Back" outcome elsewhere in this file) rather than nothing at all — this covers a pure Acheron-
    ; native combat defeat, where SNBaka.DownPose was never set because no Baka QTE ever ran. Still send
    ; IdleForceDefaultState afterward regardless, as the final safety net guaranteeing a clean state even
    ; if the transition doesn't fully resolve on its own.
    String downPose  = StorageUtil.GetStringValue(akVictim, "SNBaka.DownPose", "")
    String getUpAnim = _GetUpAnimFor(downPose)
    If getUpAnim == ""
        getUpAnim = "staggerStart"
    EndIf
    Debug.SendAnimationEvent(akVictim, getUpAnim)
    Utility.Wait(1.0)
    _Log("[SNBaka] _Recover: played get-up transition " + getUpAnim + " for down pose '" + downPose + "'")
    StorageUtil.SetStringValue(akVictim, "SNBaka.DownPose", "")
    ; Stand back up — same for player and NPC now (no vanilla BleedoutStop, no Acheron).
    Debug.SendAnimationEvent(akVictim, "IdleForceDefaultState")
    _Log("[SNBaka] _Recover: stand-up sent to " + akVictim.GetDisplayName())
    If bExpressionsEnabled
        _ClearExpression(akVictim)
    EndIf
    ; This is the ONLY stand-up path that didn't also clear Acheron's hold flag — every other
    ; resolution (Escalate, HelpUp, Release, SellToSlavery) does. Without this, an Acheron-initiated
    ; combat defeat that resolves via passive window-timeout (nobody escalated/helped in time)
    ; left SNAcheron.Held stuck at 1 forever: the victim visibly stands up, but every downed-state
    ; check (_IsDownedAny, eligibility, etc.) kept reading them as still down, since the bridge's
    ; own polling loop is what would normally clear it on an existing save it may never run again.
    _ClearAcheronHold(akVictim, abFullRescue)
EndFunction

Function _StartTears(Actor akVictim)
    If !bAnimatedTearsEnabled || !akVictim
        _Log("[SNBaka] _StartTears: GATED — enabled=" + bAnimatedTearsEnabled + " victim=" + akVictim)
        Return
    EndIf
    ; Setup() does NOT run on every load (its OnPlayerLoadGame doesn't fire on a Quest
    ; script), so TearSpell can be None here.  Resolve it LAZILY, where it's actually
    ; used, with the CONFIRMED-correct id 0x802 = zzNPCTearsTestApplySelf in
    ; EmoTears4NPCs.esp.  (The old wrong 0x322E was a visual-frame effect, not a spell.)
    If !TearSpell
        TearSpell = Game.GetFormFromFile(0x000802, "EmoTears4NPCs.esp") as Spell
        _Log("[SNBaka] _StartTears: lazy-resolved TearSpell=" + TearSpell)
    EndIf
    If !TearSpell || akVictim.GetActorBase().GetSex() != 1
        _Log("[SNBaka] _StartTears: GATED — TearSpell=" + TearSpell + " female=" + (akVictim.GetActorBase().GetSex() == 1) + " for " + akVictim.GetDisplayName())
        Return
    EndIf
    ; The EmoTears apply spell TOGGLES the tear ability, and _StartTears is called
    ; ~23 times across a scene — casting it an even number of times toggles tears
    ; back OFF ("works sometimes").  So cast ONLY when tears aren't already on, and
    ; cast one-arg exactly like the proven ExtraActions implementation.
    ; (No GetFormFromFile here — that wrong-ID lookup is what kept nulling the spell.)
    Int tearsOn = StorageUtil.GetIntValue(akVictim, "SNBaka.TearsOn", 0)
    If tearsOn == 0
        _TearVictim = akVictim
        TearSpell.Cast(akVictim)
        StorageUtil.SetIntValue(akVictim, "SNBaka.TearsOn", 1)
        _Log("[SNBaka] _StartTears: CAST tears on " + akVictim.GetDisplayName())
    Else
        _Log("[SNBaka] _StartTears: SKIPPED " + akVictim.GetDisplayName() + " — SNBaka.TearsOn already 1 (stuck flag? prior scene didn't _StopTears)")
    EndIf
    ; Out-of-sex crying shows a sad face; during sex the afraid/pained/angry cycle owns the face.
    If bExpressionsEnabled && !IsInSexAnimation(akVictim)
        _ApplyMoodExpression(akVictim, "sad")
    EndIf
EndFunction

Function _StopTears(Actor akVictim)
    If _TearVictim == akVictim
        _TearVictim = None
    EndIf
    ; Toggle the tears back off if we turned them on, so each scene starts clean.
    If akVictim && TearSpell && StorageUtil.GetIntValue(akVictim, "SNBaka.TearsOn", 0) == 1
        TearSpell.Cast(akVictim)
        StorageUtil.SetIntValue(akVictim, "SNBaka.TearsOn", 0)
    EndIf
    If bExpressionsEnabled && akVictim
        _ClearExpression(akVictim)
    EndIf
EndFunction

; Affectionate interactions must never show a partner still crying from an earlier forced/sex
; scene. Wipe BOTH tear systems on each actor: the EmoTears spell + expression (_StopTears) AND
; the durable SlaveTats face overlay (zero the heat so the fade timer can't re-apply, then
; ClearFaceMarks). Female-only guards inside the callees make this a no-op on males.
Function _ClearTearsForAffection(Actor akA, Actor akB)
    _ClearActorTears(akA)
    _ClearActorTears(akB)
EndFunction

Function _ClearActorTears(Actor ak)
    If !ak
        Return
    EndIf
    _StopTears(ak)
    StorageUtil.SetIntValue(ak, "SkyrimNetSDB.TearHeat", 0)
    ClearFaceMarks(ak)
EndFunction

; Second tears method — the one that actually survives a SexLab scene.
; _StartTears uses the EmoTears apply-spell, an MFG/animated facial effect that
; SexLab's per-stage expression system resets mid-scene (why tears "don't show"
; during sex).  A SlaveTats Face overlay is a NiOverride SKIN TEXTURE, not an MFG
; morph, so it rides on top of whatever expression SexLab forces and stays visible
; for the whole scene.  Reuses the existing face-mark assets + fade/cleanup
; (SpankedActors formlist, SpankTatFadeRate), and floors TearHeat at one intensity
; step so the streak is visible even with no prior spanks.
Function _ApplySexTears(Actor akVictim)
    If !bAnimatedTearsEnabled || !akVictim || akVictim.GetActorBase().GetSex() != 1
        Return
    EndIf
    Int heat = StorageUtil.GetIntValue(akVictim, "SkyrimNetSDB.TearHeat", 0)
    If heat < SpankTatIntensity
        heat = SpankTatIntensity
        StorageUtil.SetIntValue(akVictim, "SkyrimNetSDB.TearHeat", heat)
    EndIf
    UpdateFaceMarks(akVictim, heat)
    StorageUtil.FormListAdd(Self, "SkyrimNetSDB.SpankedActors", akVictim, True)
    _Log("[SNBaka] _ApplySexTears: SlaveTats tear overlay (heat=" + heat + ") on " + akVictim.GetDisplayName())
    ; NOTE: facial expressions during sex are left to SexLab's own per-stage expression system —
    ; we don't fight it.  Only the tear OVERLAY (above) is ours during sex.
EndFunction

; ===================== Facial expressions =====================
; Morph presets baked from "Additional Expressions Project" (PoserHotKeys FaceData), applied through
; MfgFix's MfgConsoleFunc.  Modes: 0=phoneme, 1=modifier, 2=expression(id,strength), -1=reset phon/mod.
; ResetPhonemeModifier does NOT clear the expression channel, so _ClearExpression also zeroes expression.
; Moods: happy, angry, afraid, sad, pained, surprised, confused.
; Apply one MFG value scaled by fExpressionIntensity (0.0-1.0).  Keeps the AEP proportions but
; dials the whole face down so it isn't maxed/exaggerated.  Clamped to 0-100.
Function _mfgX(Actor akActor, Int mode, Int id, Int base)
    Float s = fExpressionIntensity
    If s < 0.0
        s = 0.0
    ElseIf s > 1.0
        s = 1.0
    EndIf
    Int v = (base * s) as Int
    MfgConsoleFunc.SetPhonemeModifier(akActor, mode, id, v)
EndFunction

Function _ApplyMoodExpression(Actor akActor, String mood)
    If !akActor
        Return
    EndIf
    ; MFG face-morph expressions only work on humanoid face rigs — creatures (wolves, trolls, spiders,
    ; etc.) don't have MFG-compatible faces at all. Fixed here rather than only in Express_Execute since
    ; this is called directly from several narrative beats too (_Bleedout, Struggle_Execute) that could
    ; target a downed/struggling creature victim.
    If _IsCreatureActor(akActor)
        Return
    EndIf
    MfgConsoleFunc.ResetPhonemeModifier(akActor)
    If mood == "happy"
        _mfgX(akActor, 2, 2, 40)
        _mfgX(akActor, 1, 3, 50)
    ElseIf mood == "angry"
        _mfgX(akActor, 2, 0, 100)
        _mfgX(akActor, 1, 5, 50)
        _mfgX(akActor, 1, 6, 40)
    ElseIf mood == "afraid"
        _mfgX(akActor, 2, 1, 100)
        _mfgX(akActor, 0, 6, 100)
        _mfgX(akActor, 0, 7, 100)
        _mfgX(akActor, 0, 14, 70)
    ElseIf mood == "sad"
        _mfgX(akActor, 2, 11, 100)
        _mfgX(akActor, 0, 2, 50)
        _mfgX(akActor, 0, 3, 30)
        _mfgX(akActor, 0, 4, 50)
        _mfgX(akActor, 0, 5, 50)
        _mfgX(akActor, 0, 8, 90)
    ElseIf mood == "pained"
        _mfgX(akActor, 2, 8, 100)
        _mfgX(akActor, 0, 0, 50)
        _mfgX(akActor, 0, 1, 50)
        _mfgX(akActor, 0, 2, 100)
        _mfgX(akActor, 0, 3, 100)
        _mfgX(akActor, 0, 4, 100)
        _mfgX(akActor, 0, 5, 100)
        _mfgX(akActor, 0, 15, 60)
        _mfgX(akActor, 1, 0, 70)
        _mfgX(akActor, 1, 1, 70)
    ElseIf mood == "surprised"
        _mfgX(akActor, 2, 4, 100)
        _mfgX(akActor, 0, 14, 100)
        _mfgX(akActor, 0, 15, 50)
    ElseIf mood == "confused"
        _mfgX(akActor, 2, 5, 100)
    Else
        _Log("[SNBaka] _ApplyMoodExpression: unknown mood '" + mood + "'")
        Return
    EndIf
    _Log("[SNBaka] _ApplyMoodExpression: " + mood + " on " + akActor.GetDisplayName() + " (intensity " + fExpressionIntensity + ")")
EndFunction

Function _ClearExpression(Actor akActor)
    If !akActor
        Return
    EndIf
    MfgConsoleFunc.ResetPhonemeModifier(akActor)   ; clears phonemes + modifiers
    MfgConsoleFunc.SetPhonemeModifier(akActor, 2, 0, 0)  ; expression channel off
EndFunction

; LLM-triggered: apply a mood, hold ~6s, then clear.  A per-actor sequence counter means a newer
; expression (or a fresh trigger) won't be wiped early by an older hold's timer.
Function _HoldMoodExpression(Actor akActor, String mood)
    If !bExpressionsEnabled || !akActor
        Return
    EndIf
    _ApplyMoodExpression(akActor, mood)
    Int seq = StorageUtil.GetIntValue(akActor, "SNBaka.ExprSeq", 0) + 1
    StorageUtil.SetIntValue(akActor, "SNBaka.ExprSeq", seq)
    Utility.Wait(6.0)
    If StorageUtil.GetIntValue(akActor, "SNBaka.ExprSeq", 0) == seq
        _ClearExpression(akActor)
    EndIf
EndFunction

; --- SkyrimNet expression action (speaker emotes; target is ignored) ---
; Single parameterized action replacing the old one-yaml-per-mood set (happy/angry/afraid/sad/
; pained/surprised/confused). _ApplyMoodExpression silently no-ops on an unrecognized mood string.
Function Express_Execute(Actor akInitiator, Actor akTarget, String mood)
    _Log("[SNBakaACT] Express ENTER mood=" + mood)
    _HoldMoodExpression(akInitiator, mood)
EndFunction


; --- PlayPairedLoopAnim ---
; Start → Loop → Cleanup. A1 is the initiator, A2 is the target.
;
; sResistA1/A2 : animation played on A1/A2 during the resist window.
;   Defaults to the generic Babo_DefeatResist struggle loop.
;   Pass action-specific resist anims (e.g. SLAPForcedKiss01_A1_Resist)
;   when the animation set has its own resist pair.
; sStopA1/A2   : animation played when the player successfully escapes.
;   Defaults to Babo_DefeatResist_A1/A2_S2 (the break-free animation).
Function PlayPairedLoopAnim(Actor akA1, Actor akA2, \
        Float xLocal, Float yLocal, Float rotOffset, \
        String startA1, String startA2, \
        String loopA1,  String loopA2, \
        Float startWait, Float loopDur, \
        Bool bResistable = False, \
        String sResistA1 = "Babo_DefeatResist_A1_S1", \
        String sResistA2 = "Babo_DefeatResist_A2_S1", \
        String sStopA1   = "Babo_DefeatResist_A1_S2", \
        String sStopA2   = "Babo_DefeatResist_A2_S2", \
        Actor akImpactActor = None, \
        Bool bDisableCollision = True, \
        Bool bRefreshLoop = False)

    Bool a1IsPlayer = (akA1 == PlayerRef)
    Bool a2IsPlayer = (akA2 == PlayerRef)

    If a1IsPlayer || a2IsPlayer
        Game.DisablePlayerControls(True, True, False, False, True, False, False, False)
        ; (No SetDontMove on the player — it locked the camera. The NPC is ghosted so it can't
        ; shove the player, and the player isn't ghosted so they won't fall; no pin needed.)
    EndIf

    ObjectReference marker1 = None
    ObjectReference marker2 = None
    If XMarkerBase
        marker1 = akA2.PlaceAtMe(XMarkerBase, 1, False, False)
        marker2 = akA2.PlaceAtMe(XMarkerBase, 1, False, False)
    EndIf

    ; New model: attacker is the origin, NPC attacker teleports onto the victim, victim placed at the
    ; (xLocal=R/L, yLocal=F/B, rotOffset) offset; player never teleported; hard AI stop + pin. See _SetupPair.
    ; sFn = the start-anim name; it is ALSO the SNBaka_Offsets.ini key for this anim's offsets.
    _SetupPair(akA1, akA2, xLocal, yLocal, rotOffset, bDisableCollision, marker1, marker2, startA1)
    Debug.SendAnimationEvent(akA1, startA1)
    Debug.SendAnimationEvent(akA2, startA2)
    Bool aborted = _WaitOrAbort(akA1, akA2, startWait, 0.25)

    If !aborted && akImpactActor != None
        PlaySmackSound(akImpactActor)
    EndIf

    If !aborted
        If loopA1 != ""
            Debug.SendAnimationEvent(akA1, loopA1)
        EndIf
        If loopA2 != ""
            Debug.SendAnimationEvent(akA2, loopA2)
        EndIf

        ; The pose to RE-ASSERT during waits/QTE so an actor that drifts off snaps back: the loop anim
        ; if there is one, else the START anim. Grab-hold (BackHugMolest) passes EMPTY loops — it's a
        ; FNIS sequence that auto-chains from its START, so we must re-assert the START (re-sending the
        ; loop event kicks it out). Without this, grab-hold had nothing to re-assert and the NPC froze.
        String holdA1 = loopA1
        If holdA1 == ""
            holdA1 = startA1
        EndIf
        String holdA2 = loopA2
        If holdA2 == ""
            holdA2 = startA2
        EndIf

        If bResistable && bResistEnabled && (a1IsPlayer || a2IsPlayer)
            SkyrimNetApi.RegisterEvent("baka_resist_start", \
                akA2.GetDisplayName() + " struggles to break free from " + akA1.GetDisplayName() + ".", \
                akA1, akA2)

            Bool escaped = _PollResist(akA1, akA2, loopDur, sResistA1, sResistA2, holdA1, holdA2)
            _Log("[SNBaka] LoopAnim: _PollResist done. escaped=" + escaped + " _bQTEDefeated=" + _bQTEDefeated)

            If escaped
                Debug.SendAnimationEvent(akA1, sStopA1)
                Debug.SendAnimationEvent(akA2, sStopA2)
                SkyrimNetApi.RegisterEvent("baka_resist_success", \
                    akA2.GetDisplayName() + " breaks free from " + akA1.GetDisplayName() + ".", \
                    akA1, akA2)
                _OnVictimWon(akA2, akA1)
                Utility.Wait(1.5)
            ElseIf !_bQTEDefeated && !_ShouldAbort(akA1, akA2)
                _WaitOrAbort(akA1, akA2, loopDur * 0.4)
            EndIf
        ElseIf bResistable
            ; NPC-vs-NPC resistable loop (e.g. BackHugMolest): play the loop out, THEN resolve like
            ; the staged scenes — so it never just ends with no finish. Victim escapes -> break-free
            ; anim; attacker wins -> flag defeat so the caller runs the ground/escalation window.
            _bAELVictimEscaped = (Utility.RandomFloat(0.0, 99.9) < fNPCEscapeChance)
            _HoldAnim(akA1, akA2, holdA1, holdA2, loopDur)
            If !_ShouldAbort(akA1, akA2)
                If _bAELVictimEscaped
                    Debug.SendAnimationEvent(akA1, sStopA1)
                    Debug.SendAnimationEvent(akA2, sStopA2)
                    _WaitOrAbort(akA1, akA2, 1.5)
                Else
                    _bQTEDefeated = True   ; caller's If _bQTEDefeated -> DefeatGroundWindow
                EndIf
            EndIf
        Else
            ; Non-resistable: FREEZE both actors on the pose for the full duration — re-asserted each
            ; tick so a short/one-shot clip or an idle replacer can't drop them out. (Re-assert is now
            ; the default; the bRefreshLoop flag is kept only for call-site compatibility.)
            _HoldAnim(akA1, akA2, holdA1, holdA2, loopDur)
        EndIf
    EndIf

    _CleanupPair(akA1, akA2, marker1, marker2, a1IsPlayer || a2IsPlayer, _bQTEDefeated)
EndFunction

; --- PlayPairedSimpleAnim ---
; Single animation with no explicit loop event. Duration is the total hold time.
; If bResistable, substitutes Babo_DefeatResist_A1/A2_S1 for the resist window.
; On escape → S2 cleanup. On fail → plays original anim for remaining time.
Function PlayPairedSimpleAnim(Actor akA1, Actor akA2, \
        Float xLocal, Float yLocal, Float rotOffset, \
        String animA1, String animA2, Float duration, \
        Bool bResistable = False, \
        Bool bDisableCollision = True, \
        Bool abMoanAtMid = False)

    Bool a1IsPlayer = (akA1 == PlayerRef)
    Bool a2IsPlayer = (akA2 == PlayerRef)

    If a1IsPlayer || a2IsPlayer
        Game.DisablePlayerControls(True, True, False, False, True, False, False, False)
        ; (No SetDontMove on the player — it locked the camera. The NPC is ghosted so it can't
        ; shove the player, and the player isn't ghosted so they won't fall; no pin needed.)
    EndIf

    ObjectReference marker1 = None
    ObjectReference marker2 = None
    If XMarkerBase
        marker1 = akA2.PlaceAtMe(XMarkerBase, 1, False, False)
        marker2 = akA2.PlaceAtMe(XMarkerBase, 1, False, False)
    EndIf

    ; New attacker-anchored placement + hard AI stop + pin (see _SetupPair). animA1 = the SNBaka_Offsets.ini key.
    _SetupPair(akA1, akA2, xLocal, yLocal, rotOffset, bDisableCollision, marker1, marker2, animA1)
    Debug.SendAnimationEvent(akA1, animA1)
    Debug.SendAnimationEvent(akA2, animA2)

    If bResistable && bResistEnabled && (a1IsPlayer || a2IsPlayer)
        SkyrimNetApi.RegisterEvent("baka_resist_start", \
            akA2.GetDisplayName() + " struggles to break free from " + akA1.GetDisplayName() + ".", \
            akA1, akA2)

        Bool escaped = _PollResist(akA1, akA2, duration, "Babo_DefeatResist_A1_S1", "Babo_DefeatResist_A2_S1", animA1, animA2)
        _Log("[SNBaka] SimpleAnim: _PollResist done. escaped=" + escaped + " _bQTEDefeated=" + _bQTEDefeated)

        If escaped
            Debug.SendAnimationEvent(akA1, "Babo_DefeatResist_A1_S2")
            Debug.SendAnimationEvent(akA2, "Babo_DefeatResist_A2_S2")
            SkyrimNetApi.RegisterEvent("baka_resist_success", \
                akA2.GetDisplayName() + " breaks free from " + akA1.GetDisplayName() + ".", \
                akA1, akA2)
            _OnVictimWon(akA2, akA1)
            Utility.Wait(1.0)
        ElseIf !_bQTEDefeated && !_ShouldAbort(akA1, akA2)
            _WaitOrAbort(akA1, akA2, duration * 0.5)
        EndIf
    ElseIf abMoanAtMid
        ; Play the moan ~halfway through (near the Babo impact); freeze the pose either side.
        Float half = duration * 0.5
        If !_HoldAnim(akA1, akA2, animA1, animA2, half)
            _PlaySpankMoanOnly(akA2)
            _HoldAnim(akA1, akA2, animA1, animA2, duration - half)
        EndIf
    Else
        ; Freeze both actors on the pose for the whole duration (re-asserted each tick).
        _HoldAnim(akA1, akA2, animA1, animA2, duration)
    EndIf

    _CleanupPair(akA1, akA2, marker1, marker2, a1IsPlayer || a2IsPlayer, _bQTEDefeated)
EndFunction

; --- PlayPairedSequence ---
; Multi-stage: animsA1[i] / animsA2[i] in order, each held stageTimer seconds.
;
; If bResistable and player is A2:
;   A2 holds Babo_DefeatResist_A2_S1 throughout (the struggle loop).
;   A1 still advances through each stage animation normally.
;   Player can escape at any point during any stage.
;   This allows the NPC to visually escalate while the player fights back.
; Confirmed in live testing: a completely unrelated mod (SkyrimNet_PairedAnimations) can have the
; player's OWN follower "ExecuteTarget" (a scripted kill-move) the player mid-struggle, because that
; mod's eligibility check never considers allegiance at all — any actor is "eligible" against any
; target. We can't fix another mod's code from here, but AddPackageOverride's priority-100 hold already
; blocks every OTHER package/AI-driven behavior from being assigned to an actor while it's active — so
; forcing that same hold onto nearby teammates for the duration of OUR OWN scenes should keep them from
; being hijacked into a kill-scene package by anything else, regardless of what that other mod's
; eligibility logic does or doesn't check.
; akAggressor: the OTHER member of THIS pair (the attacker/creature) — excluded from the sweep below
; (it's handled separately by _SetupPair), never touched otherwise.
; Every OTHER nearby actor (any NPC or creature, ally or hostile, human or beast) is held off combat
; for the duration -- a "cloak of calm" so the pair is effectively ignored by anyone not actually
; involved, without literally turning them invisible. The player is the sole exception: never held,
; always free to interject or be interjected upon. Any hit that DOES land despite this (the player,
; or anything that slips past) still aborts the struggle/scene as normal -- this only stops OTHER
; actors from choosing to start something, it doesn't make the pair invulnerable.
Function _ProtectNearbyAllies(Actor akCenter, Actor akAggressor, Bool abHold)
    If !akCenter
        Return
    EndIf
    ; LOADED-AREA enumeration (po3), same fix as the creature/companion scans: the old single-cell
    ; sweep + single-closest supplement missed everything registered in a linked cell — confirmed
    ; live yet again with giants aggroing straight through a "protected" QTE from the next cell over.
    ; Hold is radius-capped so a whole loaded exterior doesn't get frozen; RELEASE is uncapped so a
    ; held actor can never be stranded in DoNothing by positional drift (releasing a never-held actor
    ; is a no-op).
    Actor[] loaded = PO3_SKSEFunctions.GetActorsByProcessingLevel(0)
    Int held = 0
    Int i = 0
    While i < loaded.Length
        Actor a = loaded[i]
        If a && a != akCenter && a != akAggressor && a != PlayerRef && !a.IsDead() && (!abHold || a.GetDistance(akCenter) <= 3000.0)
            _HoldActorAI(a, abHold)
            ; Deliberately NO calm/pacify on bystanders — a cloak here stopped UNRELATED fights nearby
            ; (correct objection from testing). The victim-side calm in _ProtectVictimTargeting is what
            ; makes attackers drop the pair (SL Defeat / Surrender pattern: the calm goes ON the fallen
            ; actor, and combat AI treats a calmed actor as an invalid target). Once an attacker loses
            ; its only target and exits combat, THIS hold is what keeps it from wandering back in
            ; (package overrides can't grip an actor still in combat — combat AI outranks packages).
            If abHold
                held += 1
                ; (No per-actor trace — a den's worth of Debug.Trace lines per hold, each recomputing
                ; hostility/distance just for the log, was real VM load on an already-starved setup.
                ; The summary below says how many; _PacifyActor still traces the transitions.)
            EndIf
        EndIf
        i += 1
    EndWhile
    If abHold
        _Log("[SNBaka] _ProtectNearbyAllies: " + held + " actor(s) held+calmed around " + akCenter.GetDisplayName())
    Else
        _Log("[SNBaka] _ProtectNearbyAllies: released holds/calms around " + akCenter.GetDisplayName())
    EndIf
EndFunction

Function PlayPairedSequence(Actor akA1, Actor akA2, \
        Float xLocal, Float yLocal, Float rotOffset, \
        String[] animsA1, String[] animsA2, Float stageTimer, \
        Bool bResistable = False, \
        Bool bDisableCollision = True, \
        Float afA1Stage0Rot = 0.0)

    Bool a1IsPlayer = (akA1 == PlayerRef)
    Bool a2IsPlayer = (akA2 == PlayerRef)

    If a1IsPlayer || a2IsPlayer
        Game.DisablePlayerControls(True, True, False, False, True, False, False, False)
        ; (No SetDontMove on the player — it locked the camera. The NPC is ghosted so it can't
        ; shove the player, and the player isn't ghosted so they won't fall; no pin needed.)
    EndIf
    ; Not gated on player involvement — a nearby teammate can be hijacked into attacking whoever's
    ; downed regardless of whether the player is one of the two actors in THIS pairing.
    _ProtectNearbyAllies(akA2, akA1, True)
    ; Reset the escape flag unconditionally, not just inside the resistable branch below -- a
    ; NON-resistable sequence used to leave whatever value the PREVIOUS struggle set, and the
    ; post-escape grace at the bottom of this function keys off it.
    _bAELVictimEscaped = False

    ObjectReference marker1 = None
    ObjectReference marker2 = None
    If XMarkerBase
        marker1 = akA2.PlaceAtMe(XMarkerBase, 1, False, False)
        marker2 = akA2.PlaceAtMe(XMarkerBase, 1, False, False)
    EndIf

    ; New attacker-anchored placement + hard AI stop + pin (see _SetupPair). animsA1[0] = the SNBaka_Offsets.ini key.
    _SetupPair(akA1, akA2, xLocal, yLocal, rotOffset, bDisableCollision, marker1, marker2, animsA1[0])
    If bResistable && bResistEnabled && (a1IsPlayer || a2IsPlayer)
        SkyrimNetApi.RegisterEvent("baka_resist_start", \
            akA2.GetDisplayName() + " struggles to break free from " + akA1.GetDisplayName() + ".", \
            akA1, akA2)

        _bAELStruggleComplete = False
        _bAELVictimEscaped    = False
        _bPlayerIsVictim      = a2IsPlayer
        RegisterForModEvent("AEL_GameEnd", "OnAELGameEnd")

        ; Both actors start at stage 0. A1 and A2 advance in sync while QTE runs.
        Debug.SendAnimationEvent(akA1, animsA1[0])
        Debug.SendAnimationEvent(akA2, animsA2[0])

        Bool escaped = False
        Bool aborted = False

        ; fQTEStartDelay: lets stage 0 settle visually and — critically — gives Skyrim's
        ; UI time to finish closing the Interact message box. SPE_Interface.OpenCustomMenu
        ; (used inside MakeGame) returns False if called while the UI is still transitioning
        ; after Message.Show(), which is why Struggle/ChokeHug showed no QTE overlay.
        If fQTEStartDelay > 0.0
            aborted = _WaitOrAbort(akA1, akA2, fQTEStartDelay)
        EndIf

        Bool ael_ok = False
        If !aborted
            _Log("[SNBaka] PlayPairedSequence: starting QTE. A1=" + akA1.GetDisplayName() + " A2=" + akA2.GetDisplayName())
            ael_ok = AELStruggle.MakeGame(fResistDifficulty)
            _Log("[SNBaka] PlayPairedSequence: MakeGame returned " + ael_ok)
        EndIf

        If ael_ok
            Float elapsed = 0.0
            Float stageElapsed = 0.0
            Float sinceRe = 0.0
            Float tick = 0.1
            Float maxWait = stageTimer * animsA1.Length + 10.0
            Int stageIdx = 0
            ; Hold stage 0 for the ENTIRE QTE — no longer advances stages on stageTimer while the
            ; struggle is still undecided. That used to let the visible pose drift completely out of
            ; sync with the actual QTE outcome (the animation could already be 2-3 stages further along
            ; than what the minigame had actually resolved). Stages now only ever advance AFTER the QTE
            ; completes, branching into the win/lose resolution below — the same pattern the timed
            ; (non-QTE) fallback further down already uses for NPC-vs-NPC.
            While !_bAELStruggleComplete && !aborted && elapsed < maxWait
                Utility.Wait(tick)
                elapsed      += tick
                stageElapsed += tick
                sinceRe      += tick
                If _ShouldAbort(akA1, akA2)
                    aborted = True
                EndIf
                If !aborted && sinceRe >= 2.0
                    ; Re-assert stage 0 ~every 2s so PC-NPC actors can't drift/freeze mid-QTE.
                    sinceRe = 0.0
                    Debug.SendAnimationEvent(akA1, animsA1[stageIdx])
                    Debug.SendAnimationEvent(akA2, animsA2[stageIdx])
                EndIf
            EndWhile
            ; If poll timed out while Flash QTE is still open, force-close the menu.
            If !_bAELStruggleComplete
                SPE_Interface.CloseCustomMenu()
                Utility.Wait(0.3)
            EndIf
            escaped = _bAELStruggleComplete && _bAELVictimEscaped
            _Log("[SNBaka] PlayPairedSequence: QTE done. complete=" + _bAELStruggleComplete + " escaped=" + escaped)
            If _bAELStruggleComplete && !escaped
                _bQTEDefeated = True
                ; Finish remaining time in the current stage first.
                Float stageRemain = stageTimer - stageElapsed
                If stageRemain > 0.05 && !_ShouldAbort(akA1, akA2)
                    _WaitOrAbort(akA1, akA2, stageRemain)
                EndIf
                Int lastIdx = animsA1.Length - 1
                Int starIdx = lastIdx - 1
                If starIdx > 0 && stageIdx < starIdx && !_ShouldAbort(akA1, akA2)
                    stageIdx = starIdx
                    Debug.SendAnimationEvent(akA1, animsA1[stageIdx])
                    Debug.SendAnimationEvent(akA2, animsA2[stageIdx])
                    _WaitOrAbort(akA1, akA2, stageTimer)
                EndIf
            EndIf
        Else
            ; Timed sequence. Random outcome only when NEITHER actor is the player —
            ; player-involved cases rely on the QTE; if MakeGame failed, play all stages
            ; with no forced outcome (interaction just ends cleanly).
            Bool npcEscaped = bResistable && !aborted && !a1IsPlayer && !a2IsPlayer \
                && (Utility.RandomFloat(0.0, 99.9) < fResistDifficulty)
            Int stagesPlay = animsA1.Length
            If npcEscaped && animsA1.Length > 1
                stagesPlay = animsA1.Length / 2 + 1  ; roughly first half before break-free
            EndIf
            Int fi = 0
            While fi < stagesPlay && !aborted
                Debug.SendAnimationEvent(akA1, animsA1[fi])
                Debug.SendAnimationEvent(akA2, animsA2[fi])
                If _WaitOrAbort(akA1, akA2, stageTimer)
                    aborted = True
                EndIf
                fi += 1
            EndWhile
            If !aborted
                If npcEscaped
                    _Log("[SNBaka] PlayPairedSequence: NPC random — victim escapes")
                    _bAELVictimEscaped = True
                    Debug.SendAnimationEvent(akA1, "Babo_DefeatResist_A1_S2")
                    Debug.SendAnimationEvent(akA2, "Babo_DefeatResist_A2_S2")
                    Utility.Wait(1.5)
                ElseIf bResistable
                    _Log("[SNBaka] PlayPairedSequence: NPC random — attacker wins")
                    _bQTEDefeated = True
                EndIf
            EndIf
        EndIf

        UnregisterForModEvent("AEL_GameEnd")

        If escaped
            ; Play the anim's OWN final stage (its break-free), then free the actors quickly — 1.5s is
            ; enough for the break-free to read; 3.5 left them frozen ~2s too long after it ended.
            Int li2 = animsA1.Length - 1
            Debug.SendAnimationEvent(akA1, animsA1[li2])
            Debug.SendAnimationEvent(akA2, animsA2[li2])
            SkyrimNetApi.RegisterEvent("baka_resist_success", \
                akA2.GetDisplayName() + " breaks free from " + akA1.GetDisplayName() + ".", \
                akA1, akA2)
            _OnVictimWon(akA2, akA1)
            _WaitOrAbort(akA1, akA2, 1.5)
        EndIf
    Else
        ; Normal sequence — NPC-NPC (no QTE).
        If !bResistable
            ; Non-resistable paired sequence: just play every stage straight through.
            Float a1BaseAng = akA1.GetAngleZ()   ; base facing from _SetupPair, for the optional stage-0 flip
            Int i = 0
            While i < animsA1.Length && !_ShouldAbort(akA1, akA2)
                ; Some clips author stage 0 with the ATTACKER turned (Investigation): force akA1
                ; +afA1Stage0Rot on stage 0 only, restore base facing from stage 1 onward.
                If afA1Stage0Rot != 0.0
                    If i == 0
                        akA1.SetAngle(0.0, 0.0, a1BaseAng + afA1Stage0Rot)
                    ElseIf i == 1
                        akA1.SetAngle(0.0, 0.0, a1BaseAng)
                    EndIf
                    _HoldPinned(akA1)
                EndIf
                ; Freeze the actors on this stage for its whole duration (re-asserted each tick).
                _HoldAnim(akA1, akA2, animsA1[i], animsA2[i], stageTimer)
                i += 1
            EndWhile
        Else
            ; FORCED anim rule (Struggle, ChokeHug, any resistable staged anim). The clip has
            ; several stages: the LAST is the victim breaking free, the LAST-MINUS-ONE is the
            ; attacker's victory pose. Play the shared middle stages (everything before the
            ; deciding stage) at fNPCStageTime each, then show the deciding stage:
            ;   attacker win -> last-minus-one (victor),   victim win -> last (break-free).
            Bool npcEscaped = (Utility.RandomFloat(0.0, 99.9) < fNPCEscapeChance)
            Int lastIdx = animsA1.Length - 1
            Int penult  = lastIdx - 1
            If penult < 0
                penult = 0
            EndIf
            ; Shared middle stages 0 .. penult-1 (stop before the deciding stage).
            Int i = 0
            While i < penult && !_ShouldAbort(akA1, akA2)
                _HoldAnim(akA1, akA2, animsA1[i], animsA2[i], fNPCStageTime)
                i += 1
            EndWhile
            If !_ShouldAbort(akA1, akA2)
                If npcEscaped && animsA1.Length > 1
                    ; Victim wins: skip the victor stage, play the break-free LAST stage directly.
                    _HoldAnim(akA1, akA2, animsA1[lastIdx], animsA2[lastIdx], fNPCStageTime)
                    _bAELVictimEscaped = True
                    SkyrimNetApi.RegisterEvent("baka_resist_success", \
                        akA2.GetDisplayName() + " breaks free from " + akA1.GetDisplayName() + ".", \
                        akA1, akA2)
                    _OnVictimWon(akA2, akA1)
                Else
                    ; Attacker wins: play the LAST-MINUS-ONE (victor) stage, then flag defeat.
                    _HoldAnim(akA1, akA2, animsA1[penult], animsA2[penult], fNPCStageTime)
                    _bQTEDefeated = True   ; -> DefeatGroundWindow / escalation
                EndIf
            EndIf
        EndIf
    EndIf

    _ProtectNearbyAllies(akA2, akA1, False)
    _CleanupPair(akA1, akA2, marker1, marker2, a1IsPlayer || a2IsPlayer, _bQTEDefeated)
    ; The victim WON -- keep them untouchable a while longer (see _PostEscapeGrace). Must run AFTER
    ; _CleanupPair, whose unconditional SetGhost(False) would wipe it.
    If _bAELVictimEscaped
        _PostEscapeGrace(akA2)
    EndIf
EndFunction

; --- _CleanupPair ---
; Resets both actors: removes vehicles, restrained/ghost flags,
; re-enables player controls if involved, evaluates packages,
; and deletes position markers.
; bSkipA2Reset: when True, omits IdleForceDefaultState and EvaluatePackage on A2.
; Pass True when A2 is about to enter bleedout — keeps them in their final pose
; until KnockDown fires so they never briefly "stand up" before collapsing.
; ---- Keep-alive pin (DOM Snap) --------------------------------------------------------
; A near-zero, very-slow TranslateTo holds the actor at its current spot + facing for ~100s,
; so animation root-motion or a shove can't drift it off its fixed marker. Each actor is
; pinned to its OWN marker (we can't share one — our Baka Motion anims are authored for an
; offset layout, not co-origin), so neither can push the other. StopTranslation in
; _CleanupPair / _EscalationCleanup ends the hold. Never the player (never force-move them).
Function _HoldPinned(Actor ak)
    If ak && ak != PlayerRef
        ak.TranslateTo(ak.GetPositionX(), ak.GetPositionY(), ak.GetPositionZ(), \
                       0.0, 0.0, ak.GetAngleZ() + 0.01, 500.0, 0.0001)
    EndIf
EndFunction

; ---- Height-matching (DOM ScaleActorToOther) ------------------------------------------
; Paired anims align best when both actors are the same height. We scale the NON-player
; actor to its partner's scale for the duration, storing the original so _CleanupPair /
; _EscalationCleanup can restore it. Tracked in the SNBaka.ScaledActors formlist so the
; game-time heartbeat can sweep up any actor left resized by a save-mid-animation reload.
; Never scales the player. Only acts on a meaningful (>2%) difference.
Function _MatchPairHeight(Actor akA1, Actor akA2)
    If !bMatchHeight
        Return
    EndIf
    Actor scaleMe = None
    Actor refActor = None
    If akA1 != PlayerRef
        scaleMe  = akA1
        refActor = akA2
    ElseIf akA2 != PlayerRef
        scaleMe  = akA2
        refActor = akA1
    EndIf
    If !scaleMe || !refActor
        Return
    EndIf
    ; Only scale when both actors are fully loaded — SetScale on an unloaded actor can fault.
    If !scaleMe.Is3DLoaded() || !refActor.Is3DLoaded()
        Return
    EndIf
    ; If a previous run left this actor scaled (unclean exit), restore before re-measuring.
    _RestoreActorScale(scaleMe)
    Float cur = scaleMe.GetScale()
    Float ref = refActor.GetScale()
    If ref <= 0.0 || cur <= 0.0
        Return
    EndIf
    Float ratio = ref / cur
    If ratio > 1.02 || ratio < 0.98
        StorageUtil.SetFloatValue(scaleMe, "SNBaka.OrigScale", cur)
        StorageUtil.FormListAdd(Self, "SNBaka.ScaledActors", scaleMe, False)
        scaleMe.SetScale(ref)
        _Log("[SNBaka] HeightMatch: " + scaleMe.GetDisplayName() + " " + cur + " -> " + ref)
    EndIf
EndFunction

Function _RestoreActorScale(Actor akActor)
    If !akActor
        Return
    EndIf
    Float orig = StorageUtil.GetFloatValue(akActor, "SNBaka.OrigScale", 0.0)
    If orig > 0.0
        akActor.SetScale(orig)
        StorageUtil.SetFloatValue(akActor, "SNBaka.OrigScale", 0.0)   ; mark restored
    EndIf
EndFunction

; Bulk-restore every actor flagged as height-matched and empty the tracking list.
; Wired into EmergencyReset as a manual recovery valve (CGF "...EmergencyReset" 0) in
; case a save made mid-animation left an NPC resized. Not run periodically so it can
; never un-scale an actor that is mid-animation right now.
Function _RestoreAllScaledActors()
    Int i = StorageUtil.FormListCount(Self, "SNBaka.ScaledActors")
    While i > 0
        i -= 1
        Actor a = StorageUtil.FormListGet(Self, "SNBaka.ScaledActors", i) as Actor
        If a
            _RestoreActorScale(a)
        EndIf
        StorageUtil.FormListRemoveAt(Self, "SNBaka.ScaledActors", i)
    EndWhile
EndFunction

Function _CleanupPair(Actor akA1, Actor akA2, \
        ObjectReference marker1, ObjectReference marker2, Bool hadPlayer, Bool bSkipA2Reset = False)
    _Log("[SNBaka] CleanupPair: A1=" + akA1.GetDisplayName() + " A2=" + akA2.GetDisplayName() + " hadPlayer=" + hadPlayer)
    akA1.SetVehicle(None)
    akA2.SetVehicle(None)
    ; Reset the pose FIRST, while STILL ghosted/restrained/pacified/AI-held -- confirmed real bug from
    ; testing (a creature "fell and got stuck" mid-combat, not tied to timing since a prior scene): the
    ; OLD order restored vulnerability (Ghost/AI/aggression/movement) BEFORE sending IdleForceDefaultState,
    ; leaving a window where the actor could get hit and staggered while still visually mid-struggle-pose.
    ; A stagger outranks a plain idle-force event and nothing ever re-sent it once the stagger cleared,
    ; so it just stuck there. A direct SendAnimationEvent isn't gated by the AI package, so it still
    ; reaches the behavior graph with DoNothing/pacify/ghost all still active -- nothing can interrupt it.
    Debug.SendAnimationEvent(akA1, "IdleForceDefaultState")
    If !bSkipA2Reset
        Debug.SendAnimationEvent(akA2, "IdleForceDefaultState")
    EndIf
    Utility.Wait(0.3)
    akA1.EvaluatePackage()
    If !bSkipA2Reset
        akA2.EvaluatePackage()
    EndIf
    ; Only NOW restore vulnerability/AI/aggression -- the pose is already clean, so nothing they get hit
    ; with from this point on can interrupt a reset that's already finished.
    akA1.SetGhost(False)
    akA2.SetGhost(False)
    ; These unconditional SetGhost(False) calls also wipe the DOWN-state ghost the Acheron bridge
    ; applies (its _ForceEssentialForDown), whose bookkeeping flag lives on the actor -- clear the flag
    ; to match, or a victim re-downed right after this paired animation can never be re-ghosted (the
    ; force function sees the stale flag==1 and skips SetGhost, leaving them hittable while helpless).
    ; Confirmed as the most plausible chain behind a follower dying while downed: struggle ends ->
    ; un-ghosted here with stale flag -> redown never re-ghosts -> stray hit lands for real.
    StorageUtil.SetIntValue(akA1, "SNAcheron.GhostForcedByUs", 0)
    StorageUtil.SetIntValue(akA2, "SNAcheron.GhostForcedByUs", 0)
    ; Restore collision (teammate flag) and remove the DoNothing AI override.
    SNBakaUI.SetNoCollision(akA1, False)
    SNBakaUI.SetNoCollision(akA2, False)
    _HoldActorAI(akA1, False)
    _HoldActorAI(akA2, False)
    ; Restore any height-match scaling applied for this pair.
    _RestoreActorScale(akA1)
    _RestoreActorScale(akA2)
    ; Un-pacify (restore original aggression) both.
    _PacifyActor(akA1, False)
    _PacifyActor(akA2, False)
    ; Deliberately NO Acheron.ReleaseActor here. Releasing the victim's two-way pacify at pair-cleanup
    ; opened a real window (confirmed live, 15:40 session): QTE lost -> cleanup released the player ->
    ; all three falmers re-targeted them during the struggle->scene transition -> the scene CTD guard
    ; refused the scene. The victim's untargetable state must survive every internal transition
    ; (downed -> struggle -> scene -> re-down); it ends ONLY at the genuine exits: _PostEscapeGrace
    ; (escape/scene end, which releases after the mercy window) or recovery via _ClearAcheronHold.
    akA1.StopTranslation()
    akA2.StopTranslation()
    akA1.SetRestrained(False)
    akA1.SetDontMove(False)
    akA2.SetRestrained(False)
    akA2.SetDontMove(False)
    If hadPlayer
        Game.ForceThirdPerson()
        PlayerRef.SetDontMove(False)   ; release the player pin (we pinned instead of ghosting)
        PlayerRef.SetRestrained(False)
        ; OStim sets this for player scenes; a scene that got force-stopped mid-thread (or refused)
        ; strands it, and nothing else clears it — the reported "can't attack + camera off" combo.
        Game.SetPlayerAIDriven(False)
    EndIf
    Game.EnablePlayerControls()
    _Log("[SNBaka] CleanupPair: player controls re-enabled (bSkipA2Reset=" + bSkipA2Reset + ")")

    _StopTears(akA2)

    ; Reset the hard auto-get-up ceiling to the full duration for whichever of the pair is STILL down
    ; once this paired animation ends -- being actively engaged with (win or lose, Struggle/ChokeHug/
    ; Inspect/Escalate/CreatureEscalate, all of them route through here) means the clock isn't why
    ; they're still down, so it shouldn't get to expire out from under them mid-scene. Single, central
    ; hook: every paired interaction in this file ends at _CleanupPair, so nothing needs its own
    ; special-cased reset call. _IsDownedAny, not a bare OnGround check -- an Acheron-held victim has
    ; SNAcheron.Held=1 with OnGround=0, and the OnGround-only version of this check silently skipped
    ; exactly the actors the reset exists for.
    If _IsDownedAny(akA1)
        StorageUtil.SetFloatValue(akA1, "SNBaka.AutoGetUpDeadlineRT", Utility.GetCurrentRealTime() + StorageUtil.GetFloatValue(PlayerRef, "SNAcheron.AutoGetUpSeconds", 600.0))
    EndIf
    If _IsDownedAny(akA2)
        StorageUtil.SetFloatValue(akA2, "SNBaka.AutoGetUpDeadlineRT", Utility.GetCurrentRealTime() + StorageUtil.GetFloatValue(PlayerRef, "SNAcheron.AutoGetUpSeconds", 600.0))
    EndIf

    If marker1
        marker1.Delete()
    EndIf
    If marker2
        marker2.Delete()
    EndIf
EndFunction

; The MERCY window: hold (or re-apply) the victim's ghost for fEscapeGraceDuration seconds at every
; exit from the protected interaction pipeline -- a won struggle OR the end of a sex scene -- so
; nobody gets spawn-killed the exact frame the protection drops (confirmed from testing: a third
; falmer attacked the player the second their won struggle finished). Deliberately BLOCKING -- the
; calling thread is this encounter's own worker, and holding it here also keeps whatever locks/
; cooldowns/re-downs follow from firing until the mercy ends. Ghost blocks incoming hits only; the
; victim can still fight, flee, or loot during the window.
Function _PostEscapeGrace(Actor akWinner)
    If !akWinner
        Return
    EndIf
    If fEscapeGraceDuration <= 0.0
        akWinner.SetGhost(False)   ; callers rely on this function ending the ghost either way
        _ReleaseAcheronPacify(akWinner)
        Return
    EndIf
    akWinner.SetGhost(True)
    _Log("[SNBaka] _PostEscapeGrace: " + akWinner.GetDisplayName() + " untouchable for " + fEscapeGraceDuration + "s of mercy")
    Utility.Wait(fEscapeGraceDuration)
    akWinner.SetGhost(False)
    ; This is the ONE place the struggle/scene-scoped two-way pacify (_SetupPair / the scene paths)
    ; ends for a victim who walks free — after the mercy window, never mid-transition. A victim who is
    ; re-downed instead never comes through here un-defeated, so their pacify carries straight into
    ; Acheron's own defeat state with no targetable gap (the "3 falmers re-targeted the player between
    ; struggle and scene" report). Recovery paths end it via _ClearAcheronHold instead.
    _ReleaseAcheronPacify(akWinner)
    _Log("[SNBaka] _PostEscapeGrace: ended for " + akWinner.GetDisplayName())
EndFunction

; Release Acheron's two-way pacify, but never strip it from an actor Acheron currently holds
; DEFEATED (a defeated actor is always pacified — that protection belongs to the down state).
Function _ReleaseAcheronPacify(Actor ak)
    If ak && StorageUtil.GetIntValue(PlayerRef, "SNAcheron.Present", 0) == 1 && !Acheron.IsDefeated(ak)
        Acheron.ReleaseActor(ak)
    EndIf
EndFunction

; Clears only akA1's lock/stop flags without starting the cooldown timer.
; Used after a QTE defeat so the attacker is free to trigger Escalate_Execute
; while the victim remains locked during the ground window.
Function _UnlockAttackerOnly(Actor akA1)
    StorageUtil.SetIntValue(akA1, "SNBaka.Locked",        0)
    StorageUtil.SetIntValue(akA1, "SNBaka.StopRequested", 0)
EndFunction

; Called after a QTE defeat. Victim drops to the ground for fEscalationWindow
; seconds. During that window the attacker is free; if Escalate_Execute fires,
; _DoEscalation runs. Otherwise the victim is released and a cooldown starts.
Function _DefeatGroundWindow(Actor akA1, Actor akA2)
    _Log("[SNBaka] _DefeatGroundWindow: attacker=" + akA1.GetDisplayName() + " victim=" + akA2.GetDisplayName() + " window=" + fEscalationWindow)
    If !akA2 || akA2.IsDead()
        _Log("[SNBaka] _DefeatGroundWindow: victim already dead/None — aborting")
        StorageUtil.SetIntValue(akA2, "SNBaka.Locked",        0)
        StorageUtil.SetIntValue(akA2, "SNBaka.StopRequested", 0)
        _StartCooldown(akA1)
        Return
    EndIf

    ; DELEGATE to Acheron when present: it OWNS the downed state (hold + calm + recover + "X is downed"
    ; cues), so we just hand the victim over and step out. The acheron_downed cue then drives the next
    ; action (Rescue / Escalate-when-clear / etc.). This now includes the PLAYER -- explicit spec: a
    ; defeated player must stay down until the get-up key, help, or a won QTE, exactly like a combat
    ; defeat; the old player-only local window below auto-released them after fEscalationWindow, which
    ; is an unsanctioned self-recovery. The fallback window below only runs when Acheron is absent
    ; (Baka standalone), where the timed release is BY DESIGN the only recovery system there is.
    If _DelegateDownToAcheron(akA2)
        _UnlockAttackerOnly(akA1)
        StorageUtil.SetIntValue(akA2, "SNBaka.Locked",        0)
        StorageUtil.SetIntValue(akA2, "SNBaka.OnGround",      0)
        StorageUtil.SetStringValue(akA2, "SNBaka.DownPose",   "")
        StorageUtil.SetFormValue(akA2, "SNBaka.GroundWindowAggressor", None)
        _StartCooldown(akA1)
        _Log("[SNBaka] _DefeatGroundWindow: delegated downed state to Acheron for " + akA2.GetDisplayName())
        Return
    EndIf

    Bool a2IsPlayer = (akA2 == PlayerRef)
    _Log("[SNBaka] _DefeatGroundWindow: victim isPlayer=" + a2IsPlayer)
    If a2IsPlayer
        Game.DisablePlayerControls(True, True, False, False, True, False, False, False)
        ; (No SetDontMove on the player — it locked the camera. The NPC is ghosted so it can't
        ; shove the player, and the player isn't ghosted so they won't fall; no pin needed.)
    EndIf
    ; Clear every downed-menu request flag BEFORE OnGround=1 (OnGround=1 is when the downed
    ; menu becomes openable). Any pick made from here on survives into the wait loop — this
    ; fixes the menu choice sometimes doing nothing because the old post-settle reset flushed
    ; a quick pick made during the ~1.5s settle.
    _bEscalateRequested = False
    _bReleaseRequested  = False
    _iDownedReplay      = 0
    _bStandBack         = False
    _bResetDownWindow   = False
    StorageUtil.SetIntValue(akA2, "SNBaka.InspectCount", 0)   ; fresh down -> reset the inspect-loop guard
    StorageUtil.SetStringValue(akA2, "SNBaka.DownPose", "")   ; fresh down -> re-roll the pose (then it sticks)
    ; Set OnGround=1 immediately so Interact_ShowMenu's downed-menu shortcut can detect
    ; the downed victim as soon as the attacker's lock is released (before _Bleedout).
    StorageUtil.SetIntValue(akA2, "SNBaka.OnGround", 1)
    ; Records WHO owns this window, so LockBoth can let THIS SAME aggressor's follow-up actions
    ; (PinHelpless/GropeHelpless/etc. — see LockBoth) through despite the victim being locked for the
    ; window's duration, instead of silently bouncing off IsActorLocked like every other caller.
    StorageUtil.SetFormValue(akA2, "SNBaka.GroundWindowAggressor", akA1)
    _ForceEssentialForDown(akA2, True)
    _Log("[SNBaka] _DefeatGroundWindow: OnGround=1 (early — downed menu ready)")
    _Bleedout(akA2, akA1)
    _Log("[SNBaka] _DefeatGroundWindow: bleedout on " + akA2.GetDisplayName())
    _StartTears(akA2)
    Utility.Wait(0.5)
    If !a2IsPlayer
        akA2.SetRestrained(True)
        akA2.SetDontMove(True)
        ; The reworked down pose is a plain idle (not vanilla bleedout), so the NPC could
        ; re-enter/initiate combat and break the scene. Pacify (Aggression 0) + stop combat +
        ; DoNothing AI for the duration; original aggression restored on release.
        _PacifyActor(akA2, True)
        _HoldActorAI(akA2, True)
        _Log("[SNBaka] _DefeatGroundWindow: Restrained+DontMove+pacified on NPC victim")
    EndIf
    If _bDruggedEscalation
        _Notify(akA2.GetDisplayName() + " collapses, unconscious.")
    ElseIf akA1 == PlayerRef
        ; Player is the one standing over the defeated NPC — the decision is theirs.
        _Notify("What will you do to " + akA2.GetDisplayName() + "?")
    ElseIf akA2 == PlayerRef
        ; NPC is standing over the player.
        _Notify(akA1.GetDisplayName() + " stands over you. What will they do?")
    Else
        ; NPC over NPC — the player is just witnessing.
        _Notify(akA1.GetDisplayName() + " stands over " + akA2.GetDisplayName() + ".")
    EndIf

    ; 1-second settle: lets the down pose stabilise and flushes any stale Escalate_Execute
    ; calls that may have arrived before the window opened.
    Utility.Wait(1.0)
    ; (Flags were already cleared at the top, before OnGround=1 — do NOT clear them again here,
    ; or a downed-menu pick made during this settle would be lost.)
    _Log("[SNBaka] _DefeatGroundWindow: escalate window open (" + fEscalationWindow + "s)")
    If _bDruggedEscalation
        SkyrimNetApi.RegisterEvent("baka_defeat", \
            akA2.GetDisplayName() + " is unconscious — drugged by " + akA1.GetDisplayName() + ". " + \
            "They are completely unaware of what is happening and cannot resist in any way. " + \
            "Roleplay them as limp, unresponsive, breathing slowly. " + \
            akA1.GetDisplayName() + " must now decide what to do with the helpless " + akA2.GetDisplayName() + ".", \
            akA1, akA2)
    Else
        ; This is the LOCKED ground window: the victim is pinned, so aggressive acts like grope/choke/
        ; struggle (which call LockBoth) would silently fail here — don't offer them. Escalate and HelpUp
        ; both work (HelpUp calls _ForceRecover directly, no lock needed), same as Release.
        SkyrimNetApi.RegisterEvent("baka_defeat", \
            akA2.GetDisplayName() + " is beaten down and pinned, helpless at " + akA1.GetDisplayName() + "'s feet. " + \
            akA1.GetDisplayName() + " can talk to them — interrogate, threaten, mock, demand their surrender " + \
            "or belongings — but must still decide NOW and carry it out (use the action, don't just describe it) " + \
            "— exactly ONE of: Escalate (force them into sex; use the Escalate action — never StartNewSex), " + \
            "HelpUp (show mercy, stand them up), or Release (step back, let the moment pass). " + \
            "Pick ONE and do it now. " + akA2.GetDisplayName() + " reacts. One beat.", \
            akA1, akA2)
    EndIf

    Float elapsed = 0.0
    Float tick    = 0.2
    Float sinceHold = 0.0
    Float sinceCue  = 0.0
    Bool escalated = False
    Bool sceneTookOver = False
    ; No time-based hard cap here on purpose — recovery is strictly the 3 conditions (HelpUp, nobody
    ; around, win the QTE), full stop. A cap that fires on raw elapsed time regardless of presence would
    ; stand the victim up even while the aggressor is still right there mid-decision, silently bypassing
    ; the rule. HelpUp/Release/QTE-win are always available regardless of proximity, so there's no
    ; realistic "stuck forever" case this was actually needed for.
    While elapsed < fEscalationWindow && !escalated && !sceneTookOver && !_bReleaseRequested && !_bStandBack
        Utility.Wait(tick)
        elapsed += tick
        sinceHold += tick
        ; A sex scene has taken the victim — started by Baka's Escalate OR by ANOTHER mod (OStimNet /
        ; SexLab) that we don't drive. Stop managing them immediately so we never recover or re-pose them
        ; mid-scene (that yanks the body out of the running animation). Exit and hand them to the scene.
        If IsInSexAnimation(akA2)
            sceneTookOver = True
        EndIf
        ; PRESENCE-BASED HOLD (same model as Downed_SkyrimNet — same ~10m/700-unit radius): while ANY
        ; actor is near the victim, keep them down — reset the recover countdown (elapsed). They only
        ; stand up once the area has cleared for fEscalationWindow seconds, or via Escalate / Release /
        ; HelpUp. This is what stops an attacker "backing up" and the victim popping up mid-sequence.
        If _AnyActorNear(akA2, 700.0)
            elapsed = 0.0
        EndIf
        If _bResetDownWindow
            ; An aggressor just interacted with the downed victim (LLM inspect/etc.) — keep them down
            ; and protected.
            _bResetDownWindow = False
            elapsed = 0.0
            _Log("[SNBaka] _DefeatGroundWindow: down timer reset by interaction")
        EndIf
        If sinceHold >= 3.0 && !sceneTookOver
            ; Re-assert the SAME cached down pose so the engine/AI can't reclaim the actor and
            ; visibly swap the pose. Static pose -> safe to re-assert for the player too (it's only
            ; an anim event, not SetDontMove, so it won't lock the camera). NEVER re-pose once a sex
            ; scene has taken over, or the down pose fights the running sex animation.
            sinceHold = 0.0
            String dp = StorageUtil.GetStringValue(akA2, "SNBaka.DownPose", "")
            If dp != ""
                Debug.SendAnimationEvent(akA2, dp)
            EndIf
        EndIf
        ; Nothing decided yet — the initial baka_defeat cue fired once and the attacker may just sit on
        ; it (an LLM turn can easily miss a one-shot cue). Re-cue every ~15s so "the attacker overpowered
        ; them and just stands there" doesn't go silent — same idea as Acheron's periodic reminder, kept
        ; here too since this window runs standalone (no Acheron involved).
        sinceCue += tick
        If sinceCue >= 15.0 && !sceneTookOver
            sinceCue = 0.0
            _CueDecisionIfDowned(akA1, akA2, False)   ; passive reminder — do NOT reset the recovery clock
        EndIf
        If _bEscalateRequested
            _bEscalateRequested = False
            ; _DoEscalation itself also gates on this (every escalation path funnels through it), but by
            ; the time it runs here the victim has ALREADY been unconditionally _Recover()'d a few lines
            ; below (stood up) regardless of what _DoEscalation decides — so its own "victim stays down"
            ; comment was being silently broken: a combat-blocked escalate stood the victim up with no
            ; way to retry (Escalate_Execute requires OnGround, which _Recover just cleared). Confirmed
            ; from a live log: Escalate accepted -> _Recover -> _DoEscalation blocked (combat near) ->
            ; retry a few seconds later rejected with "target not downed". Check here, BEFORE recovering,
            ; so a blocked escalate leaves the victim down and the window still running, exactly like the
            ; request was never made — same as _DoEscalation's other two callers, which never recover
            ; the victim ahead of time and simply hit the same gate the moment they call it.
            If _CombatNear(akA2, fCombatOverRadius)
                _Log("[SNBaka] _DefeatGroundWindow: escalate requested but combat still near — victim stays down, window keeps running")
                SkyrimNetApi.RegisterEvent("baka_escalate", \
                    akA1.GetDisplayName() + " stands over the beaten " + akA2.GetDisplayName() + " — but the fight is not over yet. Finish it first, then they can be taken.", \
                    akA1, akA2)
            Else
                escalated = True
                _Log("[SNBaka] _DefeatGroundWindow: escalate requested at t=" + elapsed)
            EndIf
        ElseIf _iDownedReplay > 0
            ; Downed-menu Investigate/Inspect: play the inspection anim through (no QTE),
            ; re-down the victim, and reset the window timer so they stay defeated.
            Int replayWhich = _iDownedReplay
            _iDownedReplay = 0
            _Log("[SNBaka] _DefeatGroundWindow: downed replay " + replayWhich + " at t=" + elapsed)
            _DownedReplay(akA1, akA2, replayWhich)
            ; Only NPC victims get the window timer reset here. The PLAYER isn't reset by the replay
            ; itself, but an aggressor close enough to inspect them is also close enough to trip the
            ; _AnyActorNear check above on the very same tick, which resets elapsed anyway — so this
            ; doesn't leave the player any less protected, it just avoids a redundant reset.
            If !a2IsPlayer
                elapsed = 0.0
                _Log("[SNBaka] _DefeatGroundWindow: replay done — window timer reset, NPC victim still down")
            Else
                _Log("[SNBaka] _DefeatGroundWindow: replay done — PLAYER victim")
            EndIf
        EndIf
    EndWhile

    If sceneTookOver
        ; A sex scene (Baka or another mod, e.g. OStimNet) owns the victim now. Do NOT _Recover or send a
        ; stand-up — that pulls them out of the running animation. Just drop our down flags and let the
        ; scene recover them when it ends.
        StorageUtil.SetIntValue(akA2, "SNBaka.OnGround",      0)
        StorageUtil.SetStringValue(akA2, "SNBaka.DownPose",   "")
        StorageUtil.SetIntValue(akA2, "SNBaka.StopRequested", 0)
        StorageUtil.SetIntValue(akA2, "SNBaka.Locked",        0)
        StorageUtil.SetFormValue(akA2, "SNBaka.GroundWindowAggressor", None)
        If !a2IsPlayer
            _HoldActorAI(akA2, False)
        EndIf
        _bEscalateRequested = False
        _bReleaseRequested  = False
        _bStandBack         = False
        _Log("[SNBaka] _DefeatGroundWindow: a sex scene took over -> standing down WITHOUT recovery")
        _StartCooldown(akA1)
        Return
    EndIf

    Bool standBack = _bStandBack
    _bStandBack    = False
    Bool released = _bReleaseRequested
    If released
        _Log("[SNBaka] _DefeatGroundWindow: release requested at t=" + elapsed + " — freeing victim early")
    EndIf
    _bEscalateRequested = False
    _bReleaseRequested  = False

    If escalated
        _Notify(akA1.GetDisplayName() + " makes their move.")
    ElseIf standBack
        _Notify(akA1.GetDisplayName() + " stands back; " + akA2.GetDisplayName() + " staggers to their feet.")
    ElseIf released
        _Notify(akA1.GetDisplayName() + " steps back and lets you go.")
    Else
        _Notify(akA1.GetDisplayName() + " backs away.")
    EndIf
    StorageUtil.SetIntValue(akA2, "SNBaka.OnGround", 0)
    StorageUtil.SetFormValue(akA2, "SNBaka.GroundWindowAggressor", None)
    akA2.SetRestrained(False)
    akA2.SetDontMove(False)
    If !a2IsPlayer
        _PacifyActor(akA2, False)
        _HoldActorAI(akA2, False)
    EndIf
    _Log("[SNBaka] _DefeatGroundWindow: OnGround=0. escalated=" + escalated)

    If standBack
        ; Stand Back: a visible stagger as they scramble up, then the normal recover/stand.
        Debug.SendAnimationEvent(akA2, "staggerStart")
        Utility.Wait(0.3)
    EndIf
    _Recover(akA2)
    ; Only stand the player up if we are NOT about to chain into escalation.
    ; If escalated, _DoEscalation will handle controls and positioning directly.
    If a2IsPlayer && !escalated
        Game.EnablePlayerControls()
        Debug.SendAnimationEvent(akA2, "IdleForceDefaultState")
        _Log("[SNBaka] _DefeatGroundWindow: player controls re-enabled")
    EndIf

    If escalated
        _Log("[SNBaka] _DefeatGroundWindow: escalating to _DoEscalation")
        _DoEscalation(akA1, akA2)
    Else
        _Log("[SNBaka] _DefeatGroundWindow: window expired without escalation")
        StorageUtil.SetIntValue(akA2, "SNBaka.Locked",        0)
        StorageUtil.SetIntValue(akA2, "SNBaka.StopRequested", 0)
        _CueOutcome("baka_forced", \
            akA2.GetDisplayName() + " was left defeated on the ground by " + akA1.GetDisplayName() + ", and slowly recovers.", \
            akA1, akA2)
        If akA1 == PlayerRef || akA2 == PlayerRef
            Game.EnablePlayerControls()
        EndIf
        _StartCooldown(akA1)
    EndIf
EndFunction

; ── Sex-scene backend dispatch ───────────────────────────────────────────────
; iSexBackend: 0 = auto (SexLab if present, else OStim), 1 = SexLab, 2 = OStim.
; SexLab is resolved at runtime (GetFormFromFile in Setup) so SexLab.esm need NOT be a master.
; OStim runs a normal scene (OThread.QuickStart); it has no built-in aggressive system and we
; don't need one — the aggressive framing is narrative (RegisterEvent narration + expressions).
Int Function _ResolveSexBackend(Int aiPref = -1)
    Int b = aiPref
    If b < 0
        b = iSexBackend       ; -1 = use the normal-sex backend setting
    EndIf
    Bool hasSL = SkyrimNet_BakaSL.Installed()
    If b == 0
        If hasSL
            b = 1
        Else
            b = 2
        EndIf
    EndIf
    If b == 1 && !hasSL
        _Log("[SNBaka] _ResolveSexBackend: SexLab selected but not installed — falling back to OStim")
        b = 2
    EndIf
    Return b
EndFunction

; Starts a 2-actor scene on the configured framework and applies the tear overlay to the victim.
; ── SexLab tag matching ──────────────────────────────────────────────────────
; SexLab packs tag their anims very differently (Leito / Anubis / Billyy / ZaZ / FunnyBizness /
; Nibbles all use different words). Filtering on ONE canonical tag (e.g. "Aggressive") with
; requireAll often returns NOTHING, so the scene fails or picks at random. Instead we OR a wide
; synonym set per selection, suppress the opposite tone + the non-chosen positions, and fall back
; broader if needed — so a fitting scene is almost always found.
;   position  = "vaginal" / "anal" / "oral" / ""   intensity = "aggressive" / "loving" / ""
; (SexLab tag-matching + anim resolution moved to the SkyrimNet_BakaSL bridge — see StartScene there.)

; Callers pass a position + intensity selector; we build the OR tag filter (above). OStim ignores
; tags and picks its own scene.
Int Function _StartSexScene(Actor[] akActors, Actor akVictim, Actor akAggressor, String position, String intensity, Int aiBackend = -1)
    Int backend = _ResolveSexBackend(aiBackend)
    Int tid = -1
    ; FINAL combat gate, at the single choke point every scene start funnels through: if the PLAYER is
    ; among the actors and any combat is still live on or near them, REFUSE to start -- OStim CTDs
    ; (confirmed repeatedly) when its thread spins up while the player is in combat, and every earlier
    ; gate leaves a prep window where a fight can re-flare after the check. Over-blocking is the safe
    ; direction here: a refused scene falls through to each caller's existing no-scene handling (their
    ; wait loops see no animation and re-down the victim), and the retry pipeline gets another shot
    ; once things settle. IsInCombat() alone can be a stale alarm flag, but for a CTD guard a false
    ; positive just means "try again later" -- acceptable.
    Int gi = 0
    While gi < akActors.Length
        ; _CombatNear only — deliberately NOT PlayerRef.IsInCombat(): the player's own combat flag
        ; reflects OTHERS holding them in a combat list and lingers long after every attacker has been
        ; AI-held/lock-cleared ("after StopCombat(): IsInCombat()=TRUE" in the log). Gating on it
        ; refused every post-QTE scene — the reported escalate/refuse/re-down loop. Real combatants
        ; actively fighting near the player (the actual OStim hazard) is what _CombatNear measures.
        If akActors[gi] == PlayerRef && _CombatNear(PlayerRef, fCombatOverRadius)
            _Log("[SNBaka] _StartSexScene: REFUSED — player is in the scene with combat still live (CTD guard)")
            Return -1
        EndIf
        gi += 1
    EndWhile
    ; A defeat/aggressive scene runs far longer than the down/grab anims, so a calm cast earlier in the
    ; encounter may have lapsed — re-cast it for a fresh full duration so combat can't re-ignite under the
    ; scene. ONLY for participants who are actually IN COMBAT: a peaceful/consensual scene (e.g. two NPCs
    ; in a tavern) has no fight to suppress, so we don't needlessly Calm them.
    If SNBakaCalm
        Int ci = 0
        While ci < akActors.Length
            If akActors[ci] && akActors[ci] != PlayerRef && akActors[ci].IsInCombat()
                SNBakaCalm.Cast(akActors[ci], akActors[ci])
            EndIf
            ci += 1
        EndWhile
    EndIf
    If backend == 1
        tid = SkyrimNet_BakaSL.StartScene(akActors, akVictim, akAggressor, position, intensity)
        _Log("[SNBaka] _StartSexScene: SexLab tid=" + tid + " pos='" + position + "' int='" + intensity + "'")
    ElseIf backend == 2
        ; OStim. Instead of relying on OStim's default pick, we ask OStim's library for a scene that
        ; fits these actors and pin it as the starting animation. For aggressive escalation that pulls
        ; the forced/choke BakaFactory "Babo" scenes; the SAME query resolves CREATURE scenes when the
        ; actor array is [creature, victim]. Aggressor = dominant so OStim assigns roles correctly.
        Int bid = OThreadBuilder.Create(akActors)
        If bid < 0
            _Log("[SNBaka] _StartSexScene: OStim Create failed (invalid actor)")
            Return -1
        EndIf
        OThreadBuilder.NoFurniture(bid)
        If akAggressor && intensity == "aggressive"
            Actor[] doms = new Actor[1]
            doms[0] = akAggressor
            OThreadBuilder.SetDominantActors(bid, doms)
        EndIf
        String sceneId = _PickOStimScene(akActors, intensity)
        If sceneId == ""
            ; CREATURE scenes only start when we can PIN a matching animation — OStim's default pick
            ; can't resolve creature combos, so an empty pick means "no animation installed for this
            ; pairing" (confirmed live: giant scenes started with scene='' and died instantly, burning
            ; the whole prep cycle and exposing the AlignMenu null-thread crash). Refuse instead; the
            ; caller's no-scene unwind re-downs the victim and resets the creature cleanly. Human
            ; scenes keep OStim's default pick.
            Int ci = 0
            While ci < akActors.Length
                If akActors[ci] && _CreatureAnimKey(akActors[ci]) != ""
                    _Log("[SNBaka] _StartSexScene: REFUSED — no OStim animation found for this creature combination (an animation pack covering it, e.g. Billyy's, is not installed)")
                    OThreadBuilder.Cancel(bid)
                    Return -1
                EndIf
                ci += 1
            EndWhile
        Else
            OThreadBuilder.SetStartingAnimation(bid, sceneId)
        EndIf
        String meta = position
        If intensity != ""
            If meta != ""
                meta += ","
            EndIf
            meta += intensity
        EndIf
        If meta != ""
            OThreadBuilder.SetMetadataCSV(bid, meta)
        EndIf
        tid = OThreadBuilder.Start(bid)
        If tid < 0
            OThreadBuilder.Cancel(bid)        ; start failed — free the builder id so it isn't leaked
        EndIf
        _Log("[SNBaka] _StartSexScene: OStim tid=" + tid + " scene='" + sceneId + "' pos='" + position + "' int='" + intensity + "'")
    Else
        _Log("[SNBaka] _StartSexScene: no sex framework available — scene skipped.")
    EndIf
    If tid >= 0 && akVictim
        _ApplySexTears(akVictim)
        ; Stashed so a later hit/combat check (see the scene-wait loops in _EscalationCleanup and
        ; _DoCreatureEscalation) can force-stop THIS specific running scene without needing every
        ; caller to thread tid/backend through as extra parameters.
        StorageUtil.SetIntValue(akVictim, "SNBaka.SceneTid", tid)
        StorageUtil.SetIntValue(akVictim, "SNBaka.SceneBackend", backend)
    EndIf
    Return tid
EndFunction

; A hit on either animating actor (accidental or not) must stop the scene right now, not just wait for
; it to end -- OStim in particular crashes (confirmed via CrashLoggerSSE, null actor alignment inside
; OStim's AlignMenu) if combat resettles while its own thread is still running. Reads the tid/backend
; _StartSexScene stashed on the victim; no-op if none is running.
Function _StopSexScene(Actor akVictim)
    If !akVictim
        Return
    EndIf
    Int tid = StorageUtil.GetIntValue(akVictim, "SNBaka.SceneTid", -1)
    If tid < 0
        Return
    EndIf
    Int backend = StorageUtil.GetIntValue(akVictim, "SNBaka.SceneBackend", 0)
    _Log("[SNBaka] _StopSexScene: force-stopping tid=" + tid + " backend=" + backend + " for " + akVictim.GetDisplayName())
    If backend == 1
        SkyrimNet_BakaSL.StopScene(tid)
    ElseIf backend == 2
        OThread.Stop(tid)
    EndIf
    StorageUtil.SetIntValue(akVictim, "SNBaka.SceneTid", -1)
EndFunction

; Ask OStim's library for a scene that fits these actors. For aggressive escalation we first try
; forced/aggressive-tagged scenes (this is what pulls in the BakaFactory Babo "ChokeRape/Conquering/
; ThreateningMMF" scenes); we then fall back to any valid scene. Returns "" to mean "let OStim pick /
; no specific match".
String Function _PickOStimScene(Actor[] akActors, String intensity)
    String s = ""
    If _AnyCreatureIn(akActors)
        ; Creature packs are tagged by species, not "forced/aggressive/rape" like human packs — the
        ; human tag query below silently finds nothing for a creature pair. Superload is OStim's
        ; broader, untagged-friendly lookup; same technique Yamete Redux uses for its own creature
        ; scenes. No positive tag requirement — creature packs are sparse enough that adding one on
        ; top risks finding nothing at all, so just exclude the obviously-wrong "idle" scenes.
        s = OLibrary.GetRandomSceneSuperloadCSV(akActors, SceneTagBlacklist = "idle")
    ElseIf intensity == "aggressive"
        s = OLibrary.GetRandomSceneWithAnySceneTagCSV(akActors, "forced,aggressive,rape,choke,rough,dirty")
    EndIf
    If s == ""
        s = OLibrary.GetRandomScene(akActors)
    EndIf
    Return s
EndFunction

; Shared by both sex backends: does this actor array include a creature? Both _PickOStimScene (below)
; and SkyrimNet_BakaSL.StartScene (a separate script, hence Global + self-contained keyword lookup
; rather than reusing the instance-cached _kwActorTypeNPC/_IsCreatureActor) need this to route to the
; creature-aware animation lookup instead of the human one, which silently returns nothing usable for
; a creature actor.
Bool Function _AnyCreatureIn(Actor[] akActors) Global
    Keyword kwNPC = Game.GetFormFromFile(0x00013794, "Skyrim.esm") as Keyword
    If !kwNPC
        Return False
    EndIf
    Int i = 0
    While i < akActors.Length
        If akActors[i] && !akActors[i].HasKeyword(kwNPC)
            Return True
        EndIf
        i += 1
    EndWhile
    Return False
EndFunction

; Plays the strangle animation on the downed victim, then starts an aggressive scene.
; No second QTE — escalation goes directly to the configured sex framework.
Function _DoEscalation(Actor akA1, Actor akA2)
    ; Every HUMAN escalation path funnels here -- Escalate_Execute's "ours" branch (via the ground
    ; window's own loop), its "external" branch, and _DispatchDownedAction's external branch (the
    ; PrismaUI downed-menu AND AcheronNG's native Hunter's Pride menu both call that) -- so this one
    ; function is the actual shared gate for all of them. (Creature escalation does NOT go through
    ; here -- _DoCreatureEscalation calls _StartSexScene directly.)
    If _IsCreatureActor(akA1) || _IsCreatureActor(akA2)
        _Log("[SNBaka] _DoEscalation: blocked — creature actor")
        Return
    EndIf
    ; _TargetSexAllowed is a content-PREFERENCE filter (what should the LLM/an NPC be allowed to pick),
    ; not a technical constraint -- so, same precedent as bNPCCanEscalate below, it only gates a
    ; non-player initiator. The player pressing Hunter's Pride (or the PrismaUI menu) on a specific
    ; target, including a male one with iTargetSex set to female-only, is their own deliberate choice
    ; and shouldn't be second-guessed here.
    If akA1 != PlayerRef && !_TargetSexAllowed(akA2)
        _Log("[SNBaka] _DoEscalation: blocked — target sex not allowed by MCM")
        Return
    EndIf
    ; ESCALATION IS THE ONLY COMBAT-GATED STEP. Forced sex (the OStim scene) is unstable mid-combat, so
    ; we NEVER start it while a fight is still going on near the victim. The victim stays down; the LLM is
    ; told to finish the fight first, and can escalate once it's over.
    If _CombatNear(akA2, fCombatOverRadius)
        _Log("[SNBaka] _DoEscalation: blocked — combat still ongoing nearby; deferring sex")
        SkyrimNetApi.RegisterEvent("baka_escalate", \
            akA1.GetDisplayName() + " stands over the beaten " + akA2.GetDisplayName() + " — but the fight is not over yet. Finish it first, then they can be taken.", \
            akA1, akA2)
        Return
    EndIf
    _Log("[SNBaka] _DoEscalation: A1=" + akA1.GetDisplayName() + " A2=" + akA2.GetDisplayName())
    ; Lock BOTH — not just the attacker. The victim must be Locked too, or (when the victim is the
    ; player) Downed_SkyrimNet keeps running its hold/recovery/creature-retry THROUGH the sex scene and
    ; fires the down pose into it, breaking the animation.
    StorageUtil.SetIntValue(akA1, "SNBaka.Locked", 1)
    StorageUtil.SetIntValue(akA2, "SNBaka.Locked", 1)

    Bool a1IsPlayer = (akA1 == PlayerRef)
    Bool a2IsPlayer = (akA2 == PlayerRef)

    If a1IsPlayer || a2IsPlayer
        Game.DisablePlayerControls(True, True, False, False, True, False, False, False)
        ; (No SetDontMove on the player — it locked the camera. The NPC is ghosted so it can't
        ; shove the player, and the player isn't ghosted so they won't fall; no pin needed.)
    EndIf

    akA1.StopCombat()
    akA1.StopCombatAlarm()
    akA2.StopCombat()
    akA2.StopCombatAlarm()

    ; Recover A2 from bleedout before positioning — SetAngle has no effect while
    ; the bleedout animation controls the actor's root bone.
    _Recover(akA2)
    Utility.Wait(0.3)

    ; Disable NPC↔player collision (teammate flag) + suppress AI (DoNothing package) so
    ; the choke pose holds.  Restored in _EscalationCleanup.
    SNBakaUI.SetNoCollision(akA1, True)
    SNBakaUI.SetNoCollision(akA2, True)
    _HoldActorAI(akA1, True)
    _HoldActorAI(akA2, True)
    ; Pacify both NPCs so the victim can't draw a weapon / fight back mid-animation. Restored in cleanup.
    _PacifyActor(akA1, True)
    _PacifyActor(akA2, True)
    ; Same two-way protection _SetupPair gives its victims — this inline setup predates that upgrade:
    ; _PacifyActor only stops the VICTIM fighting; Acheron's pacify stops everyone else TARGETING them
    ; ("ignoring & ignored"). Ends via _PostEscapeGrace or a real recovery, same lifecycle as everywhere.
    _ProtectVictimTargeting(akA2)
    ; Height-matching via Actor.SetScale was REMOVED — it caused runaway scaling (refActor's
    ; scale was never restored, so actors snowballed bigger) and a CTD scare, for marginal gain.
    ; Offsets are what looks best. If revisited, use a controlled NiOverride node-scale, not SetScale.

    ; A1 starts ~5 units in front of A2 (very close — 14 read too far apart).  z-offset 0
    ; places A1 at A2's EXACT Z so they're at the same height on stairs/slopes.
    Float angZ = akA2.GetAngleZ()
    ; Escalation is VICTIM-anchored (the victim is DOWNED in place), so this is the one case where the
    ; offset positions the ATTACKER relative to the (downed) victim. Tunable via SNBaka_Offsets.ini key
    ; "Escalation": x=right/left, y=front/back, z=up/down of the attacker vs the victim, rot=attacker
    ; facing (180 = facing the victim). Defaults fall back to fEscalDist_* / 180 so no .ini = old behavior.
    Float defDist = fEscalDist_NPC
    If akA2 == PlayerRef
        defDist = fEscalDist_PCVic
    EndIf
    Float ox   = SNBakaUI.GetOffset("Escalation", "x", 0.0)
    Float oy   = SNBakaUI.GetOffset("Escalation", "y", defDist)
    Float oz   = SNBakaUI.GetOffset("Escalation", "z", 0.0)
    Float orot = SNBakaUI.GetOffset("Escalation", "rot", 180.0)
    Float offX = (oy * Math.Sin(angZ)) + (ox * Math.Cos(angZ))
    Float offY = (oy * Math.Cos(angZ)) - (ox * Math.Sin(angZ))

    akA1.MoveTo(akA2, offX, offY, 0.0, False)
    Utility.Wait(0.1)
    ; Snap A1 to A2's Z (+ z offset), in case the navmesh nudged it off on a slope.
    akA1.SetPosition(akA1.GetPositionX(), akA1.GetPositionY(), akA2.GetPositionZ() + oz)
    akA1.SetAngle(0.0, 0.0, angZ + orot)
    akA2.SetAngle(0.0, 0.0, angZ)
    _Log("[SNBaka] _DoEscalation: A1 snapped to (" + akA1.GetPositionX() + "," + akA1.GetPositionY() + ") angle=" + (angZ + orot))
    _LogPair("Escalation", akA1, akA2, ox, oy, orot, angZ + orot)

    ; Roles: A1 (attacker) plays A2_S1 (crouching straddler), A2 (victim) plays A1_S1 (downed).
    Debug.SendAnimationEvent(akA1, "Babo_DefeatResist_A2_S1")
    Debug.SendAnimationEvent(akA2, "Babo_DefeatResist_A1_S1")
    _StartTears(akA2)
    _WaitOrAbort(akA1, akA2, 8.0)

    ; Transition directly to SexLab aggressive scene.
    Debug.SendAnimationEvent(akA1, "IdleForceDefaultState")
    Debug.SendAnimationEvent(akA2, "IdleForceDefaultState")
    Utility.Wait(0.5)

    _StartTears(akA2)

    _Log("[SNBaka] _DoEscalation: SexLab installed=" + SkyrimNet_BakaSL.Installed() + " drugged=" + _bDruggedEscalation)

    ; ── Player involved: open our PrismaUI encounter wizard (async).  The scene
    ; is started in _StartSexLabScene when the player finishes; cleanup happens
    ; there too.  No SkyrimNet_SexLab dependency. ─────────────────────────────
    If (a1IsPlayer || a2IsPlayer) && SNBakaUI.IsAvailable()
        _Log("[SNBaka] _DoEscalation: opening PrismaUI encounter wizard")
        ; The Interact menu pauses correctly because it opens from normal gameplay.
        ; Here the player is still under DisablePlayerControls from the choke, which
        ; stops PrismaUI's menu-pause from engaging.  Return control to a clean state
        ; first; the wizard's pauseGame=true then freezes everything during the picks.
        Game.EnablePlayerControls()
        SNBakaUI.ShowEncounterMenu(akA1, akA2)
        Return
    EndIf

    ; ── Automatic path (NPC-NPC, or no PrismaUI): aggressive scene ────────────
    Actor[] sexActors = new Actor[2]
    sexActors[0] = akA1
    sexActors[1] = akA2
    ; Escalation is always a non-consensual overpower -> aggressive tone, any position.
    Int sceneTid = _StartSexScene(sexActors, akA2, akA1, "", "aggressive")
    If sceneTid < 0
        _Log("[SNBaka] _DoEscalation: WARNING — scene failed to start (tid=" + sceneTid + "); narrating anyway, cleanup will run immediately (IsInSexAnimation will read false)")
    EndIf
    String npcNarr = akA1.GetDisplayName() + " overpowers " + akA2.GetDisplayName() + "."
    If _bDruggedEscalation
        npcNarr = akA1.GetDisplayName() + " takes advantage of the unconscious " + akA2.GetDisplayName() + ". " + \
            akA2.GetDisplayName() + " is unaware of what is being done to them — roleplay them as completely passive, limp, unresponsive."
        _bDruggedEscalation = False
    EndIf
    ; NPC-NPC scene: tell the LLM and show the player what's happening to whom.
    SkyrimNetApi.RegisterEvent("baka_sexlab_trigger", npcNarr, akA1, akA2)
    _Notify(npcNarr)
    _EscalationCleanup(akA1, akA2)
EndFunction

; Restores controls / locks / cooldown after an escalation.  Shared by the
; automatic path above and the async PrismaUI path in _StartSexLabScene.
Function _EscalationCleanup(Actor akA1, Actor akA2)
    ; This used to run immediately when the sex scene STARTED (called right after _StartSexScene, not
    ; after it ends) — meaning IdleForceDefaultState/EvaluatePackage/SetRestrained(False) fired on BOTH
    ; actors, and SNBaka.Locked was cleared, WHILE SexLab/OStim was actively mid-animation. Clearing the
    ; lock is what mattered most: it's the one signal that makes Acheron's poll defer, so clearing it
    ; early let Acheron start trying to manage/recover the same actor SexLab/OStim was still animating —
    ; two systems fighting over one actor mid-scene, a classic crash vector. Wait for the scene to
    ; actually be over (poll the same faction check IsEligible/etc. already use) before touching anything.
    _Log("[SNBaka] _EscalationCleanup: waiting for scene to end. A1=" + akA1.GetDisplayName() + " A2=" + akA2.GetDisplayName())
    ; Same nearby-teammate protection as PlayPairedSequence's own struggle phase, extended through the
    ; actual sex scene too — a downed/occupied actor is vulnerable to being "executed" by an unrelated
    ; mod's own AI-driven action for this whole window, not just during the preceding struggle.
    _ProtectNearbyAllies(akA2, akA1, True)
    ; The VICTIM is untouchable for the scene's whole duration, same rule as the struggle phase
    ; (_SetupPair now ghosts both participants): the aggressor's own faction allies won't kill its
    ; prey — a stray ally hit whiffs instead of staggering the animation or feeding OStim a combat
    ; transition mid-thread. The AGGRESSOR stays hittable on purpose: a genuine hit on IT (a rescuer
    ; interceding) is exactly what's allowed to break the scene, per the abort rule below.
    akA2.SetGhost(True)
    ; Ghost stops hits LANDING; Acheron's pacify makes combat IGNORE her outright (same mechanism its
    ; own defeat state uses — "the others stop attacking downed characters"), so attackers drop her as
    ; a target instead of whiffing at her for the whole scene. Scene-scoped: released after the loop.
    _ProtectVictimTargeting(akA2)
    Utility.Wait(2.0)   ; grace period: SexLab/OStim need a moment to add the actors to the scene faction
    Int waited = 0
    Bool sceneCut = False
    ; Force-stop the scene only when a REAL fight reaches the aggressor -- OStim crashes (confirmed
    ; CrashLoggerSSE, null actor alignment inside OStim's AlignMenu) if combat resettles while its own
    ; thread is running. Same refined rule as _ShouldAbort: combat STATE alone (the aggressor's faction
    ; alarm reacting to its ally attacking this very victim) doesn't count; only a live, non-downed
    ; combat target OTHER than the scene's own victim does -- that's what a genuine interceding hit
    ; produces (the aggressor's target switches to whoever hit it). The victim side isn't checked at
    ; all anymore: they're ghosted above, nothing can land on them.
    While IsInSexAnimation(akA2) && waited < 900 && !sceneCut   ; 15min hard cap (audit: a stuck faction flag pinned a VM thread for up to an hour)
        Actor a1t = akA1.GetCombatTarget()
        If akA1.IsInCombat() && a1t && a1t != akA2 && !a1t.IsDead() && !a1t.IsDisabled() && !_IsDownedAny(a1t)
            _Log("[SNBaka] _EscalationCleanup: " + akA1.GetDisplayName() + " is in a real fight against " + a1t.GetDisplayName() + " mid-scene — force-stopping")
            _StopSexScene(akA2)
            sceneCut = True
        Else
            Utility.Wait(1.0)
            waited += 1
        EndIf
    EndWhile
    _ProtectNearbyAllies(akA2, akA1, False)
    If akA2
        ; Scene over: hold the ghost a few MERCY seconds more before dropping it (no spawn-kills the
        ; frame the protection ends), THEN release the scene-scoped pacify.
        _PostEscapeGrace(akA2)
        If StorageUtil.GetIntValue(PlayerRef, "SNAcheron.Present", 0) == 1
            Acheron.ReleaseActor(akA2)   ; end the scene-scoped pacify; the captive re-down re-pacifies via DefeatActor
        EndIf
    EndIf
    If waited >= 900
        _Log("[SNBaka] _EscalationCleanup: WARNING — hit the 15min hard cap still IsInSexAnimation=true; proceeding anyway (stuck scene faction?)")
    Else
        _Log("[SNBaka] _EscalationCleanup: scene ended after " + waited + "s — proceeding with cleanup")
    EndIf
    ; Defensive: a long wait is exactly where an actor could go invalid (unloaded, killed, deleted) out
    ; from under us. Every call below assumes both are live; without this guard a None here would throw
    ; the same "call X on a None object" error on every single line for the rest of the function.
    If !akA1 || !akA2 || akA1.IsDisabled() || akA2.IsDisabled()
        _Log("[SNBaka] _EscalationCleanup: ABORTING — an actor went invalid while waiting for the scene to end (A1=" + akA1 + " A2=" + akA2 + ")")
        Return
    EndIf
    ; Restore collision (teammate flag). Cosmetic — order doesn't matter for these two.
    SNBakaUI.SetNoCollision(akA1, False)
    SNBakaUI.SetNoCollision(akA2, False)
    ; Restore any height-match scaling applied for this pair. Also cosmetic.
    _RestoreActorScale(akA1)
    _RestoreActorScale(akA2)
    ; Establish the "don't re-fight this person" relationship BEFORE anything below gives the attacker
    ; back the means to act on hostility (AI control, aggression). Confirmed bug: this used to run AFTER
    ; _HoldActorAI(akA1, False) and _PacifyActor(akA1, False) — a real timing window where the attacker's
    ; AI could re-evaluate combat with its normal aggression already restored and nothing yet telling it
    ; the player/victim was an ally, so it went straight back into combat seconds after the scene ended
    ; (confirmed in logs — Combat_pace, a third-party combat-AI mod, showed the attacker actively pacing
    ; through the entire window right after cleanup). The attacker returns to normal; the DEFEATED victim
    ; stays SUBDUED — "at the attacker's mercy": aggression is NOT restored and they're allied to the
    ; captor so neither re-aggros, until Release or HelpUp frees them.
    akA1.SetRelationshipRank(akA2, 4)
    ; SNBaka.Captive used to be set only in this NPC-only branch (SetRelationshipRank on an NPC's OWN
    ; faction/AI disposition is what actually needs the != PlayerRef guard -- the player has no AI to
    ; read it). That bundled the tracking flag in with it by accident: SNBaka.Captive is a plain
    ; narrative/state flag, "is this actor currently a subdued captive", which applies exactly the same
    ; whether the victim is the player or an NPC -- and Acheron's OnActorRescued now depends on it being
    ; accurate for BOTH. Confirmed bug: the player never got flagged, so the premature-AcheronNG-rescue
    ; fix silently didn't apply to the exact player scenario it was built for.
    StorageUtil.SetIntValue(akA2, "SNBaka.Captive", 1)
    If akA2 != PlayerRef
        akA2.SetRelationshipRank(akA1, 4)
    EndIf
    _Log("[SNBaka] _EscalationCleanup: relationship rank set (ally) BEFORE releasing AI/aggression — " + akA1 + " <-> " + akA2)
    ; Give the attacker back its AI package (so it resumes normal behavior instead of standing frozen),
    ; but NOT its aggression yet — confirmed in live testing that relationship rank alone isn't reliably
    ; enough to stop the attacker re-engaging (its underlying faction disposition can still read as
    ; hostile). The victim goes right back to being tracked as downed below, so the attacker stays
    ; pacified for exactly as long as the victim stays subdued — _ForceRecover/Acheron's own _Recover
    ; un-pacify the tracked SNBaka.GroundWindowAggressor when the victim is actually freed (HelpUp,
    ; Release, get-up QTE win, or the nobody-around timeout), not here.
    _HoldActorAI(akA1, False)
    _HoldActorAI(akA2, False)
    If akA2 == PlayerRef
        _PacifyActor(akA2, False)
    EndIf
    _Log("[SNBaka] _EscalationCleanup: AI released for " + akA1 + " — aggression stays held until the victim is actually freed")
    If akA1 == PlayerRef || akA2 == PlayerRef
        Game.EnablePlayerControls()
    EndIf
    akA1.SetRestrained(False)
    akA1.SetDontMove(False)
    akA2.SetRestrained(False)
    akA2.SetDontMove(False)
    StorageUtil.SetIntValue(akA1, "SNBaka.Locked",        0)
    StorageUtil.SetIntValue(akA2, "SNBaka.Locked",        0)
    StorageUtil.SetIntValue(akA1, "SNBaka.StopRequested", 0)
    StorageUtil.SetIntValue(akA2, "SNBaka.StopRequested", 0)
    ; Guarantee neither actor is left stuck in a down pose / ground flag after the scene ends.
    StorageUtil.SetIntValue(akA1, "SNBaka.OnGround", 0)
    StorageUtil.SetIntValue(akA2, "SNBaka.OnGround", 0)
    StorageUtil.SetStringValue(akA1, "SNBaka.DownPose", "")
    StorageUtil.SetStringValue(akA2, "SNBaka.DownPose", "")
    Debug.SendAnimationEvent(akA1, "IdleForceDefaultState")
    Debug.SendAnimationEvent(akA2, "IdleForceDefaultState")
    akA1.EvaluatePackage()
    akA2.EvaluatePackage()
    ; RE-DOWN after a defeat-sex scene: the victim (player or NPC) is still a defeated captive, so hand
    ; them back to Acheron (it re-holds + keeps them out of combat, freed only via HelpUp/Release or the
    ; bridge's nobody-around timeout). If Acheron isn't present this no-ops and the pre-existing subdue
    ; state stands. Previously skipped for the player, which is why the PC fully recovered right after sex.
    ; Re-track akA1 as the aggressor for this renewed down cycle — combat was stopped above, so a fresh
    ; GetCombatTarget() capture on Acheron's side would find nothing; set it directly instead, same as
    ; _DefeatGroundWindow does for an initial down. This is also what lets _ForceRecover/_Recover find
    ; akA1 again to finally un-pacify it once the victim is actually freed.
    StorageUtil.SetFormValue(akA2, "SNBaka.GroundWindowAggressor", akA1)
    ; Clean graph reset BEFORE the re-down (same fix as the creature path): OStim's post-scene reset
    ; is async and expression addons fight the skeleton right now — a collapse launched from a dirty
    ; graph intermittently fails to play ("did not animate correctly after the scene").
    Debug.SendAnimationEvent(akA2, "IdleForceDefaultState")
    Utility.Wait(0.5)
    _DelegateDownToAcheron(akA2)
    ; POSE ENFORCEMENT, same as the creature path: force the vanilla bleedout once the async defeat
    ; lands — post-scene graphs regularly eat the native collapse, leaving the victim standing frozen.
    If akA2 != PlayerRef
        Utility.Wait(1.5)
        If !akA2.IsDead()
            Debug.SendAnimationEvent(akA2, "BleedoutStart")
            _Log("[SNBaka] post-scene re-down: BleedoutStart enforced on " + akA2.GetDisplayName())
        EndIf
    EndIf
    ; Immediate "still down" nudge — same one every other intermediate action gets via UnlockBoth.
    ; Without this, coming back from a sex scene left the LLM waiting on Acheron's own up-to-30s poll
    ; to find out the victim is still down. _CueDecisionIfDowned already no-ops if the victim ISN'T
    ; down (HelpUp/Release already cleared it), so this only fires when there's actually a reason to.
    _CueDecisionIfDowned(akA1, akA2)
    _StartCooldown(akA1)
EndFunction

; Called by SkyrimNet_BakaIntegration.dll when the player finishes the encounter wizard.
; The DLL splits the player's picks into these strings (or role="cancel").
; akAggressor/akVictim are the escalation pair (one is the player).
Function _StartSexLabScene(String role, String intensity, String flavor, String actType, Actor akAggressor, Actor akVictim)
    _Log("[SNBaka] _StartSexLabScene: role=" + role + " intensity=" + intensity + " flavor=" + flavor + " act=" + actType)
    Bool wasDrugged = _bDruggedEscalation
    _bDruggedEscalation = False

    ; ── Cancel: the aggressor changed their mind ─────────────────────────────
    If role == "cancel" || role == ""
        SkyrimNetApi.RegisterEvent("baka_release", \
            akAggressor.GetDisplayName() + " looms over " + akVictim.GetDisplayName() + \
            ", then stops — deciding against it and stepping back.", \
            akAggressor, akVictim)
        _EscalationCleanup(akAggressor, akVictim)
        Return
    EndIf

    ; ── Resolve roles relative to the player ─────────────────────────────────
    Actor npc = akAggressor
    If akAggressor == PlayerRef
        npc = akVictim
    EndIf
    Actor agg = PlayerRef
    Actor vic = npc
    Bool consensual = False
    If role == "they_take_me"
        agg = npc
        vic = PlayerRef
    ElseIf role == "together"
        agg = akAggressor
        vic = None
        consensual = True
    EndIf

    ; ── Normalize the action's act-type + intensity into our SexLab selectors ──
    String sexPos = ""
    If actType == "vaginal"
        sexPos = "vaginal"
    ElseIf actType == "anal" || actType == "painal"
        sexPos = "anal"
    ElseIf actType == "oral"
        sexPos = "oral"
    EndIf
    String sexInt = ""
    If intensity == "rough" || intensity == "brutal"
        sexInt = "aggressive"
    ElseIf intensity == "loving"
        sexInt = "loving"
    EndIf

    ; ── Start the scene (dispatched to the configured framework) ──────────────
    Actor[] sexActors = new Actor[2]
    If consensual
        sexActors[0] = akAggressor
        sexActors[1] = akVictim
    Else
        sexActors[0] = agg
        sexActors[1] = vic
    EndIf
    _StartSexScene(sexActors, vic, agg, sexPos, sexInt)

    ; ── Compose the roleplay narrative for SkyrimNet ─────────────────────────
    String aggName = agg.GetDisplayName()
    String vicName = akVictim.GetDisplayName()
    If !consensual
        vicName = vic.GetDisplayName()
    ElseIf agg == akVictim
        vicName = akAggressor.GetDisplayName()
    EndIf

    ; Present-continuous: the scene is UNFOLDING NOW with these parameters (not a
    ; past/finished statement), so the LLM roleplays it as it happens.
    String verb = " is now having sex with "
    If consensual
        If intensity == "loving"
            verb = " is now tenderly making love to "
        ElseIf intensity == "rough" || intensity == "brutal"
            verb = " is now having rough, eager sex with "
        EndIf
    Else
        If intensity == "brutal"
            verb = " is now violently raping "
        ElseIf intensity == "rough"
            verb = " is now roughly forcing themselves on "
        ElseIf intensity == "loving"
            verb = " is now taking "
        Else
            verb = " is now forcing themselves on "
        EndIf
    EndIf

    String typePhrase = ""
    If actType == "anal"
        typePhrase = ", anal"
    ElseIf actType == "painal"
        typePhrase = ", rough painful anal"
    ElseIf actType == "oral"
        typePhrase = ", oral"
    ElseIf actType == "vaginal"
        typePhrase = ", vaginal"
    EndIf

    String flavorPhrase = ""
    If flavor == "drugged" || wasDrugged
        flavorPhrase = ". " + vicName + " is drugged and unaware — roleplay them as limp and unresponsive"
    ElseIf flavor == "blackmail"
        flavorPhrase = ", coercing them through blackmail"
    ElseIf flavor == "power"
        flavorPhrase = ", abusing a position of power over them"
    ElseIf flavor == "degrading"
        flavorPhrase = ", degrading and humiliating them"
    ElseIf flavor == "gagged"
        flavorPhrase = ", a hand clamped over their mouth to keep them quiet"
    ElseIf flavor == "threatening"
        flavorPhrase = ", threatening them throughout"
    EndIf

    String narrative = aggName + verb + vicName + typePhrase + flavorPhrase + "."
    SkyrimNetApi.RegisterEvent("baka_sexlab_trigger", narrative, agg, akVictim)
    _Notify(narrative)

    _EscalationCleanup(akAggressor, akVictim)
EndFunction

; ============================================================
; Action execute functions — called by SkyrimNet YAML actions
;
; All-All notes:
;   • M/F-named and A01/A02-named animations are role-based.
;     Any initiator gender / target gender combination works.
;   • Actions marked [FEMALE TARGET REQUIRED] gate on HasFemaleBody(akTarget)
;     and return silently if the target has a male body.
;     This is an engine-level gate — bFemaleTargetOnly does not control it.
;
; bResistable = True on all panic actions.
; ============================================================

; ╔══════════════════════════════════════════════════════════════════════════╗
; ║  SCENE CUES TO SKYRIMNET — how every action tells the LLM what's going on. ║
; ║  Two cues per scene so the LLM both REACTS live and REMEMBERS it:          ║
; ║   _CueOngoing : a short-lived event that sits in the live SCENE CONTEXT    ║
; ║      for the scene's length, so the victim + nearby NPCs can react WHILE   ║
; ║      it happens. Phrase it present-tense, name who does what to whom, and   ║
; ║      (for forced acts) say the victim is held/helpless so the reaction      ║
; ║      lands. Keyed per-aggressor so it refreshes, not stacks.               ║
; ║   _CueOutcome : ONE persistent event for memory/history, past-tense, with  ║
; ║      the final result. Replaces the old deflating "X lets go" lines.       ║
; ║  sType is the tag the Director keys reactions off:                         ║
; ║   "baka_forced"  = non-consensual (fear/anger expected)                    ║
; ║   "baka_intimate"= consensual (warm/playful expected)                      ║
; ║  Always originator = aggressor, target = victim.                          ║
; ╚══════════════════════════════════════════════════════════════════════════╝
; Roleplay direction appended to every live scene cue: restate WHO is doing it to WHOM, and describe
; each actor's likely emotional state so the LLM voices whichever one it's generating correctly (the
; victim reacts, the aggressor stays in character). Reads in their NAMES so it's unambiguous.
String Function _RoleplayHint(String sType, Actor akAtk, Actor akVic)
    String a = akAtk.GetDisplayName()
    String v = akVic.GetDisplayName()
    If sType == "baka_forced"
        Return " " + a + " is the aggressor forcing this on " + v + ", who is held and cannot get away. " \
            + v + " would likely be anxious, panicking, frightened, angry, or pleading — whatever fits " + v \
            + "'s personality and this moment; " + a + " is in control and acting with intent. Speak and react in character as whichever of them is talking."
    ElseIf sType == "baka_intimate"
        Return " " + a + " is being affectionate toward " + v + ". " + v + " might respond shyly, warmly, with surprise, flustered, or playfully — depending on how close the two of them are. React in character."
    EndIf
    Return ""
EndFunction

Function _CueOngoing(String sType, String sDesc, Actor akAtk, Actor akVic, Float afSeconds = 25.0)
    If akAtk && akVic
        SkyrimNetApi.RegisterShortLivedEvent("baka_scene_" + akAtk.GetFormID(), \
            sType, sDesc + _RoleplayHint(sType, akAtk, akVic), "", (afSeconds * 1000.0) as Int, akAtk, akVic)
        If bDebugLog
            ; RecordAnimation (called just before this) stored the formal interaction name on the aggressor.
            String act = StorageUtil.GetStringValue(akAtk, "SNBaka.LastAnim", "?")
            _Notify("[Baka] " + act + ": " + akAtk.GetDisplayName() + " -> " + akVic.GetDisplayName())
            _Log("[SNBaka][ACTION] interaction=" + act + " type=" + sType \
                + " aggressor=" + akAtk.GetDisplayName() + " target=" + akVic.GetDisplayName() + " | " + sDesc)
        EndIf
    EndIf
EndFunction

Function _CueOutcome(String sType, String sSummary, Actor akAtk, Actor akVic)
    If akAtk && akVic
        SkyrimNetApi.RegisterEvent(sType, sSummary, akAtk, akVic)
    EndIf
EndFunction

; Resolves a resistable scene to ONE short outcome line: who won. The attacker-win path runs the
; defeat window (its own cue), so this is mostly the victim-escaped case. Third person, no detail —
; the live cue already said what was happening; here we only state the result.
Function _CueResistOutcome(String sType, Actor akAtk, Actor akVic)
    If !akAtk || !akVic
        Return
    EndIf
    String s
    If _bAELVictimEscaped
        s = akVic.GetDisplayName() + " broke free. It is over."
    Else
        s = akAtk.GetDisplayName() + " overpowered " + akVic.GetDisplayName() + ". It is over."
    EndIf
    _CueOutcome(sType, s, akAtk, akVic)
EndFunction

; Prints where a paired scene actually placed the actors (on-screen + log), so positioning can be
; reported precisely. Gated by bDebugPositions. asAnim = the playing event; afX/afY = requested offsets.
; Clear paired-anim position log. Reports the VICTIM's offset relative to the ATTACKER, with the
; attacker as the origin (0,0,0) facing forward: L/R (left-right), F/B (front-back), U (up), and the
; straight-line distance — plus the offset we ASKED for. This is the only positional log you need to
; tune from: e.g. "R12 F40 U-3 dist 42" = victim is 12 right, 40 in front, 3 below the attacker.
Function _LogPair(String sFn, Actor akAtk, Actor akVic, Float wantX, Float wantY, Float rotOffset, Float aAng)
    If !bDebugPositions || !akAtk || !akVic
        Return
    EndIf
    Float wdx = akVic.GetPositionX() - akAtk.GetPositionX()
    Float wdy = akVic.GetPositionY() - akAtk.GetPositionY()
    Int   dz  = (akVic.GetPositionZ() - akAtk.GetPositionZ()) as Int
    ; rotate the world delta back into the attacker's local frame
    Float lr  = (wdx * Math.Cos(aAng)) - (wdy * Math.Sin(aAng))   ; +right / -left
    Float fb  = (wdx * Math.Sin(aAng)) + (wdy * Math.Cos(aAng))   ; +front / -back
    Int   dist = akAtk.GetDistance(akVic) as Int
    String sLR = "R"
    If lr < 0.0
        sLR = "L"
    EndIf
    String sFB = "F"
    If fb < 0.0
        sFB = "B"
    EndIf
    String msg = sFn + ": victim vs attacker(0,0,0) = " \
        + sLR + (Math.Abs(lr) as Int) + " " + sFB + (Math.Abs(fb) as Int) + " U" + dz \
        + "  dist=" + dist + " rot=" + (rotOffset as Int) \
        + "  [asked R/L=" + (wantX as Int) + " F/B=" + (wantY as Int) + "]"
    _Notify("[Baka] " + msg)
    _Log("[SNBaka][POS] " + msg + "  aAng=" + (aAng as Int) \
        + "  ATK=" + akAtk.GetDisplayName() + "  VIC=" + akVic.GetDisplayName())
EndFunction

; ── Shared paired-anim setup ──────────────────────────────────────────────────────────────────
; ONE model for every paired animation:
;   * The ATTACKER (akAtk) is the origin (0,0,0). An NPC attacker is TELEPORTED onto the victim, so
;     the scene always happens where the victim was standing.
;   * The VICTIM (akVic) is then placed relative to the attacker:
;         xLocal = victim RIGHT(+) / LEFT(-)      yLocal = victim FRONT(+) / BACK(-)
;         rotOffset = victim facing minus attacker facing (180 = facing each other)
;   * The PLAYER is NEVER teleported: as the attacker they stay put and the victim comes to them; as
;     the victim they stay put and the attacker is placed so the victim still lands at the offset.
;   * Hard AI stop: DoNothing package + pacify + restrain + SetDontMove + ghost + vehicle-pin, so no
;     other mod / idle replacer can animate them until the scene ends (undone in _CleanupPair).
; mk1/mk2 are pre-placed XMarkers used to vehicle-pin the attacker/victim. sFn = label for the log.
Function _SetupPair(Actor akAtk, Actor akVic, Float xLocal, Float yLocal, Float rotOffset, \
        Bool bDisableCollision, ObjectReference mk1, ObjectReference mk2, String sFn)
    Bool atkPlayer = (akAtk == PlayerRef)
    Bool vicPlayer = (akVic == PlayerRef)

    akAtk.StopCombat()
    akAtk.StopCombatAlarm()
    akVic.StopCombat()
    akVic.StopCombatAlarm()
    akAtk.StopTranslation()
    akVic.StopTranslation()
    If !atkPlayer
        akAtk.SetVehicle(None)
    EndIf
    If !vicPlayer
        akVic.SetVehicle(None)
    EndIf
    akAtk.EvaluatePackage()
    akVic.EvaluatePackage()
    Utility.Wait(0.1)

    ; HARD AI STOP first, so nothing else drives them while we position. Fixed order, in order:
    ; calm (StopCombat above + pacify here) -> shrink/remove collision -> ghost + AI-hold + restrain/
    ; DontMove -> THEN reposition -> THEN animate (caller starts the anim after this returns). Ghost/
    ; Restrained/DontMove used to be applied AFTER the MoveTo/SetPosition block below, which left a
    ; ~0.2-0.4s window where a freshly-teleported actor was neither ghosted nor movement-locked yet --
    ; exactly the kind of window where residual AI/physics could nudge them before the pose locks in.
    SNBakaUI.SetNoCollision(akAtk, True)
    SNBakaUI.SetNoCollision(akVic, True)
    _HoldActorAI(akAtk, True)
    _HoldActorAI(akVic, True)
    _PacifyActor(akAtk, True)
    _PacifyActor(akVic, True)
    ; _PacifyActor is ONE-WAY: the actor itself stops fighting, but nothing above stops OTHERS from
    ; still TARGETING the victim mid-struggle (ghost only makes their hits whiff — they keep swinging,
    ; confirmed report). Acheron's native pacify is the two-way state the ground phase already enjoys
    ; ("ignoring & ignored by combat" — enemies drop them as a target entirely), and it's list-based
    ; native state, not a spell that wears off, so one call holds until released in _CleanupPair.
    ; VICTIM only: the AGGRESSOR must stay targetable so a genuinely hostile intercessor can still
    ; break the struggle by hitting IT (same rule as the scene paths). The player variant clears
    ; stale locks instead of pacifying — see _ProtectVictimTargeting.
    _ProtectVictimTargeting(akVic)
    If bDisableCollision
        ; BOTH actors, player included -- the player-victim exception here left them the one attackable
        ; participant in any struggle: confirmed from testing, a second falmer attacked the player
        ; mid-struggle and the hit/stagger broke the animation, three times in one session. Explicit
        ; spec: nobody attacks the victim of an aggression in progress. (The old "player isn't ghosted
        ; so they won't fall" concern predates SetNoCollision being applied unconditionally above --
        ; ghost only gates combat hit processing, not world collision, so there's nothing to fall
        ; through.) _CleanupPair already un-ghosts both actors unconditionally on every exit path.
        akAtk.SetGhost(True)
        akVic.SetGhost(True)
    EndIf
    If !atkPlayer
        akAtk.SetRestrained(True)
        akAtk.SetDontMove(True)
    EndIf
    If !vicPlayer
        akVic.SetRestrained(True)
        akVic.SetDontMove(True)
    EndIf

    ; --- editable offsets (SNBaka_Offsets.ini, key = sFn). Missing file/key falls back to the passed
    ; defaults, so no .ini == co-located + the action's own facing. x=R/L, y=F/B, z=up/down, rot=facing. ---
    Float ox   = SNBakaUI.GetOffset(sFn, "x",   xLocal)
    Float oy   = SNBakaUI.GetOffset(sFn, "y",   yLocal)
    Float oz   = SNBakaUI.GetOffset(sFn, "z",   0.0)
    Float orot = SNBakaUI.GetOffset(sFn, "rot", rotOffset)
    ; NPC -> PLAYER (player is the victim) can need different alignment than player -> NPC. Prefer a
    ; direction-specific "<sFn>_pcvic" key, falling back to the plain key's value above when it's not
    ; in the .ini — so existing tuning keeps working until a _pcvic override is added.
    If vicPlayer
        String kvic = sFn + "_pcvic"
        ox   = SNBakaUI.GetOffset(kvic, "x",   ox)
        oy   = SNBakaUI.GetOffset(kvic, "y",   oy)
        oz   = SNBakaUI.GetOffset(kvic, "z",   oz)
        orot = SNBakaUI.GetOffset(kvic, "rot", orot)
    EndIf
    ; PLAYER -> NPC (player is the attacker) never had the same per-direction override the victim
    ; case got above — it silently fell back to the plain/NPC-vs-NPC key. Player anchor geometry
    ; (vehicle marker, camera pivot) isn't identical to an NPC attacker's, so give it the same
    ; "<sFn>_pcatk" override lever, symmetric with _pcvic.
    If atkPlayer
        String katk = sFn + "_pcatk"
        ox   = SNBakaUI.GetOffset(katk, "x",   ox)
        oy   = SNBakaUI.GetOffset(katk, "y",   oy)
        oz   = SNBakaUI.GetOffset(katk, "z",   oz)
        orot = SNBakaUI.GetOffset(katk, "rot", orot)
    EndIf

    ; --- anchor on the ATTACKER ---
    Float aAng
    If atkPlayer
        aAng = akAtk.GetAngleZ()                       ; player attacker stays put
    ElseIf !vicPlayer
        akAtk.MoveTo(akVic)                            ; NPC attacker teleports ONTO the victim
        Utility.Wait(0.2)
        aAng = akAtk.GetAngleZ()
    Else
        aAng = akVic.GetAngleZ() - orot                ; player victim: keep the player's facing
    EndIf
    Float vAng = aAng + orot
    Float wdx  = (ox * Math.Cos(aAng)) + (oy * Math.Sin(aAng))
    Float wdy  = (oy * Math.Cos(aAng)) - (ox * Math.Sin(aAng))

    If vicPlayer
        ; never move the player — place the ATTACKER at (victim - offset) so victim ends at +offset.
        ; z: victim is +oz above the attacker, so the attacker sits oz BELOW the (fixed) player.
        akAtk.MoveTo(akVic, -wdx, -wdy, 0.0, False)
        Utility.Wait(0.2)                              ; let havok settle before the final snap
        ; Re-anchor off the PLAYER'S current position (not the just-settled attacker): if the
        ; attacker drifted during the settle wait, re-applying its own (drifted) X/Y here — as a
        ; prior version did — baked that drift in permanently once frozen below. Recomputing from
        ; the fixed player + offset guarantees an exact placement regardless of drift.
        akAtk.SetPosition(akVic.GetPositionX() - wdx, akVic.GetPositionY() - wdy, akVic.GetPositionZ() - oz)
        akAtk.SetAngle(0.0, 0.0, aAng)
    Else
        akAtk.SetAngle(0.0, 0.0, aAng)
        akVic.MoveTo(akAtk, wdx, wdy, 0.0, False)       ; victim to attacker + offset
        Utility.Wait(0.2)                              ; let havok settle before the final snap
        ; Re-anchor off the ATTACKER'S settled position (read fresh, not cached before the wait):
        ; either actor can drift a little during the settle, and the old code only re-snapped Z,
        ; leaving X/Y wherever havok left them — that's the "offset looks off" misalignment.
        akVic.SetPosition(akAtk.GetPositionX() + wdx, akAtk.GetPositionY() + wdy, akAtk.GetPositionZ() + oz)
        akVic.SetAngle(0.0, 0.0, vAng)
    EndIf

    ; --- vehicle-pin BOTH (ghost/restrain/DontMove already applied above, before repositioning) ---
    If mk1
        mk1.MoveTo(akAtk)
        If atkPlayer
            mk1.SetPosition(mk1.GetPositionX(), mk1.GetPositionY(), mk1.GetPositionZ() - 2.0 + _fPlayerZAdjust)
        EndIf
        akAtk.SetVehicle(mk1)
    EndIf
    If mk2
        mk2.MoveTo(akVic)
        If vicPlayer
            mk2.SetPosition(mk2.GetPositionX(), mk2.GetPositionY(), mk2.GetPositionZ() - 2.0 + _fPlayerZAdjust)
        EndIf
        akVic.SetVehicle(mk2)
    EndIf
    _HoldPinned(akAtk)
    _HoldPinned(akVic)
    _LogPair(sFn, akAtk, akVic, ox, oy, orot, aAng)
EndFunction

; --- BackHug ---
; Role anims: A1=BaboBackHugStartM/LoopM, A2=BaboBackHugStartF/LoopF
; Works on any gender combination.
Function BackHug_Execute(Actor akInitiator, Actor akTarget)
    _Log("[SNBakaACT] BackHug ENTER")
    If !IsEligible(akInitiator, akTarget)
        Return
    EndIf
    If !LockBoth(akInitiator, akTarget)
        Return
    EndIf
    RecordAnimation(akInitiator, "BackHug", akTarget.GetDisplayName())
    RecordAnimation(akTarget,    "BackHug", akInitiator.GetDisplayName())
    _CueOngoing("baka_intimate", \
        akInitiator.GetDisplayName() + " holds " + akTarget.GetDisplayName() + " from behind.", \
        akInitiator, akTarget)

    _ClearTearsForAffection(akInitiator, akTarget)
    PlayPairedLoopAnim(akInitiator, akTarget, \
        0.0, 0.0, 0.0, \
        "BaboBackHugStartM",    "BaboBackHugStartF", \
        "BaboBackHugLoopM",     "BaboBackHugLoopF", \
        2.0, fHugLoopDuration)

    _CueOutcome("baka_intimate", \
        akInitiator.GetDisplayName() + " held " + akTarget.GetDisplayName() + " from behind.", \
        akInitiator, akTarget)
    UnlockBoth(akInitiator, akTarget)
EndFunction

; --- BackHugMolest --- [bResistable]
; A1=BaboBackHugMolestStartM/LoopM, A2=BaboBackHugMolestStartF/LoopF
; Works on any gender combination.
Function BackHugMolest_Execute(Actor akInitiator, Actor akTarget)
    _Log("[SNBakaACT] BackHugMolest ENTER")
    If !IsEligible(akInitiator, akTarget)
        Return
    EndIf
    If !LockBoth(akInitiator, akTarget)
        Return
    EndIf
    RecordAnimation(akInitiator, "BackHugMolest", akTarget.GetDisplayName())
    RecordAnimation(akTarget,    "BackHugMolest", akInitiator.GetDisplayName())
    _CueOngoing("baka_forced", \
        akInitiator.GetDisplayName() + " gropes " + akTarget.GetDisplayName() + " from behind; " + akTarget.GetDisplayName() + " struggles.", \
        akInitiator, akTarget)
    PlayPanicSound(akTarget)
    _StartTears(akTarget)

    ; xLocal 4 nudges the attacker laterally; yLocal -55 (behind) is tuned for NPC-NPC. NPC-PC
    ; reads too close, so push the attacker ~8 further back whenever the player is involved.
    Float yMolest = fBackHugSep_NPC        ; see POSITIONING TUNING block at top
    If akInitiator == PlayerRef || akTarget == PlayerRef
        yMolest = fBackHugSep_PC
    EndIf
    ; NOTE: BaboBackHugMolest is authored as a FNIS *sequence* (s -a Start + cyclic Loop), not
    ; basic anims like Struggle/ChokeHug. A FNIS sequence is triggered by the START event ONLY —
    ; FNIS auto-chains to the looping continuation. Sending the Loop event ourselves yanked the
    ; actor out of the running sequence (back to default) — which is why it failed every time.
    ; So pass empty loop names: only Start fires, and the cyclic Loop plays on its own.
    PlayPairedLoopAnim(akInitiator, akTarget, \
        0.0, 0.0, 0.0, \
        "BaboBackHugMolestStartM",  "BaboBackHugMolestStartF", \
        "", "", \
        2.5, fMolestLoopDuration, True)

    ; Respect the QTE: only down the victim if they were actually defeated.  If they
    ; broke free (or weren't pinned), release them — no ground window.
    If _bQTEDefeated
        _bQTEDefeated = False
        _UnlockAttackerOnly(akInitiator)
        _DefeatGroundWindow(akInitiator, akTarget)
    Else
        _CueResistOutcome("baka_forced", akInitiator, akTarget)
        UnlockBoth(akInitiator, akTarget)
    EndIf
EndFunction

; --- FrontHug ---
; A1=BaboFrontHugStartM/LoopM, A2=BaboFrontHugStartF/LoopF
; Works on any gender combination.
Function FrontHug_Execute(Actor akInitiator, Actor akTarget)
    _Log("[SNBakaACT] FrontHug ENTER")
    If !IsEligible(akInitiator, akTarget)
        Return
    EndIf
    If !LockBoth(akInitiator, akTarget)
        Return
    EndIf
    RecordAnimation(akInitiator, "FrontHug", akTarget.GetDisplayName())
    RecordAnimation(akTarget,    "FrontHug", akInitiator.GetDisplayName())
    _CueOngoing("baka_intimate", \
        akInitiator.GetDisplayName() + " embraces " + akTarget.GetDisplayName() + ".", \
        akInitiator, akTarget)

    _ClearTearsForAffection(akInitiator, akTarget)
    PlayPairedLoopAnim(akInitiator, akTarget, \
        0.0, 0.0, 180.0, \
        "BaboFrontHugStartM",   "BaboFrontHugStartF", \
        "BaboFrontHugLoopM",    "BaboFrontHugLoopF", \
        2.0, fHugLoopDuration)

    _CueOutcome("baka_intimate", \
        akInitiator.GetDisplayName() + " and " + akTarget.GetDisplayName() + " shared a close embrace.", \
        akInitiator, akTarget)
    UnlockBoth(akInitiator, akTarget)
EndFunction

; --- ArmHold ---
; Affectionate: the initiator takes the target by the arm and holds them close. Gendered M/F
; parts like the hugs (M = initiator, F = target). Single loopable clip — no separate start/loop.
Function ArmHold_Execute(Actor akInitiator, Actor akTarget)
    _Log("[SNBakaACT] ArmHold ENTER")
    If !IsEligible(akInitiator, akTarget)
        Return
    EndIf
    If !LockBoth(akInitiator, akTarget)
        Return
    EndIf
    RecordAnimation(akInitiator, "ArmHold", akTarget.GetDisplayName())
    RecordAnimation(akTarget,    "ArmHold", akInitiator.GetDisplayName())
    _CueOngoing("baka_intimate", \
        akInitiator.GetDisplayName() + " takes " + akTarget.GetDisplayName() + " gently by the arm and holds them close.", \
        akInitiator, akTarget)
    _ClearTearsForAffection(akInitiator, akTarget)
    PlayPairedSimpleAnim(akInitiator, akTarget, \
        0.0, 0.0, 0.0, \
        "BaboHoldArmM", "BaboHoldArmF", \
        fHugLoopDuration)
    _CueOutcome("baka_intimate", \
        akInitiator.GetDisplayName() + " held " + akTarget.GetDisplayName() + " close by the arm.", \
        akInitiator, akTarget)
    UnlockBoth(akInitiator, akTarget)
EndFunction

; --- KissLove ---
; A1=BaboKissLoveS01/S02_A1, A2=BaboKissLoveS01/S02_A2
; Works on any gender combination.
Function KissLove_Execute(Actor akInitiator, Actor akTarget)
    _Log("[SNBakaACT] KissLove ENTER")
    If !IsEligible(akInitiator, akTarget)
        Return
    EndIf
    If !LockBoth(akInitiator, akTarget)
        Return
    EndIf
    RecordAnimation(akInitiator, "KissLove", akTarget.GetDisplayName())
    RecordAnimation(akTarget,    "KissLove", akInitiator.GetDisplayName())
    _CueOngoing("baka_intimate", \
        akInitiator.GetDisplayName() + " kisses " + akTarget.GetDisplayName() + " tenderly.", \
        akInitiator, akTarget)

    String[] a1 = new String[2]
    String[] a2 = new String[2]
    ; A1 animations = female role. Swap when male initiator kisses female target.
    Bool kissSwap = (akInitiator.GetActorBase().GetSex() == 0) && (akTarget.GetActorBase().GetSex() == 1)
    If kissSwap
        a1[0] = "BaboKissLoveS01_A2"
        a1[1] = "BaboKissLoveS02_A2"
        a2[0] = "BaboKissLoveS01_A1"
        a2[1] = "BaboKissLoveS02_A1"
    Else
        a1[0] = "BaboKissLoveS01_A1"
        a1[1] = "BaboKissLoveS02_A1"
        a2[0] = "BaboKissLoveS01_A2"
        a2[1] = "BaboKissLoveS02_A2"
    EndIf

    _ClearTearsForAffection(akInitiator, akTarget)
    PlayPairedSequence(akInitiator, akTarget, 0.0, 0.0, 180.0, a1, a2, fKissLoopDuration)

    _CueOutcome("baka_intimate", \
        akInitiator.GetDisplayName() + " and " + akTarget.GetDisplayName() + " shared a kiss.", \
        akInitiator, akTarget)
    UnlockBoth(akInitiator, akTarget)
EndFunction

; --- ForcedKiss --- [bResistable]
; Uses action-specific resist/stop anims: SLAPForcedKiss01_A1/A2_Resist and _Stop.
; Works on any gender combination.
Function ForcedKiss_Execute(Actor akInitiator, Actor akTarget)
    _Log("[SNBakaACT] ForcedKiss ENTER")
    If !IsEligible(akInitiator, akTarget)
        Return
    EndIf
    If !LockBoth(akInitiator, akTarget)
        Return
    EndIf
    RecordAnimation(akInitiator, "ForcedKiss", akTarget.GetDisplayName())
    RecordAnimation(akTarget,    "ForcedKiss", akInitiator.GetDisplayName())
    _CueOngoing("baka_forced", \
        akInitiator.GetDisplayName() + " forces a kiss on " + akTarget.GetDisplayName() + "; " + akTarget.GetDisplayName() + " struggles.", \
        akInitiator, akTarget)
    PlayPanicSound(akTarget)
    _StartTears(akTarget)

    ; A2_* = aggressor role, A1_* = passive/victim role (SLAP convention).
    ; Initiator is always the aggressor — always plays A2_*. No QTE.
    ; Face-to-face, very close (kiss).
    Float xKiss = fForcedKissSep_NPC
    If akInitiator == PlayerRef || akTarget == PlayerRef
        xKiss = fForcedKissSep_PC
    EndIf
    ; X axis = front-to-back gap for this SLAP kiss anim (its Y reads as lateral, which put them
    ; side-by-side). Keep yLocal 0 so they stay one directly in front of the other.
    ; bRefreshLoop=True: the SLAP kiss loop exits after one cycle, so re-fire it on a tick to keep
    ; the victim in the pose for the full duration (defaults spelled out to reach the trailing flag).
    PlayPairedLoopAnim(akInitiator, akTarget, \
        0.0, 0.0, 180.0, \
        "SLAPForcedKiss01_A2_S01",    "SLAPForcedKiss01_A1_S01", \
        "SLAPForcedKiss01_A2_Loop",   "SLAPForcedKiss01_A1_Loop", \
        2.0, fKissLoopDuration, \
        False, \
        "Babo_DefeatResist_A1_S1", "Babo_DefeatResist_A2_S1", \
        "Babo_DefeatResist_A1_S2", "Babo_DefeatResist_A2_S2", \
        None, True, True)

    _CueOutcome("baka_forced", \
        akInitiator.GetDisplayName() + " forced a kiss on " + akTarget.GetDisplayName() + " against their will.", \
        akInitiator, akTarget)
    UnlockBoth(akInitiator, akTarget)
EndFunction

; --- TouchBreasts --- [FEMALE TARGET REQUIRED]
; A1=Babo_TouchingBreasts_A01, A2=Babo_TouchingBreasts_A02
Function TouchBreasts_Execute(Actor akInitiator, Actor akTarget)
    _Log("[SNBakaACT] TouchBreasts ENTER")
    If !IsEligible(akInitiator, akTarget)
        Return
    EndIf
    If !HasFemaleBody(akTarget)
        Return
    EndIf
    If !LockBoth(akInitiator, akTarget)
        Return
    EndIf
    RecordAnimation(akInitiator, "TouchBreasts", akTarget.GetDisplayName())
    RecordAnimation(akTarget,    "TouchBreasts", akInitiator.GetDisplayName())
    _CueOngoing("baka_forced", \
        akInitiator.GetDisplayName() + " gropes " + akTarget.GetDisplayName() + "'s breasts; " + akTarget.GetDisplayName() + " struggles.", \
        akInitiator, akTarget)

    _StartTears(akTarget)
    PlayPairedSimpleAnim(akInitiator, akTarget, \
        0.0, 0.0, 180.0, \
        "Babo_TouchingBreasts_A02", "Babo_TouchingBreasts_A01", \
        fTouchLoopDuration)

    _CueOutcome("baka_forced", \
        akInitiator.GetDisplayName() + " groped " + akTarget.GetDisplayName() + "'s breasts.", \
        akInitiator, akTarget)
    UnlockBoth(akInitiator, akTarget)
EndFunction

; --- SuckBreasts --- [FEMALE TARGET REQUIRED]
; A1=Babo_SuckingBreasts_A01, A2=Babo_SuckingBreasts_A02
Function SuckBreasts_Execute(Actor akInitiator, Actor akTarget)
    _Log("[SNBakaACT] SuckBreasts ENTER")
    If !IsEligible(akInitiator, akTarget)
        Return
    EndIf
    If !HasFemaleBody(akTarget)
        Return
    EndIf
    If !LockBoth(akInitiator, akTarget)
        Return
    EndIf
    RecordAnimation(akInitiator, "SuckBreasts", akTarget.GetDisplayName())
    RecordAnimation(akTarget,    "SuckBreasts", akInitiator.GetDisplayName())
    _CueOngoing("baka_forced", \
        akInitiator.GetDisplayName() + " forces their mouth to " + akTarget.GetDisplayName() + "'s breasts; " + akTarget.GetDisplayName() + " struggles.", \
        akInitiator, akTarget)

    _StartTears(akTarget)
    PlayPairedSimpleAnim(akInitiator, akTarget, \
        0.0, 0.0, 180.0, \
        "Babo_SuckingBreasts_A02", "Babo_SuckingBreasts_A01", \
        fTouchLoopDuration)

    _CueOutcome("baka_forced", \
        akInitiator.GetDisplayName() + " forced their mouth on " + akTarget.GetDisplayName() + "'s breasts.", \
        akInitiator, akTarget)
    UnlockBoth(akInitiator, akTarget)
EndFunction

; --- ExaminePrivates --- [FEMALE TARGET REQUIRED] [bResistable]
; A1=BaboExaminePussyA1, A2=BaboExaminePussyA2
Function ExaminePrivates_Execute(Actor akInitiator, Actor akTarget)
    _Log("[SNBakaACT] ExaminePrivates ENTER")
    If !IsEligible(akInitiator, akTarget)
        Return
    EndIf
    If !HasFemaleBody(akTarget)
        Return
    EndIf
    If !LockBoth(akInitiator, akTarget)
        Return
    EndIf
    RecordAnimation(akInitiator, "ExaminePrivates", akTarget.GetDisplayName())
    RecordAnimation(akTarget,    "ExaminePrivates", akInitiator.GetDisplayName())
    _CueOngoing("baka_forced", \
        akInitiator.GetDisplayName() + " forces " + akTarget.GetDisplayName() + " open and examines them; " + akTarget.GetDisplayName() + " struggles.", \
        akInitiator, akTarget)
    PlayPanicSound(akTarget)
    _StartTears(akTarget)

    PlayPairedSimpleAnim(akInitiator, akTarget, \
        0.0, 0.0, 180.0, \
        "BaboExaminePussyA2", "BaboExaminePussyA1", \
        fTouchLoopDuration)

    If _bQTEDefeated
        _Log("[SNBaka] Execute: QTE defeated — calling DefeatGroundWindow. attacker=" + akInitiator.GetDisplayName() + " victim=" + akTarget.GetDisplayName())
        _bQTEDefeated = False
        _UnlockAttackerOnly(akInitiator)
        _DefeatGroundWindow(akInitiator, akTarget)
    Else
        _CueResistOutcome("baka_forced", akInitiator, akTarget)
        UnlockBoth(akInitiator, akTarget)
    EndIf
EndFunction

; --- PlayPrivates --- [FEMALE TARGET REQUIRED] [bResistable]
; A1=BaboPlayingPussyA1, A2=BaboPlayingPussyA2
Function PlayPrivates_Execute(Actor akInitiator, Actor akTarget)
    _Log("[SNBakaACT] PlayPrivates ENTER")
    If !IsEligible(akInitiator, akTarget)
        Return
    EndIf
    If !HasFemaleBody(akTarget)
        Return
    EndIf
    If !LockBoth(akInitiator, akTarget)
        Return
    EndIf
    RecordAnimation(akInitiator, "PlayPrivates", akTarget.GetDisplayName())
    RecordAnimation(akTarget,    "PlayPrivates", akInitiator.GetDisplayName())
    _CueOngoing("baka_forced", \
        akInitiator.GetDisplayName() + " gropes " + akTarget.GetDisplayName() + " between the legs; " + akTarget.GetDisplayName() + " struggles.", \
        akInitiator, akTarget)
    PlayPanicSound(akTarget)
    _StartTears(akTarget)

    ; No QTE — Play Privates just plays the loop, then releases (no knockdown).
    PlayPairedSimpleAnim(akInitiator, akTarget, \
        0.0, 0.0, 180.0, \
        "BaboPlayingPussyA2", "BaboPlayingPussyA1", \
        fTouchLoopDuration, False)
    _CueResistOutcome("baka_forced", akInitiator, akTarget)
    UnlockBoth(akInitiator, akTarget)
EndFunction

; --- OralOnTarget --- [FEMALE TARGET REQUIRED]
; A1=BaboSuckingPussyA01, A2=BaboSuckingPussyA02
Function OralOnTarget_Execute(Actor akInitiator, Actor akTarget)
    _Log("[SNBakaACT] OralOnTarget ENTER")
    If !IsEligible(akInitiator, akTarget)
        Return
    EndIf
    If !HasFemaleBody(akTarget)
        Return
    EndIf
    If !LockBoth(akInitiator, akTarget)
        Return
    EndIf
    RecordAnimation(akInitiator, "OralOnTarget", akTarget.GetDisplayName())
    RecordAnimation(akTarget,    "OralOnTarget", akInitiator.GetDisplayName())
    _CueOngoing("baka_forced", \
        akInitiator.GetDisplayName() + " forces oral on " + akTarget.GetDisplayName() + "; " + akTarget.GetDisplayName() + " struggles.", \
        akInitiator, akTarget)

    _StartTears(akTarget)
    PlayPairedSimpleAnim(akInitiator, akTarget, \
        0.0, 0.0, 180.0, \
        "BaboSuckingPussyA02", "BaboSuckingPussyA01", \
        fTouchLoopDuration)

    _CueOutcome("baka_forced", \
        akInitiator.GetDisplayName() + " forced oral on " + akTarget.GetDisplayName() + ".", \
        akInitiator, akTarget)
    UnlockBoth(akInitiator, akTarget)
EndFunction

; --- Spanking ---
; A1=BaboSpankingM, A2=BaboSpankingF
; Works on any gender combination.
Function Spanking_Execute(Actor akInitiator, Actor akTarget)
    _Log("[SNBakaACT] Spanking ENTER")
    If IsInSexAnimation(akInitiator) || IsInSexAnimation(akTarget)
        SpankTarget_Execute(akInitiator, akTarget, True)
        Return
    EndIf
    If !IsEligible(akInitiator, akTarget)
        Return
    EndIf
    If !LockBoth(akInitiator, akTarget)
        Return
    EndIf
    RecordAnimation(akInitiator, "Spanking", akTarget.GetDisplayName())
    RecordAnimation(akTarget,    "Spanking", akInitiator.GetDisplayName())
    _CueOngoing("baka_forced", \
        akInitiator.GetDisplayName() + " spanks " + akTarget.GetDisplayName() + ".", \
        akInitiator, akTarget)
    ; No slap here — the Babo spanking anim plays its own impact, so ours would
    ; double it.  abMoanAtMid=True plays the MOAN ~halfway through (near the impact).
    PlayPairedSimpleAnim(akInitiator, akTarget, \
        0.0, 0.0, 0.0, \
        "BaboSpankingM", "BaboSpankingF", \
        1.0, False, False, True)

    ApplySpankMark(akTarget)
    ApplyFaceMarks(akTarget)
    _StartTears(akTarget)

    _CueOutcome("baka_forced", \
        akInitiator.GetDisplayName() + " spanked " + akTarget.GetDisplayName() + ".", \
        akInitiator, akTarget)
    UnlockBoth(akInitiator, akTarget)
EndFunction

; --- WombHit --- [bResistable]
; A1=BaboWombHitM (single shot), A2=BaboWombHit (start) + BaboWombHitLoop
; Works on any gender combination.
Function WombHit_Execute(Actor akInitiator, Actor akTarget)
    _Log("[SNBakaACT] WombHit ENTER")
    If !IsEligible(akInitiator, akTarget)
        Return
    EndIf
    If !LockBoth(akInitiator, akTarget)
        Return
    EndIf
    RecordAnimation(akInitiator, "WombHit", akTarget.GetDisplayName())
    RecordAnimation(akTarget,    "WombHit", akInitiator.GetDisplayName())
    _CueOngoing("baka_forced", \
        akInitiator.GetDisplayName() + " punches " + akTarget.GetDisplayName() + " in the gut, dropping them.", \
        akInitiator, akTarget)
    _StartTears(akTarget)
    ; _bQTEDefeated=True so _CleanupPair (inside PlayPairedLoopAnim) skips standing the victim
    ; back up — otherwise the womb-hit victim won't stay down for _DefeatGroundWindow/_Bleedout.
    _bQTEDefeated = True
    ; Sound plays at impact moment (when loop phase starts), not before wind-up.
    PlayPairedLoopAnim(akInitiator, akTarget, \
        0.0, 0.0, 180.0, \
        "BaboWombHitM", "BaboWombHit", \
        "BaboWombHitM", "BaboWombHitLoop", \
        1.0, 0.5, False, \
        "Babo_DefeatResist_A1_S1", "Babo_DefeatResist_A2_S1", \
        "Babo_DefeatResist_A1_S2", "Babo_DefeatResist_A2_S2", \
        akTarget)

    _bQTEDefeated = False
    _UnlockAttackerOnly(akInitiator)
    _DefeatGroundWindow(akInitiator, akTarget)
EndFunction

; --- Flirt ---
; A1=Babo_Flirt_A02/A02D (performer — the one flirting), A2=Babo_Flirt_A01 (observer)
; Works on any gender combination.
Function Flirt_Execute(Actor akInitiator, Actor akTarget)
    _Log("[SNBakaACT] Flirt ENTER")
    If !IsEligible(akInitiator, akTarget)
        Return
    EndIf
    If !LockBoth(akInitiator, akTarget)
        Return
    EndIf
    RecordAnimation(akInitiator, "Flirt", akTarget.GetDisplayName())
    RecordAnimation(akTarget,    "Flirt", akInitiator.GetDisplayName())
    _ClearTearsForAffection(akInitiator, akTarget)
    _CueOngoing("baka_intimate", \
        akInitiator.GetDisplayName() + " flirts with " + akTarget.GetDisplayName() + ".", \
        akInitiator, akTarget)

    String[] a1 = new String[2]
    String[] a2 = new String[2]
    a1[0] = "Babo_Flirt_A02D"
    a1[1] = "Babo_Flirt_A02"
    a2[0] = "Babo_Flirt_A01"
    a2[1] = "Babo_Flirt_A01"

    ; X axis = front-to-back for this anim family (its baked root rotation makes marker-X read as
    ; forward). Negative pulls the flirted partner up to match the performer's arm. The player path
    ; (anchorOnPlayer) already looked right, so it keeps its own value (fFlirtSep_PC, default 0).
    Float xFlirt = fFlirtSep_NPC
    If akInitiator == PlayerRef || akTarget == PlayerRef
        xFlirt = fFlirtSep_PC
    EndIf
    PlayPairedSequence(akInitiator, akTarget, 0.0, 0.0, 0.0, a1, a2, fTouchLoopDuration)
    ; Mark that this actor flirted — unlocks the flirt escalations (face/breast/pussy) for a while.
    StorageUtil.SetFloatValue(akInitiator, "SNBaka.LastFlirt", Utility.GetCurrentGameTime())

    _CueOutcome("baka_intimate", \
        akInitiator.GetDisplayName() + " flirted with " + akTarget.GetDisplayName() + ".", \
        akInitiator, akTarget)
    UnlockBoth(akInitiator, akTarget)
EndFunction

; ── Flirt escalations ────────────────────────────────────────────────────────
; Unlocked only AFTER a base Flirt (gated by the baka_flirted decorator on the speaker).
; The speaker is the active toucher (A01); the target is touched (A02); face-to-face (rot 180).
String Function GetFlirted(Actor akActor)
    If !akActor
        Return "false"
    EndIf
    Float last = StorageUtil.GetFloatValue(akActor, "SNBaka.LastFlirt", 0.0)
    ; ~2 game-hours window so the escalation stays available through the conversation.
    If last > 0.0 && (Utility.GetCurrentGameTime() - last) < 0.0833
        Return "true"
    EndIf
    Return "false"
EndFunction

Function _FlirtEscalate(Actor akInitiator, Actor akTarget, String animA1, String animA2, String what, Float rotOffset = 180.0)
    If !IsEligible(akInitiator, akTarget)
        Return
    EndIf
    If !LockBoth(akInitiator, akTarget)
        Return
    EndIf
    RecordAnimation(akInitiator, "Flirt", akTarget.GetDisplayName())
    _CueOngoing("baka_intimate", \
        akInitiator.GetDisplayName() + " " + what + " " + akTarget.GetDisplayName() + ".", \
        akInitiator, akTarget)
    _ClearTearsForAffection(akInitiator, akTarget)
    ; animA1 is played by the INITIATOR (the toucher); pass the toucher-role anim there.
    PlayPairedSimpleAnim(akInitiator, akTarget, 0.0, 0.0, rotOffset, animA1, animA2, fTouchLoopDuration)
    ; Keep the escalation window alive so the chain can continue.
    StorageUtil.SetFloatValue(akInitiator, "SNBaka.LastFlirt", Utility.GetCurrentGameTime())
    _CueOutcome("baka_intimate", \
        akInitiator.GetDisplayName() + " and " + akTarget.GetDisplayName() + " shared a charged, intimate moment.", \
        akInitiator, akTarget)
    UnlockBoth(akInitiator, akTarget)
EndFunction

; Initiator plays the _A02 (toucher) role; target plays _A01. Caress = face-to-face (rot 180);
; tease breasts/below = same direction (rot 0), with the initiator behind for "below".
Function FlirtFace_Execute(Actor akInitiator, Actor akTarget)
    _Log("[SNBakaACT] FlirtFace ENTER")
    _FlirtEscalate(akInitiator, akTarget, "Babo_FlirtFace_A02", "Babo_FlirtFace_A01", "tenderly caresses the face of", 180.0)
EndFunction

Function FlirtBreast_Execute(Actor akInitiator, Actor akTarget)
    _Log("[SNBakaACT] FlirtBreast ENTER")
    _FlirtEscalate(akInitiator, akTarget, "Babo_FlirtBreast_A02", "Babo_FlirtBreast_A01", "playfully fondles the breasts of", 0.0)
EndFunction

Function FlirtPussy_Execute(Actor akInitiator, Actor akTarget)
    _Log("[SNBakaACT] FlirtPussy ENTER")
    _FlirtEscalate(akInitiator, akTarget, "Babo_FlirtPussy_A02", "Babo_FlirtPussy_A01", "slips a hand between the legs of", 0.0)
EndFunction

; Stops the LLM from looping "inspect" forever on a downed victim. Returns False if the inspect
; should be SKIPPED (already inspected enough this down) — and nudges the aggressor to do something
; else. When it proceeds on a downed victim it bumps the count AND keeps their down-timer alive
; (so they stay protected while real interactions happen).
Bool Function _InspectGuard(Actor akInitiator, Actor akTarget)
    If !_IsDownedAny(akTarget)
        Return True
    EndIf
    Int ic = StorageUtil.GetIntValue(akTarget, "SNBaka.InspectCount", 0)
    If ic >= 2
        SkyrimNetApi.RegisterEvent("baka_forced", \
            akInitiator.GetDisplayName() + " has already looked " + akTarget.GetDisplayName() + " over thoroughly — there is nothing more to learn from inspecting again. Time to escalate, take what is wanted, or move on.", \
            akInitiator, akTarget)
        _Log("[SNBaka] _InspectGuard: inspect loop capped on " + akTarget.GetDisplayName())
        Return False
    EndIf
    StorageUtil.SetIntValue(akTarget, "SNBaka.InspectCount", ic + 1)
    _bResetDownWindow = True
    Return True
EndFunction

; --- CapturedInspect --- [FEMALE TARGET REQUIRED] [bResistable]
; Sequence includes CapturedBoob and CapturedPussy stages — requires female A2.
Function CapturedInspect_Execute(Actor akInitiator, Actor akTarget)
    _Log("[SNBakaACT] CapturedInspect ENTER")
    If !IsEligible(akInitiator, akTarget)
        Return
    EndIf
    If !HasFemaleBody(akTarget)
        Return
    EndIf
    If !_InspectGuard(akInitiator, akTarget)
        Return
    EndIf
    If !LockBoth(akInitiator, akTarget)
        Return
    EndIf
    RecordAnimation(akInitiator, "CapturedInspect", akTarget.GetDisplayName())
    RecordAnimation(akTarget,    "CapturedInspect", akInitiator.GetDisplayName())
    _CueOngoing("baka_forced", \
        akInitiator.GetDisplayName() + " inspects captured " + akTarget.GetDisplayName() + "'s body; " + akTarget.GetDisplayName() + " struggles.", \
        akInitiator, akTarget)
    PlayPanicSound(akTarget)
    _StartTears(akTarget)

    String[] a1 = new String[3]
    String[] a2 = new String[3]
    a1[0] = "Babo_Captured_A2"
    a1[1] = "Babo_CapturedBoob_A2"
    a1[2] = "Babo_CapturedPussy_A2"
    a2[0] = "Babo_Captured_A1"
    a2[1] = "Babo_CapturedBoob_A1"
    a2[2] = "Babo_CapturedPussy_A1"

    ; No QTE and no knockdown from the menu — play the sequence through, then release.
    ; (The downed-victim re-down version is _DownedReplay, used by the second menu.)
    PlayPairedSequence(akInitiator, akTarget, 0.0, 0.0, 180.0, a1, a2, fSequenceStageTimer, False)
    _CueResistOutcome("baka_forced", akInitiator, akTarget)
    UnlockBoth(akInitiator, akTarget)
EndFunction

; --- Investigate --- [FEMALE TARGET REQUIRED] [bResistable]
; Thorough 3-stage inspection — requires female A2.
Function Investigate_Execute(Actor akInitiator, Actor akTarget)
    _Log("[SNBakaACT] Investigate ENTER")
    If !IsEligible(akInitiator, akTarget)
        Return
    EndIf
    If !HasFemaleBody(akTarget)
        Return
    EndIf
    If !_InspectGuard(akInitiator, akTarget)
        Return
    EndIf
    If !LockBoth(akInitiator, akTarget)
        Return
    EndIf
    RecordAnimation(akInitiator, "Investigate", akTarget.GetDisplayName())
    RecordAnimation(akTarget,    "Investigate", akInitiator.GetDisplayName())
    _CueOngoing("baka_forced", \
        akInitiator.GetDisplayName() + " inspects " + akTarget.GetDisplayName() + "'s body; " + akTarget.GetDisplayName() + " struggles.", \
        akInitiator, akTarget)
    PlayPanicSound(akTarget)
    _StartTears(akTarget)

    String[] a1 = new String[3]
    String[] a2 = new String[3]
    a1[0] = "Babo_Investigation_S01_A02"
    a1[1] = "Babo_Investigation_S02_A02"
    a1[2] = "Babo_Investigation_S03_A02"
    a2[0] = "Babo_Investigation_S01_A01"
    a2[1] = "Babo_Investigation_S02_A01"
    a2[2] = "Babo_Investigation_S03_A01"

    ; No QTE and no knockdown from the menu — play the sequence through, then release.
    ; (The downed-victim re-down version is _DownedReplay, used by the second menu.)
    ; Investigation stage 0 is authored with the aggressor turned 180; force only akA1 flipped
    ; on stage 0 (afA1Stage0Rot=180), restored from stage 1 on. Stages 2-3 already look right.
    PlayPairedSequence(akInitiator, akTarget, 0.0, 0.0, 180.0, a1, a2, fSequenceStageTimer, False, True, 180.0)
    _CueResistOutcome("baka_forced", akInitiator, akTarget)
    UnlockBoth(akInitiator, akTarget)
EndFunction

; --- Struggle --- [bResistable]
; 5-stage grapple. Works on any gender combination.
; abFromHit: set ONLY by the on-hit mid-combat path (OnCreatureHitFollower's humanoid branch) --
; relaxes IsEligible's attacker-in-combat gate for exactly that call, since a struggle triggered BY a
; combat hit is mid-combat by definition. LLM/YAML invocations (down_pin/struggle actions) call with
; two args, so the default keeps their behavior unchanged.
Function Struggle_Execute(Actor akInitiator, Actor akTarget, Bool abFromHit = False)
    _Log("[SNBakaACT] Struggle ENTER")
    If !IsEligible(akInitiator, akTarget, abFromHit)
        Return
    EndIf
    If !LockBoth(akInitiator, akTarget)
        Return
    EndIf
    RecordAnimation(akInitiator, "Struggle", akTarget.GetDisplayName())
    RecordAnimation(akTarget,    "Struggle", akInitiator.GetDisplayName())
    _CueOngoing("baka_forced", \
        akInitiator.GetDisplayName() + " grapples " + akTarget.GetDisplayName() + " to overpower them; " + akTarget.GetDisplayName() + " fights back.", \
        akInitiator, akTarget)
    _StartTears(akTarget)
    If bExpressionsEnabled
        _ApplyMoodExpression(akTarget, "afraid")
    EndIf

    String[] a1 = new String[5]
    String[] a2 = new String[5]
    a1[0] = "Babo_Struggle_S01_A02"
    a1[1] = "Babo_Struggle_S02_A02"
    a1[2] = "Babo_Struggle_S03_A02"
    a1[3] = "Babo_Struggle_S04_A02"
    a1[4] = "Babo_Struggle_S05_A02"
    a2[0] = "Babo_Struggle_S01_A01"
    a2[1] = "Babo_Struggle_S02_A01"
    a2[2] = "Babo_Struggle_S03_A01"
    a2[3] = "Babo_Struggle_S04_A01"
    a2[4] = "Babo_Struggle_S05_A01"

    ; New convention: the victim sits FRONT-LEFT of the attacker. fStruggleSep_* = how far in FRONT
    ; (yLocal +), fStruggleLeft = how far to the LEFT (xLocal -). Co-located is 0,0; tune from the
    ; "[Baka] Sequence ...: victim vs attacker(0,0,0) = L.. F.." log line.
    Float yFront = fStruggleSep_NPC
    If akInitiator == PlayerRef            ; player is the attacker
        yFront = fStruggleSep_PCAtk
    ElseIf akTarget == PlayerRef           ; player is the victim
        yFront = fStruggleSep_PCVic
    EndIf
    PlayPairedSequence(akInitiator, akTarget, fStruggleLeft, yFront, 0.0, a1, a2, fSequenceStageTimer, True)

    If _bQTEDefeated
        _Log("[SNBaka] Execute: QTE defeated — calling DefeatGroundWindow. attacker=" + akInitiator.GetDisplayName() + " victim=" + akTarget.GetDisplayName())
        _bQTEDefeated = False
        _UnlockAttackerOnly(akInitiator)
        _DefeatGroundWindow(akInitiator, akTarget)
    Else
        If !_bAELVictimEscaped
            _Log("[SNBaka] struggle outcome: attacker won the exchange (not a fresh QTE-defeat) — _RecoveryPeriod on " + akTarget)
            _RecoveryPeriod(akTarget, akInitiator, 10.0)
        ElseIf _IsDownedAny(akTarget)
            ; Three ways up, full stop: HelpUp, nobody around, or winning the QTE. This is #3 — the
            ; victim beat a PinHelpless/ChokeHelpless attempt made against them while already downed, so
            ; they're up, period. _ForceRecover clears the hold AND stands them up; _CleanupPair (already
            ; run by PlayPairedSequence) separately restores the attacker's normal aggression/AI, which is
            ; correct here since the victim is genuinely no longer downed — the fight can resume for real.
            _Log("[SNBaka] struggle outcome: victim escaped AND was already downed — _ForceRecover (condition #3) on " + akTarget)
            _ForceRecover(akTarget)
        Else
            _Log("[SNBaka] struggle outcome: victim escaped, was not downed to begin with — no recovery action needed")
        EndIf
        _CueResistOutcome("baka_forced", akInitiator, akTarget)
        If bExpressionsEnabled
            _ClearExpression(akTarget)
        EndIf
        UnlockBoth(akInitiator, akTarget)
    EndIf
EndFunction

; --- ChokeHug --- [bResistable]
; 5-stage chokehold. Works on any gender combination.
Function ChokeHug_Execute(Actor akInitiator, Actor akTarget)
    _Log("[SNBakaACT] ChokeHug ENTER")
    If !IsEligible(akInitiator, akTarget)
        Return
    EndIf
    If !LockBoth(akInitiator, akTarget)
        Return
    EndIf
    RecordAnimation(akInitiator, "ChokeHug", akTarget.GetDisplayName())
    RecordAnimation(akTarget,    "ChokeHug", akInitiator.GetDisplayName())
    _CueOngoing("baka_forced", \
        akInitiator.GetDisplayName() + " chokes " + akTarget.GetDisplayName() + " from behind; " + akTarget.GetDisplayName() + " fights back.", \
        akInitiator, akTarget)
    PlayPanicSound(akTarget)
    _StartTears(akTarget)
    If bExpressionsEnabled
        _ApplyMoodExpression(akTarget, "pained")
    EndIf

    String[] a1 = new String[5]
    String[] a2 = new String[5]
    a1[0] = "Babo_ChokeHug_S01_A02"
    a1[1] = "Babo_ChokeHug_S02_A02"
    a1[2] = "Babo_ChokeHug_S03_A02"
    a1[3] = "Babo_ChokeHug_S04_A02"
    a1[4] = "Babo_ChokeHug_S05_A02"
    a2[0] = "Babo_ChokeHug_S01_A01"
    a2[1] = "Babo_ChokeHug_S02_A01"
    a2[2] = "Babo_ChokeHug_S03_A01"
    a2[3] = "Babo_ChokeHug_S04_A01"
    a2[4] = "Babo_ChokeHug_S05_A01"

    ; ChokeHug action ONLY (not the escalate-defeat choke in _DoEscalation). xLocal=0 (no lateral
    ; shift — that put the attacker off to the side); the choke anim seats the attacker directly
    ; behind the victim. NPC-NPC self-seats ~15 apart (offset 0); when the player is the victim it
    ; reads too close, so push the attacker further back. See POSITIONING TUNING block at top.
    Float yChoke = fChokeHugSep_NPC
    If akTarget == PlayerRef
        yChoke = fChokeHugSep_PCVic
    EndIf
    PlayPairedSequence(akInitiator, akTarget, 0.0, 0.0, 0.0, a1, a2, fSequenceStageTimer, True)

    If _bQTEDefeated
        _Log("[SNBaka] Execute: QTE defeated — calling DefeatGroundWindow. attacker=" + akInitiator.GetDisplayName() + " victim=" + akTarget.GetDisplayName())
        _bQTEDefeated = False
        _UnlockAttackerOnly(akInitiator)
        ; Choke knocks the victim out — female victims faint (BaboFaintF). No male faint anim exists,
        ; so males fall through to the default trauma down-pose.
        ActorBase _tb = akTarget.GetActorBase()
        If _tb && _tb.GetSex() == 1
            _sDownPose = "BaboFaintF"
        EndIf
        _DefeatGroundWindow(akInitiator, akTarget)
    Else
        If !_bAELVictimEscaped
            _Log("[SNBaka] struggle outcome: attacker won the exchange (not a fresh QTE-defeat) — _RecoveryPeriod on " + akTarget)
            _RecoveryPeriod(akTarget, akInitiator, 10.0)
        ElseIf _IsDownedAny(akTarget)
            ; Three ways up, full stop: HelpUp, nobody around, or winning the QTE. This is #3 — the
            ; victim beat a PinHelpless/ChokeHelpless attempt made against them while already downed, so
            ; they're up, period. _ForceRecover clears the hold AND stands them up; _CleanupPair (already
            ; run by PlayPairedSequence) separately restores the attacker's normal aggression/AI, which is
            ; correct here since the victim is genuinely no longer downed — the fight can resume for real.
            _Log("[SNBaka] struggle outcome: victim escaped AND was already downed — _ForceRecover (condition #3) on " + akTarget)
            _ForceRecover(akTarget)
        Else
            _Log("[SNBaka] struggle outcome: victim escaped, was not downed to begin with — no recovery action needed")
        EndIf
        _CueResistOutcome("baka_forced", akInitiator, akTarget)
        If bExpressionsEnabled
            _ClearExpression(akTarget)
        EndIf
        UnlockBoth(akInitiator, akTarget)
    EndIf
EndFunction

; --- DrunkExploit --- [bResistable]
; 5-stage. S05 = liberation (star pattern). Attacker behind victim, same facing direction.
; Works on any gender combination.
Function DrunkExploit_Execute(Actor akInitiator, Actor akTarget)
    _Log("[SNBakaACT] DrunkExploit ENTER")
    If !IsEligible(akInitiator, akTarget)
        Return
    EndIf
    If !LockBoth(akInitiator, akTarget)
        Return
    EndIf
    RecordAnimation(akInitiator, "DrunkExploit", akTarget.GetDisplayName())
    RecordAnimation(akTarget,    "DrunkExploit", akInitiator.GetDisplayName())
    _CueOngoing("baka_forced", \
        akInitiator.GetDisplayName() + " gropes " + akTarget.GetDisplayName() + ", drunk and defenseless.", \
        akInitiator, akTarget)

    String[] a1 = new String[5]
    String[] a2 = new String[5]
    a1[0] = "Babo_Drunk_S01_A02"
    a1[1] = "Babo_Drunk_S02_A02"
    a1[2] = "Babo_Drunk_S03_A02"
    a1[3] = "Babo_Drunk_S04_A02"
    a1[4] = "Babo_Drunk_S05_A02"
    a2[0] = "Babo_Drunk_S01_A01"
    a2[1] = "Babo_Drunk_S02_A01"
    a2[2] = "Babo_Drunk_S03_A01"
    a2[3] = "Babo_Drunk_S04_A01"
    a2[4] = "Babo_Drunk_S05_A01"

    ; Resistable (bResistable=True): the final Drunk stage is the victim shaking off the stupor
    ; and breaking away. Attacker wins -> victim collapses (DefeatGroundWindow). Victim "escapes"
    ; -> break-free stage plays and they recover. Player path = QTE; NPC-NPC = random outcome.
    ; Player-as-attacker sits ~1 unit too high in this anim — drop the player's pin-marker 1 more.
    If akInitiator == PlayerRef
        _fPlayerZAdjust = -1.0
    EndIf
    PlayPairedSequence(akInitiator, akTarget, 0.0, 0.0, 0.0, a1, a2, fSequenceStageTimer, True)   ; co-located base; tune from the [Baka] log
    _fPlayerZAdjust = 0.0
    If _bQTEDefeated
        _bQTEDefeated = False
        _UnlockAttackerOnly(akInitiator)
        _DefeatGroundWindow(akInitiator, akTarget)
    Else
        If !_bAELVictimEscaped
            _RecoveryPeriod(akTarget, akInitiator, 8.0)
        EndIf
        _CueResistOutcome("baka_forced", akInitiator, akTarget)
        UnlockBoth(akInitiator, akTarget)   ; <-- was missing: left the power soft-locked on a drunk-exploit escape
    EndIf
EndFunction

; --- DrugFood ---
; A1=Babo_DruggedFoodConsumptionM (the one administering the drugged food),
; A2=Babo_DruggedFoodConsumptionF (the one consuming it).
; No QTE — the drug does the work. Victim collapses into a full ground window identical
; to a QTE defeat, giving the initiator the escalation window with unconscious-victim
; context passed to SkyrimNet and SexLab.
; Works on any gender combination.
Function DrugFood_Execute(Actor akInitiator, Actor akTarget)
    _Log("[SNBakaACT] DrugFood ENTER")
    If !IsEligible(akInitiator, akTarget)
        Return
    EndIf
    If !LockBoth(akInitiator, akTarget)
        Return
    EndIf
    RecordAnimation(akInitiator, "DrugFood", akTarget.GetDisplayName())
    RecordAnimation(akTarget,    "DrugFood", akInitiator.GetDisplayName())
    _CueOngoing("baka_forced", \
        akInitiator.GetDisplayName() + " offers " + akTarget.GetDisplayName() + " food secretly spiked with something.", \
        akInitiator, akTarget)

    ; _bQTEDefeated=True so _CleanupPair skips standing the victim up + re-evaluating their
    ; AI — without it the AI recovers and the bleedout never sticks (the reported bug).
    _bQTEDefeated = True
    PlayPairedSimpleAnim(akInitiator, akTarget, \
        0.0, 0.0, 0.0, \
        "Babo_DruggedFoodConsumptionM", "Babo_DruggedFoodConsumptionF", \
        fMolestLoopDuration)
    _bQTEDefeated = False

    ; Animation done — victim collapses unconscious. No QTE; the drug does the work.
    ; Set flag so _DefeatGroundWindow and _DoEscalation use unconscious-victim context.
    _Log("[SNBaka] DrugFood_Execute: animation complete — collapsing victim into ground window (drugged)")
    _bDruggedEscalation = True
    _UnlockAttackerOnly(akInitiator)
    _DefeatGroundWindow(akInitiator, akTarget)
EndFunction

; --- ShowingOffBody ---
; A1=BaboShowingOffBodyA2 (the one being shown off / posed), A2=BaboShowingOffBodyA1 (observer).
; Inverted naming: A1 role plays the A2 animation, A2 role plays the A1 animation.
; No body-sex gate — Baka uses role-based A1/A2 naming so any character can perform the pose.
; (HasFemaleBody on the player is unreliable with RaceMenu presets — male base, female appearance.)
Function ShowingOffBody_Execute(Actor akInitiator, Actor akTarget)
    _Log("[SNBakaACT] ShowingOffBody ENTER")
    If !IsEligible(akInitiator, akTarget)
        Return
    EndIf
    If !LockBoth(akInitiator, akTarget)
        Return
    EndIf
    RecordAnimation(akInitiator, "ShowingOffBody", akTarget.GetDisplayName())
    RecordAnimation(akTarget,    "ShowingOffBody", akInitiator.GetDisplayName())
    _CueOngoing("baka_intimate", \
        akInitiator.GetDisplayName() + " shows off their body to " + akTarget.GetDisplayName() + ".", \
        akInitiator, akTarget)

    _ClearTearsForAffection(akInitiator, akTarget)
    PlayPairedSimpleAnim(akInitiator, akTarget, \
        0.0, 0.0, 180.0, \
        "BaboShowingOffBodyA2", "BaboShowingOffBodyA1", \
        fMolestLoopDuration)

    _CueOutcome("baka_intimate", \
        akInitiator.GetDisplayName() + " showed off their body to " + akTarget.GetDisplayName() + ".", \
        akInitiator, akTarget)
    UnlockBoth(akInitiator, akTarget)
EndFunction

; --- FondlePussy --- [FEMALE TARGET REQUIRED]
; A1=BaboPlayingPussyA2, A2=BaboPlayingPussyA1 (inverted naming).
; Non-resistable variant — used for consensual or subdued contexts.
; Use PlayPrivates_Execute for the resistable version.
Function FondlePussy_Execute(Actor akInitiator, Actor akTarget)
    _Log("[SNBakaACT] FondlePussy ENTER")
    If !IsEligible(akInitiator, akTarget)
        Return
    EndIf
    If !HasFemaleBody(akTarget)
        Return
    EndIf
    If !LockBoth(akInitiator, akTarget)
        Return
    EndIf
    RecordAnimation(akInitiator, "FondlePussy", akTarget.GetDisplayName())
    RecordAnimation(akTarget,    "FondlePussy", akInitiator.GetDisplayName())
    _CueOngoing("baka_forced", \
        akInitiator.GetDisplayName() + " fondles " + akTarget.GetDisplayName() + " between the legs; " + akTarget.GetDisplayName() + " struggles.", \
        akInitiator, akTarget)
    _StartTears(akTarget)

    ; Attacker directly behind the victim, in line (no lateral shift, same facing -> victim's
    ; back to the attacker). See POSITIONING TUNING block at top.
    Float yFondle = fFondleSep_NPC
    If akInitiator == PlayerRef || akTarget == PlayerRef
        yFondle = fFondleSep_PC
    EndIf
    PlayPairedSimpleAnim(akInitiator, akTarget, \
        0.0, 0.0, 180.0, \
        "BaboPlayingPussyA2", "BaboPlayingPussyA1", \
        fTouchLoopDuration)

    _CueOutcome("baka_forced", \
        akInitiator.GetDisplayName() + " fondled " + akTarget.GetDisplayName() + " between the legs.", \
        akInitiator, akTarget)
    UnlockBoth(akInitiator, akTarget)
EndFunction

; --- InterruptScene ---
; A guard, bystander, or player forces an ongoing Baka scene to stop.
; akTarget is any actor currently in an active animation (victim or initiator).
; If they are not in a scene, does nothing.
Function InterruptScene_Execute(Actor akIntervenor, Actor akTarget)
    _Log("[SNBakaACT] InterruptScene ENTER")
    If !akIntervenor || !akTarget
        Return
    EndIf
    If !IsActorLocked(akTarget)
        Return
    EndIf
    RequestStop(akTarget)
    SkyrimNetApi.RegisterEvent("baka_intervention", \
        akIntervenor.GetDisplayName() + " forces the scene involving " + akTarget.GetDisplayName() + " to stop.", \
        akIntervenor, akTarget)
EndFunction

; --- CallOff ---
; The scene initiator voluntarily ends their own ongoing animation.
; akInitiator must currently be locked (in an active animation).
Function CallOff_Execute(Actor akInitiator, Actor akTarget)
    _Log("[SNBakaACT] CallOff ENTER")
    If !akInitiator
        Return
    EndIf
    If !IsActorLocked(akInitiator)
        Return
    EndIf
    RequestStop(akInitiator)
    SkyrimNetApi.RegisterEvent("baka_calloff", \
        akInitiator.GetDisplayName() + " calls off the interaction with " + akTarget.GetDisplayName() + ".", \
        akInitiator, akTarget)
EndFunction

; --- Interact ---
; Called by SNBaka_InteractPower when player casts on an NPC.
; Two-level native message box — four top-level categories, each with a submenu.
; All button indices follow CK Message record button order (0-based, Cancel is last).
;
;   InteractMenuMain         : 0=Affectionate  1=Aggressive  2=Sexual  3=Devious  4=Cancel
;   InteractMenuAffectionate : 0=Back Hug  1=Front Hug  2=Kiss  3=Flirt  4=Cancel
;   InteractMenuAggressive   : 0=Grab Hold  1=Struggle  2=Choke  3=Womb Hit  4=Cancel
;   InteractMenuAggPhysical  : [Sexual submenu]   0=Forced Kiss  1=Spank  2=Touch Breasts  3=Examine  4=Cancel
;   InteractMenuAggSexual    : [Devious submenu]  0=Show Off Body  1=Drunk Exploit  2=Drug Food  3=Fondle  4=Cancel
;
;   CK records to update (button text only — FormIDs unchanged):
;     SNBaka_InteractMenuMain:       was 3 buttons, now 5: Affectionate/Aggressive/Sexual/Devious/Cancel
;     SNBaka_InteractMenuAggressive: was Physical/Sexual/Cancel, now: Grab Hold/Struggle/Choke/Womb Hit/Cancel
;     SNBaka_InteractMenuAggPhysical: relabel to Sexual actions: Forced Kiss/Spank/Touch Breasts/Examine/Cancel
;     SNBaka_InteractMenuAggSexual:   relabel to Devious actions: Show Off Body/Drunk Exploit/Drug Food/Fondle/Cancel
;     SNBaka_InteractMenuAffectionate: NO CHANGE
Function Interact_ShowMenu(Actor akTarget, Actor akCaster)
    If !akTarget || !akCaster
        Return
    EndIf

    ; If the target is downed — either by US (SNBaka.OnGround, from a QTE defeat/drug), by an external
    ; mod/cause (any bleedout, e.g. Surrender), or held purely by Acheron (SNAcheron.Held) — open the
    ; downed-victim menu instead of the normal interact menu. This must come before the IsActorLocked
    ; guard below.
    ; Always attempt the real menu now, unconditionally — this used to gate on SNBakaUI.IsAvailable()
    ; here in Papyrus first, silently auto-escalating instead whenever that read false even briefly
    ; (e.g. right after a save load, before the view finished recreating). ShowDownedMenu already does
    ; its own IsAvailable()+CreateMenuView() recovery internally on the C++ side — that retry never got
    ; a chance to run when the Papyrus-side pre-check alone decided to skip straight to auto-escalate.
    ; PrismaUI is a hard requirement for this mod now, so there's no real vanilla-fallback case left to
    ; preserve here.
    If _IsDownedAny(akTarget)
        _pendingCaster = akCaster
        _pendingTarget = akTarget
        SNBakaUI.ShowDownedMenu(akCaster, akTarget)
        Return
    EndIf

    If IsActorLocked(akCaster) || IsActorLocked(akTarget)
        _Log("[SNBaka] interact blocked: already in an interaction.")
        Return
    EndIf
    If _bCooldownActive
        _Log("[SNBaka] interact blocked: still on cooldown.")
        Return
    EndIf
    If !IsEligible(akCaster, akTarget)
        Return
    EndIf

    ; ── PrismaUI path (async) ────────────────────────────────────────────────
    If SNBakaUI.IsAvailable()
        _pendingTarget = akTarget
        _pendingCaster = akCaster
        ; Actors are passed into the DLL and handed straight back on dispatch,
        ; so _pending* is only a fallback — the menu being open (unpaused) can no
        ; longer leave us with the wrong actors.
        SNBakaUI.ShowInteractMenu(akCaster, akTarget)
        Return  ; result arrives via _DispatchInteractActionWithActors
    EndIf

    ; ── Vanilla fallback (synchronous) ───────────────────────────────────────
    ; Resolve menus fresh each call — VMAD properties may be zombie refs after ESL compaction.
    Message _mmMain    = Game.GetFormFromFile(0x00080A, "SkyrimNet_BakaIntegration.esp") as Message
    Message _mmAff     = Game.GetFormFromFile(0x00080B, "SkyrimNet_BakaIntegration.esp") as Message
    Message _mmAgg     = Game.GetFormFromFile(0x00080C, "SkyrimNet_BakaIntegration.esp") as Message
    Message _mmAggPhys = Game.GetFormFromFile(0x000803, "SkyrimNet_BakaIntegration.esp") as Message
    Message _mmAggSex  = Game.GetFormFromFile(0x000804, "SkyrimNet_BakaIntegration.esp") as Message
    If !_mmMain
        _Log("[SNBaka] ERROR: InteractMenuMain not found at 0x00080A - ESL FormID mismatch?")
        Return
    EndIf

    Int choice = _mmMain.Show()

    ; 0 = Affectionate
    If choice == 0 && _mmAff
        Int sub = _mmAff.Show()
        If sub == 0
            BackHug_Execute(akCaster, akTarget)
        ElseIf sub == 1
            FrontHug_Execute(akCaster, akTarget)
        ElseIf sub == 2
            KissLove_Execute(akCaster, akTarget)
        ElseIf sub == 3
            Flirt_Execute(akCaster, akTarget)
        EndIf

    ; 1 = Aggressive
    ElseIf choice == 1 && _mmAgg
        Int sub = _mmAgg.Show()
        If sub == 0
            BackHugMolest_Execute(akCaster, akTarget)
        ElseIf sub == 1
            Struggle_Execute(akCaster, akTarget)
        ElseIf sub == 2
            ChokeHug_Execute(akCaster, akTarget)
        ElseIf sub == 3
            WombHit_Execute(akCaster, akTarget)
        EndIf

    ; 2 = Sexual (uses InteractMenuAggPhysical record — relabelled in CK)
    ElseIf choice == 2 && _mmAggPhys
        Int sub = _mmAggPhys.Show()
        If sub == 0
            ForcedKiss_Execute(akCaster, akTarget)
        ElseIf sub == 1
            Spanking_Execute(akCaster, akTarget)
        ElseIf sub == 2
            TouchBreasts_Execute(akCaster, akTarget)
        ElseIf sub == 3
            ExaminePrivates_Execute(akCaster, akTarget)
        EndIf

    ; 3 = Devious (uses InteractMenuAggSexual record — relabelled in CK)
    ElseIf choice == 3 && _mmAggSex
        Int sub = _mmAggSex.Show()
        If sub == 0
            ShowingOffBody_Execute(akCaster, akTarget)
        ElseIf sub == 1
            DrunkExploit_Execute(akCaster, akTarget)
        ElseIf sub == 2
            DrugFood_Execute(akCaster, akTarget)
        ElseIf sub == 3
            FondlePussy_Execute(akCaster, akTarget)
        EndIf
    EndIf
EndFunction


; ── PrismaUI async dispatch ──────────────────────────────────────────────────

Event OnSNBakaMenuChoice(String eventName, String strArg, Float numArg, Form sender)
    Int choice = numArg as Int
    If strArg == "sexspank"
        _DispatchSexSpankAction(choice)
    Else
        _DispatchInteractAction(choice)
    EndIf
EndEvent

; Called by SkyrimNet_BakaIntegration.dll with the actors captured when the menu opened.
; Sets _pending* and runs the normal dispatch synchronously — no open-menu gap
; for the values to be clobbered in.
Function _DispatchInteractActionWithActors(Int choice, Actor cst, Actor tgt)
    _pendingCaster = cst
    _pendingTarget = tgt
    _DispatchInteractAction(choice)
EndFunction

Function _DispatchInteractAction(Int choice)
    Actor tgt = _pendingTarget
    Actor cst = _pendingCaster
    _pendingTarget = None
    _pendingCaster = None
    If choice < 0 || !tgt || !cst
        Return
    EndIf
    If choice == 0
        BackHug_Execute(cst, tgt)
    ElseIf choice == 1
        FrontHug_Execute(cst, tgt)
    ElseIf choice == 2
        KissLove_Execute(cst, tgt)
    ElseIf choice == 3
        Flirt_Execute(cst, tgt)
    ElseIf choice == 4
        BackHugMolest_Execute(cst, tgt)
    ElseIf choice == 5
        Struggle_Execute(cst, tgt)
    ElseIf choice == 6
        ChokeHug_Execute(cst, tgt)
    ElseIf choice == 7
        WombHit_Execute(cst, tgt)
    ElseIf choice == 8
        ForcedKiss_Execute(cst, tgt)
    ElseIf choice == 9
        Spanking_Execute(cst, tgt)
    ElseIf choice == 10
        TouchBreasts_Execute(cst, tgt)
    ElseIf choice == 11
        ExaminePrivates_Execute(cst, tgt)
    ElseIf choice == 12
        ShowingOffBody_Execute(cst, tgt)
    ElseIf choice == 13
        DrunkExploit_Execute(cst, tgt)
    ElseIf choice == 14
        DrugFood_Execute(cst, tgt)
    ElseIf choice == 15
        FondlePussy_Execute(cst, tgt)
    ; --- new player-accessible NPC actions (no QTE) ---
    ElseIf choice == 16
        FlirtFace_Execute(cst, tgt)        ; Caress Face
    ElseIf choice == 17
        FlirtBreast_Execute(cst, tgt)      ; Tease Breasts
    ElseIf choice == 18
        FlirtPussy_Execute(cst, tgt)       ; Tease Below
    ElseIf choice == 19
        SuckBreasts_Execute(cst, tgt)      ; Suck Breasts
    ElseIf choice == 20
        OralOnTarget_Execute(cst, tgt)     ; Suck Privates
    ElseIf choice == 21
        PlayPrivates_Execute(cst, tgt)     ; Play Privates
    ElseIf choice == 22
        Investigate_Execute(cst, tgt)      ; Investigate
    ElseIf choice == 23
        CapturedInspect_Execute(cst, tgt)  ; Inspect (captured)
    ElseIf choice == 24
        ArmHold_Execute(cst, tgt)          ; Arm Hold (affectionate)
    EndIf
EndFunction

Function _DispatchSexSpankAction(Int choice)
    Actor caster = _pendingSexCaster
    Actor npc0   = _pendingSexNPC0
    Actor npc1   = _pendingSexNPC1
    Actor npc2   = _pendingSexNPC2
    _pendingSexCaster = None
    _pendingSexNPC0 = None
    _pendingSexNPC1 = None
    _pendingSexNPC2 = None
    If choice < 0 || !caster
        Return
    EndIf
    If choice == 0 && npc0
        _SexSpank_Execute(caster, npc0)
    ElseIf choice == 1 && npc1
        _SexSpank_Execute(caster, npc1)
    ElseIf choice == 2 && npc2
        _SexSpank_Execute(caster, npc2)
    ElseIf choice == 10 && npc0
        _SexSpank_Execute(npc0, PlayerRef)
    ElseIf choice == 11 && npc1
        _SexSpank_Execute(npc1, PlayerRef)
    ElseIf choice == 12 && npc2
        _SexSpank_Execute(npc2, PlayerRef)
    ElseIf choice == 13
        _SexSpank_Execute(PlayerRef, PlayerRef)
    EndIf
EndFunction

; --- Release ---
; Called during the ground window to free the downed victim immediately without escalating.
; The attacker steps back — the moment passes. Works for both NPC and player initiators.
Function Release_Execute(Actor akInitiator, Actor akTarget)
    _Log("[SNBakaACT] Release ENTER")
    If !akTarget || !akInitiator
        Return
    EndIf
    If _IsCreatureActor(akInitiator) || _IsCreatureActor(akTarget)
        _Log("[SNBaka] Release_Execute: blocked — creature actor (use CreatureEscalate)")
        Return
    EndIf
    If _IsDownedAny(akInitiator)
        _Log("[SNBaka] Release_Execute: blocked — initiator is downed")
        Return
    EndIf
    Bool ours = StorageUtil.GetIntValue(akTarget, "SNBaka.OnGround", 0) == 1
    Bool external = !ours && _IsDownedAny(akTarget)
    If !ours && !external
        Return
    EndIf
    _bReleaseRequested = True
    _Log("[SNBaka] Release_Execute: " + akInitiator.GetDisplayName() + " releases " + akTarget.GetDisplayName())
    ; If they were defeated by something other than our ground window (Acheron combat bleedout), free
    ; them directly — the ground-window flag alone won't be read by anyone.
    If external
        _ForceRecover(akTarget)
    EndIf
    SkyrimNetApi.RegisterEvent("baka_release", \
        akInitiator.GetDisplayName() + " steps back, letting " + akTarget.GetDisplayName() + " go free.", \
        akInitiator, akTarget)
EndFunction

; Idempotent "get this actor off the ground NOW", callable from ANY state — our ground window, an
; external Acheron/other bleedout, or a stuck leftover after a scene. Safe to call repeatedly. This
; is the single reliable recovery path; everything that frees a downed actor should funnel here.
; abFullRescue=False (Stand Back only) skips Acheron's own dramatic RescueActor call -- see
; _ClearAcheronHold. Every other caller keeps the default (True), unchanged.
Function _ForceRecover(Actor akActor, Bool abFullRescue = True)
    If !akActor
        Return
    EndIf
    Bool isPlayer = (akActor == PlayerRef)
    _Log("[SNBaka] _ForceRecover ENTER: " + akActor.GetDisplayName() + " isPlayer=" + isPlayer + " abFullRescue=" + abFullRescue)
    ; If our ground window is currently running, make it exit cleanly instead of fighting us.
    _bReleaseRequested = True
    _bStandBack        = False
    StorageUtil.SetIntValue(akActor,    "SNBaka.OnGround",      0)
    StorageUtil.SetStringValue(akActor, "SNBaka.DownPose",      "")
    StorageUtil.SetIntValue(akActor,    "SNBaka.Locked",        0)
    StorageUtil.SetIntValue(akActor,    "SNBaka.StopRequested", 0)
    ; This used to be left set — only _OnVictimWon (a genuine struggle-escape) ever cleared it, so
    ; Release/HelpUp/Stand Back (everything routing through here) never actually ended the "captive"
    ; relationship this flag represents. Harmless on its own, but it's about to become load-bearing:
    ; Acheron's OnActorRescued checks this exact flag to tell "we legitimately freed them" apart from
    ; "AcheronNG's own defeat-duration timer rescued them out from under an intended captivity" — if
    ; this stayed 1 through a real release, that check couldn't tell the two apart.
    StorageUtil.SetIntValue(akActor,    "SNBaka.Captive",       0)
    ; The victim is actually being freed now — this is where the tracked aggressor (held pacified since
    ; _EscalationCleanup, if a scene happened) finally gets its aggression back, not immediately after
    ; the scene ends. Read it before clearing the reference.
    Actor trackedThreat = StorageUtil.GetFormValue(akActor, "SNBaka.GroundWindowAggressor") as Actor
    If trackedThreat
        _PacifyActor(trackedThreat, False)
        ; End the "lover"-rank anti-re-aggro link from the escalation that downed them (humanoid
        ; aggressors too — the creature-wide sweep below only covers supported creatures).
        trackedThreat.SetRelationshipRank(akActor, 0)
        If akActor != PlayerRef
            akActor.SetRelationshipRank(trackedThreat, 0)
        EndIf
    EndIf
    ; Also sweep stale creature links from past cycles (never reverted by older builds — confirmed:
    ; a giant that had previously beaten this victim would never attack them again).
    _ClearAggressorBonds(akActor)
    StorageUtil.SetFormValue(akActor,   "SNBaka.GroundWindowAggressor", None)
    akActor.SetRestrained(False)
    akActor.SetDontMove(False)
    If !isPlayer
        _PacifyActor(akActor, False)
        _HoldActorAI(akActor, False)
    EndIf
    ; Acheron's own RescueActor (inside _ClearAcheronHold) pops a bled-out actor upright natively,
    ; the instant it's called -- no animation, just "up". Calling it HERE, before _Recover gets a
    ; chance to play its own get-up transition, left nothing down to visibly transition out of: the
    ; actor was already standing by the time our SendAnimationEvent fired. Confirmed real bug from
    ; testing: HelpUp on the player looked like they "just became up" with no stand-up animation at
    ; all. _Recover already clears the Acheron hold itself, in the right order (animate first, then
    ; clear) -- let it do that instead of racing it here. Only the abFullRescue flag needs threading
    ; through so Stand Back's "skip the dramatic rescue" intent still reaches it.
    If _IsDownedAny(akActor)
        _Recover(akActor, abFullRescue)   ; get-up transition first, THEN Acheron hold clear + essential-HP guard
    Else
        ; Already standing — e.g. the bridge's cross-script control-restore handoff fires this AFTER
        ; its own recovery ritual finished. Re-running the get-up staggered the player repeatedly and
        ; raced a second queued RescueActor (confirmed report: "after using the KEY to stand, I
        ; staggered several times and cannot attack"). Skip the ritual; everything below is the
        ; idempotent sanitize half, which is the only part the handoff needs.
        _Log("[SNBaka] _ForceRecover: " + akActor.GetDisplayName() + " is already up — sanitize only, skipping the get-up ritual")
    EndIf
    If isPlayer
        Game.EnablePlayerControls()
        ; OStim sets this for player scenes and a force-stopped/refused scene can strand it — nothing
        ; else in either mod ever cleared it. Confirmed symptom pair: can't attack + sluggish camera
        ; after recovery. Idempotent when already clean.
        Game.SetPlayerAIDriven(False)
        ; Lingering Acheron PACIFY on the player (applied by earlier builds, save-persistent, native
        ; handling blocks attack/sprint) — strip it at every recovery. No-op on a clean player; the
        ; !IsDefeated guard keeps an active defeat's own pacify untouched.
        If StorageUtil.GetIntValue(PlayerRef, "SNAcheron.Present", 0) == 1 && !Acheron.IsDefeated(PlayerRef)
            Acheron.ReleaseActor(PlayerRef)
        EndIf
    EndIf
    akActor.EvaluatePackage()
    _Log("[SNBaka] _ForceRecover: stood up " + akActor.GetDisplayName() + " (player=" + isPlayer + ")")
EndFunction

; --- Help Up ---
; An NPC (or the player) helps a downed actor back to their feet. Unlike Release (which only works
; inside our brief ground window), this works whenever the target reads as downed — our OnGround
; OR an external Acheron bleedout — so it ALSO rescues a player who got stuck on the ground after a
; scene. The helper briefly crouches over the victim ("check downed") before lifting them.
Function HelpUp_Execute(Actor akInitiator, Actor akTarget)
    _Log("[SNBakaACT] HelpUp ENTER")
    If !akInitiator || !akTarget
        Return
    EndIf
    If _IsCreatureActor(akInitiator) || _IsCreatureActor(akTarget)
        _Log("[SNBaka] HelpUp_Execute: blocked — creature actor (use CreatureEscalate)")
        Return
    EndIf
    If _IsDownedAny(akInitiator)
        _Log("[SNBaka] HelpUp_Execute: blocked — initiator is downed")
        Return
    EndIf
    If !_IsDownedAny(akTarget)
        ; Two confirmed races land a HelpUp on a victim who is "down" to the eye but not to _IsDownedAny:
        ; (a) native bleedout whose Acheron defeat/adoption hasn't finished landing yet, and (b) a
        ; creature pin in progress — the grab temporarily rescues the victim out of Acheron to animate,
        ; so mid-pin she reads as recovered (10:52:50 log: LLM HelpUp during Joylie's falmer pin no-oped).
        ; The helper's intent is unambiguous, so wait out the transition and help once she's back down.
        Float settle = 0.0
        While settle < 15.0 && !_IsDownedAny(akTarget) && (IsActorLocked(akTarget) || akTarget.IsBleedingOut()) && !akTarget.IsDead()
            Utility.Wait(0.5)
            settle += 0.5
        EndWhile
        If !_IsDownedAny(akTarget)
            _Log("[SNBaka] HelpUp_Execute: target not downed (waited " + settle + "s) — nothing to do")
            Return
        EndIf
        _Log("[SNBaka] HelpUp_Execute: down state landed after " + settle + "s — proceeding")
    EndIf
    _Log("[SNBaka] HelpUp_Execute: " + akInitiator.GetDisplayName() + " helps up " + akTarget.GetDisplayName())
    SkyrimNetApi.RegisterEvent("baka_release", \
        akInitiator.GetDisplayName() + " crouches beside " + akTarget.GetDisplayName() + " and pulls them back to their feet. " + \
        akTarget.GetDisplayName() + " is up again now — shaken and worse for wear, but no longer down.", \
        akInitiator, akTarget)
    _ClearActorTears(akTarget)
    ; Brief "check downed" before lifting. NPCs get Babo_Kneel (the same pose PoseKneel uses) — it's a
    ; custom third-person-only pose, so never sent to the player. The player instead gets the vanilla
    ; IdleTake (pick-up-object idle, has proper first-person data, already used elsewhere on the player
    ; for the same "reach down" beat) — no explicit reset after, it's a self-resetting vanilla idle.
    If akInitiator == PlayerRef
        ; No combat gate for the player: helping someone up mid-fight is a deliberate button press,
        ; and skipping the beat here is exactly what read as "I did no action" in testing. If the
        ; combat graph swallows the idle, it just doesn't play — harmless.
        Debug.SendAnimationEvent(akInitiator, "IdleTake")
        Utility.Wait(2.0)
    ElseIf !akInitiator.IsInCombat()
        Debug.SendAnimationEvent(akInitiator, "Babo_Kneel")
        Utility.Wait(2.0)
        Debug.SendAnimationEvent(akInitiator, "IdleForceDefaultState")
    EndIf
    _ForceRecover(akTarget)
    ; Help Up is a deliberate caring act — Calm the target so they don't immediately re-enter combat
    ; the moment they're back on their feet (same Calm-archetype pattern used elsewhere in this file,
    ; e.g. _CalmForAnim/_PacifyActor). No-op if SNBakaCalm was never assigned, or target isn't fighting.
    If SNBakaCalm && akTarget.IsInCombat()
        akTarget.StopCombat()
        SNBakaCalm.Cast(akTarget, akTarget)
        _Log("[SNBaka] HelpUp_Execute: cast SNBakaCalm on " + akTarget.GetDisplayName())
    EndIf
EndFunction

; --- Capture ---
; The captor takes a DOWNED victim prisoner instead of killing/looting/leaving. This RESOLVES the
; encounter: the captor stops fighting (so combat does NOT resume), the victim is brought out of the
; down/bleedout state, and a captive relationship is recorded for SkyrimNet to roleplay (captor =
; master, victim = prisoner/slave). Works for both a Baka ground-window down AND an Acheron bleedout.
Function Capture_Execute(Actor akCaptor, Actor akVictim)
    _Log("[SNBakaACT] Capture ENTER")
    If !akCaptor || !akVictim
        Return
    EndIf
    If _IsCreatureActor(akCaptor) || _IsCreatureActor(akVictim)
        _Log("[SNBaka] Capture: blocked — creature actor")
        Return
    EndIf
    If _IsDownedAny(akCaptor)
        _Log("[SNBaka] Capture: blocked — captor is downed")
        Return
    EndIf
    If !_IsDownedAny(akVictim)
        _Log("[SNBaka] Capture: target not downed — ignored")
        Return
    EndIf
    ; NPC-vs-NPC is now supported: the Calm spell + "stand down everyone hostile to the CAPTIVE"
    ; detection works regardless of who the captor is, so we no longer gate this to the player.
    _Log("[SNBaka] Capture: " + akCaptor.GetDisplayName() + " captures " + akVictim.GetDisplayName())
    Bool isPlayer = (akVictim == PlayerRef)

    ; ---- PLAYER hybrid: a brief HELD-CAPTIVE beat on the ground first, THEN freed as captive. ----
    ; The player stays down (bleedout/Acheron hold, untouched) while the captor claims them out loud —
    ; "you've been taken" — then we pull them up and hand off to the ally-faction captive state below.
    If isPlayer
        _bResetDownWindow = True
        SkyrimNetApi.RegisterEvent("baka_capture", \
            akCaptor.GetDisplayName() + " pins the beaten " + akVictim.GetDisplayName() + " down and claims them as a prisoner — the fight is over. " + \
            "Have " + akCaptor.GetDisplayName() + " SAY something RIGHT NOW while " + akVictim.GetDisplayName() + " is still held helpless on the ground — assert ownership, threaten, gloat, or give an order.", \
            akCaptor, akVictim)
        Utility.Wait(6.0)   ; the captive beat — player remains downed/held
    EndIf

    ; ---- Free the victim out of the down/bleedout state (player AFTER the beat; NPCs immediately). ----
    _bReleaseRequested = True                                  ; ends any running Baka ground window
    StorageUtil.SetIntValue(akVictim, "SNBaka.OnGround", 0)
    StorageUtil.SetStringValue(akVictim, "SNBaka.DownPose", "")
    _ClearAcheronHold(akVictim)   ; clear Acheron defeat/hold -> Downed_SkyrimNet + the bridge stand down

    ; VISUAL: the captor SEIZES the victim by the arm (reusing the arm-hold paired animation) — for the
    ; player this reads as being hauled up and led away; for NPCs it's the grab/lead-away.
    If LockBoth(akCaptor, akVictim)
        PlayPairedSimpleAnim(akCaptor, akVictim, 0.0, 0.0, 0.0, "BaboHoldArmM", "BaboHoldArmF", 4.0)
        UnlockBoth(akCaptor, akVictim)
    EndIf

    ; End the fight LAST, so the pacify isn't undone by the animation above. Captor + whole nearby
    ; group go ALLY rank so faction hostility can't re-open the fight on the new prisoner.
    _PacifyActor(akCaptor, True)
    akCaptor.StopCombat()
    akCaptor.StopCombatAlarm()
    akCaptor.SetRelationshipRank(akVictim, 4)
    akCaptor.EvaluatePackage()
    _PacifyNearbyHostiles(akVictim, 3000.0)
    If !isPlayer
        _PacifyActor(akVictim, True)
        akVictim.SetRelationshipRank(akCaptor, 4)
    EndIf
    If isPlayer
        Game.EnablePlayerControls()
    EndIf

    ; Captive state + the final "now you're my captive" cue (the held beat already prompted the claim).
    StorageUtil.SetIntValue(akVictim, "SNBaka.Captive", 1)
    If isPlayer
        SkyrimNetApi.RegisterEvent("baka_capture", \
            akCaptor.GetDisplayName() + " hauls " + akVictim.GetDisplayName() + " up by the arm — now " + akCaptor.GetDisplayName() + "'s captive, no longer enemies. Keep roleplaying as captor and prisoner.", \
            akCaptor, akVictim)
    Else
        SkyrimNetApi.RegisterEvent("baka_capture", \
            akCaptor.GetDisplayName() + " seizes " + akVictim.GetDisplayName() + " by the arm and claims them as a prisoner — the fight is over, they are no longer enemies. " + \
            akVictim.GetDisplayName() + " is now " + akCaptor.GetDisplayName() + "'s captive. " + \
            "Have " + akCaptor.GetDisplayName() + " SAY something to their new captive right now — assert ownership, threaten, gloat, or give an order — then keep roleplaying as captor/master.", \
            akCaptor, akVictim)
    EndIf
EndFunction

; --- Sell to Slavery ---
; The captor hauls the defeated PLAYER off to a slave auction, handing them to Simple Slavery Plus
; Plus (the "SSLV Entry" mod event). OPTIONAL: no-ops cleanly if Simple Slavery isn't installed or the
; MCM toggle is off. NPC victims just get a narrative beat (Simple Slavery only auctions the player).
Function SellToSlavery_Execute(Actor akSeller, Actor akVictim)
    _Log("[SNBakaACT] SellToSlavery ENTER")
    If !akSeller || !akVictim
        Return
    EndIf
    ; Real plugin-presence check (same pattern Ostim_interactions uses for Stage Flow) -- the "SSLV
    ; Entry" mod event no-ops harmlessly without SS++, but everything BEFORE it (clearing the defeat
    ; state, re-enabling player controls, the capture narration) very much doesn't: without the actual
    ; auction to hand off to, this action just silently freed the victim.
    If !IsSimpleSlaveryInstalled()
        _Log("[SNBaka] SellToSlavery: blocked — SimpleSlavery.esp not installed")
        Return
    EndIf
    If _IsCreatureActor(akSeller) || _IsCreatureActor(akVictim)
        _Log("[SNBaka] SellToSlavery: blocked — creature actor")
        Return
    EndIf
    If _IsDownedAny(akSeller)
        _Log("[SNBaka] SellToSlavery: blocked — seller is downed")
        Return
    EndIf
    If akVictim != PlayerRef
        ; Simple Slavery auctions the player only — narrate the rest.
        SkyrimNetApi.RegisterEvent("baka_capture", \
            akSeller.GetDisplayName() + " hauls the defeated " + akVictim.GetDisplayName() + " away to be sold into slavery.", \
            akSeller, akVictim)
        Return
    EndIf
    If !bSellToSlavery
        _Log("[SNBaka] SellToSlavery: disabled in MCM — skipped")
        Return
    EndIf
    ; Clean the defeat state before the hand-off so the player isn't bleeding out/Acheron-held at the auction.
    _ClearAcheronHold(akVictim)
    _bReleaseRequested = True
    StorageUtil.SetIntValue(akVictim, "SNBaka.OnGround", 0)
    Game.EnablePlayerControls()
    SkyrimNetApi.RegisterEvent("baka_capture", \
        akSeller.GetDisplayName() + " drags " + akVictim.GetDisplayName() + " off to be sold at a slave auction.", \
        akSeller, akVictim)
    Utility.Wait(1.0)
    ; Hand off to Simple Slavery Plus Plus via its "SSLV Entry" mod event. If SS++ isn't installed,
    ; nothing is listening and this is a harmless no-op (so it's a soft dependency).
    SendModEvent("SSLV Entry")
    _Log("[SNBaka] SellToSlavery: sent SSLV Entry")
EndFunction

; --- EnslaveFollower ---
; An NPC hauls the player's DOWNED follower off into slavery via the Follower Slavery Mod (FSM).
; Deliberately narrow so the LLM can never confuse it with SellToSlavery (which auctions the PLAYER
; via Simple Slavery++): the captor must be a living, non-creature NPC; the target must be a downed
; player-TEAMMATE (never the player); and the player must be either downed themselves or farther
; than fSlaveryPlayerDistance — you only lose a follower you couldn't defend.
Function EnslaveFollower_Execute(Actor akCaptor, Actor akFollower)
    _Log("[SNBakaACT] EnslaveFollower ENTER")
    If !bEnabled || !bFollowerSlavery || !akCaptor || !akFollower
        Return
    EndIf
    If !IsFollowerSlaveryInstalled()
        _Log("[SNBaka] EnslaveFollower: blocked — Follower Slavery Mod not installed/initialized (open its MCM and Install)")
        Return
    EndIf
    If akFollower == PlayerRef || akCaptor == PlayerRef
        _Log("[SNBaka] EnslaveFollower: blocked — player involved (SellToSlavery is the player path)")
        Return
    EndIf
    If _IsCreatureActor(akCaptor) || _CreatureAnimKey(akCaptor) != "" || akCaptor.IsDead() || _IsDownedAny(akCaptor)
        _Log("[SNBaka] EnslaveFollower: blocked — captor is a creature, dead, or downed")
        Return
    EndIf
    If !akFollower.IsPlayerTeammate()
        _Log("[SNBaka] EnslaveFollower: blocked — " + akFollower.GetDisplayName() + " is not a follower of the player")
        Return
    EndIf
    If !_IsDownedAny(akFollower)
        _Log("[SNBaka] EnslaveFollower: blocked — follower is not downed")
        Return
    EndIf
    If IsActorLocked(akFollower) || IsInSexAnimation(akFollower)
        _Log("[SNBaka] EnslaveFollower: blocked — follower is mid-interaction/scene")
        Return
    EndIf
    If !_IsDownedAny(PlayerRef) && PlayerRef.GetDistance(akFollower) < fSlaveryPlayerDistance
        _Log("[SNBaka] EnslaveFollower: blocked — player is up and close enough to intervene (" + PlayerRef.GetDistance(akFollower) + " < " + fSlaveryPlayerDistance + ")")
        Return
    EndIf
    _Log("[SNBaka] EnslaveFollower: " + akCaptor.GetDisplayName() + " enslaves the downed " + akFollower.GetDisplayName())
    ; Clean OUR entire state off the follower first (Acheron hold, locks, pacify, bonds, ghost) —
    ; FSM force-moves and re-manages them from here on; two systems must never co-own the actor.
    _ForceRecover(akFollower)
    ; Narrate BEFORE the handoff so the LLM knows exactly what happened, to whom, by whom.
    SkyrimNetApi.RegisterEvent("baka_enslaved", \
        akCaptor.GetDisplayName() + " binds the beaten " + akFollower.GetDisplayName() + " and drags them away into slavery — they are no longer part of the player's party.", \
        akCaptor, akFollower)
    _Notify(akFollower.GetDisplayName() + " has been taken into slavery!")
    ; FSM's documented external API (fsm_utilityscript.psc): offer the captor as the master, with
    ; fallback allowed so FSM picks a valid one if the captor doesn't qualify as a master.
    Int hEnslave = ModEvent.Create("fsm_enslavefollower")
    If hEnslave
        ModEvent.PushForm(hEnslave, akFollower)
        ModEvent.PushForm(hEnslave, akCaptor)
        ModEvent.PushString(hEnslave, "")
        ModEvent.PushBool(hEnslave, True)
        ModEvent.Send(hEnslave)
        _Log("[SNBaka] EnslaveFollower: fsm_enslavefollower sent (follower=" + akFollower.GetDisplayName() + " master=" + akCaptor.GetDisplayName() + ", fallback allowed)")
    Else
        _Log("[SNBaka] EnslaveFollower: ERROR — ModEvent.Create failed, FSM handoff not sent")
    EndIf
EndFunction

; --- Escalate ---
; Called during the 20-second ground window after a QTE defeat.
; akTarget must be on the ground (SNBaka.OnGround = 1).
; akInitiator must be free (not locked). Sets _bEscalateRequested so
; _DefeatGroundWindow proceeds to _DoEscalation.
Function Escalate_Execute(Actor akInitiator, Actor akTarget)
    _Log("[SNBakaACT] Escalate ENTER")
    _Log("[SNBaka] Escalate_Execute: initiator=" + akInitiator.GetDisplayName() + " target=" + akTarget.GetDisplayName() + " OnGround=" + StorageUtil.GetIntValue(akTarget, "SNBaka.OnGround", 0) + " InitLocked=" + StorageUtil.GetIntValue(akInitiator, "SNBaka.Locked", 0) + " bNPCCanEscalate=" + bNPCCanEscalate)
    If !akTarget || !akInitiator
        _Log("[SNBaka] Escalate_Execute: blocked — None actor")
        Return
    EndIf
    If _IsCreatureActor(akInitiator) || _IsCreatureActor(akTarget)
        _Log("[SNBaka] Escalate_Execute: blocked — creature actor (use CreatureEscalate instead)")
        Return
    EndIf
    ; Content-preference filter, not a technical constraint -- same precedent as bNPCCanEscalate below,
    ; only gates a non-player initiator. The player targeting whoever they want is their own choice.
    If akInitiator != PlayerRef && !_TargetSexAllowed(akTarget)
        _Log("[SNBaka] Escalate_Execute: blocked — target sex not allowed by MCM (iTargetSex=" + iTargetSex + ")")
        Return
    EndIf
    Bool ours = StorageUtil.GetIntValue(akTarget, "SNBaka.OnGround", 0) == 1
    Bool external = !ours && _IsDownedAny(akTarget)
    If !ours && !external
        _Log("[SNBaka] Escalate_Execute: blocked — target not downed")
        Return
    EndIf
    If StorageUtil.GetIntValue(akInitiator, "SNBaka.Locked", 0) == 1
        _Log("[SNBaka] Escalate_Execute: blocked — initiator locked")
        Return
    EndIf
    If _IsDownedAny(akInitiator)
        _Log("[SNBaka] Escalate_Execute: blocked — initiator is downed")
        Return
    EndIf
    If akInitiator != PlayerRef && !bNPCCanEscalate
        _Log("[SNBaka] Escalate_Execute: blocked — NPC escalation disabled (bNPCCanEscalate=False)")
        Return
    EndIf
    _StartTears(akTarget)
    SkyrimNetApi.RegisterEvent("baka_escalate", \
        akInitiator.GetDisplayName() + " moves in on the helpless " + akTarget.GetDisplayName() + ".", \
        akInitiator, akTarget)
    If ours
        _Log("[SNBaka] Escalate_Execute: accepted — signalling the ground window")
        _bEscalateRequested = True       ; our ground window picks this up
    Else
        _Log("[SNBaka] Escalate_Execute: accepted — external down, escalating directly")
        _DoEscalation(akInitiator, akTarget)   ; no window of ours -> run it now
    EndIf
EndFunction

; --- Downed-victim menu dispatch ---
; Called by the DLL (SNBaka_MenuChoice "downed" mode) when the player picks an option from
; the menu shown by pressing the power on a downed victim. Runs on its own stack; the actual
; work for Investigate/Inspect/Stand Back is handed to the running _DefeatGroundWindow loop
; via flags so the victim stays owned by one place. choice:
;   0 = Escalate (straight to the choke/sex escalation, as before)
;   1 = Investigate    2 = Inspect (play the anim through, no QTE, then re-down + reset timer)
;   3 = Stand Back     (exit the window: stagger -> stand up -> regain control)
;  <0 = cancel (victim stays downed; window keeps running)
Function _DispatchDownedAction(Int choice, Actor akCaster, Actor akVictim)
    _Log("[SNBaka] _DispatchDownedAction: choice=" + choice + " caster=" + akCaster + " victim=" + akVictim)
    If !akCaster || !akVictim
        Return
    EndIf
    Bool ours = StorageUtil.GetIntValue(akVictim, "SNBaka.OnGround", 0) == 1
    Bool external = !ours && _IsDownedAny(akVictim)
    If !ours && !external && akVictim.IsBleedingOut()
        ; The power's menu opens on native BLEEDOUT, but the Acheron defeat + our adoption net lag it
        ; by several seconds (confirmed live: HelpUp dispatched at 11:13:09 was ignored as "no longer
        ; downed" while the bridge only adopted the defeat at 11:13:14 — the player's help did nothing).
        ; Bridge that gap: the player is pointing at someone visibly on the ground, so wait for the
        ; down state to actually land before judging whether they're downed.
        Float settle = 0.0
        While settle < 8.0 && !_IsDownedAny(akVictim) && akVictim.IsBleedingOut() && !akVictim.IsDead()
            Utility.Wait(0.5)
            settle += 0.5
        EndWhile
        ours = StorageUtil.GetIntValue(akVictim, "SNBaka.OnGround", 0) == 1
        external = !ours && _IsDownedAny(akVictim)
        _Log("[SNBaka] _DispatchDownedAction: bleedout settle wait " + settle + "s -> ours=" + ours + " external=" + external)
    EndIf
    If !ours && !external
        If choice == 4
            ; HelpUp owns its own settle logic (mid-pin lock gap, late-landing bleedout) and re-checks
            ; everything itself — let it decide instead of silently eating the player's click here.
            HelpUp_Execute(akCaster, akVictim)
            Return
        EndIf
        _Log("[SNBaka] _DispatchDownedAction: victim no longer downed — ignoring")
        Return
    EndIf
    If ours
        ; OUR ground window owns this victim — signal it via flags (it polls them).
        If choice == 0
            Escalate_Execute(akCaster, akVictim)
        ElseIf choice == 1
            _iDownedReplay = 1
        ElseIf choice == 2
            _iDownedReplay = 2
        ElseIf choice == 3
            _bStandBack = True
        ElseIf choice == 4
            HelpUp_Execute(akCaster, akVictim)   ; _ForceRecover sets _bReleaseRequested, same exit path as Stand Back
        Else
            _Log("[SNBaka] _DispatchDownedAction: cancel — victim stays downed")
        EndIf
    Else
        ; Downed by an external mod/cause (e.g. Surrender, or Acheron) — no window of ours is running, so
        ; run the action directly with the caster as the actor. (Same functions the window would have called.)
        _Log("[SNBaka] _DispatchDownedAction: external down — running choice " + choice + " directly")
        If choice == 0
            _DoEscalation(akCaster, akVictim)            ; choke-down -> sex
        ElseIf choice == 1
            _DownedReplay(akCaster, akVictim, 1)         ; investigate
        ElseIf choice == 2
            _DownedReplay(akCaster, akVictim, 2)         ; inspect
        ElseIf choice == 3
            ; Was a silent no-op here — "leaving victim to the other mod" never actually freed them,
            ; since nothing was listening for that comment. Recover them locally, but abFullRescue=False:
            ; Stand Back is "we step back and let them get up," not "we rescued them" — the earlier fix
            ; called the same full-rescue path as Help Up, which made Stand Back visibly/mechanically
            ; indistinguishable from it (Acheron's own RescueActor "saved" treatment firing either way).
            _ForceRecover(akVictim, False)
            _Log("[SNBaka] _DispatchDownedAction: external stand-back — recovered directly (no Acheron rescue)")
        ElseIf choice == 4
            HelpUp_Execute(akCaster, akVictim)
        Else
            _Log("[SNBaka] _DispatchDownedAction: external cancel — victim stays downed")
        EndIf
    EndIf
EndFunction

; --- Downed replay (Investigate / Inspect on an already-downed victim) ---
; Plays the inspection sequence to completion with NO QTE, then drops the victim back to the
; ground. Called from inside _DefeatGroundWindow's wait loop; the loop resets its timer after.
; which: 1 = Investigate (Babo_Investigation), 2 = Inspect (Babo_Captured).
Function _DownedReplay(Actor akA1, Actor akA2, Int which)
    _Log("[SNBaka] _DownedReplay: A1=" + akA1.GetDisplayName() + " A2=" + akA2.GetDisplayName() + " which=" + which)
    If !akA1 || !akA2 || akA2.IsDead()
        Return
    EndIf
    ; Investigate_Execute/CapturedInspect_Execute (the direct-call entry points for these same two
    ; actions) both check HasFemaleBody before doing anything -- this replay path, reached from the
    ; downed-menu's Investigate/Inspect picks (both the "ours" ground-window loop and the "external"/
    ; Hunter's Pride dispatch), had no such check at all, so it would happily play CapturedBoob/
    ; CapturedPussy female-specific animation stages on a male victim.
    ; Same creature-skeleton guard as IsEligible: a falmer/giant aggressor reaching this replay
    ; (via the downed menu or Hunter's Pride) would play humanoid inspection anims it can't skeleton.
    If _IsCreatureActor(akA1) || _CreatureAnimKey(akA1) != ""
        _Log("[SNBaka] _DownedReplay: blocked — creature-skeleton initiator " + akA1.GetDisplayName() + " (humanoid anims only)")
        Return
    EndIf
    If !HasFemaleBody(akA2)
        _Log("[SNBaka] _DownedReplay: blocked — target is not female")
        Return
    EndIf

    String[] a1 = new String[3]
    String[] a2 = new String[3]
    String what = "investigates "
    Float s0rot = 0.0   ; Investigation flips the aggressor on stage 0 (see PlayPairedSequence)
    If which == 2
        a1[0] = "Babo_Captured_A2"
        a1[1] = "Babo_CapturedBoob_A2"
        a1[2] = "Babo_CapturedPussy_A2"
        a2[0] = "Babo_Captured_A1"
        a2[1] = "Babo_CapturedBoob_A1"
        a2[2] = "Babo_CapturedPussy_A1"
        what = "inspects the captured "
        RecordAnimation(akA1, "CapturedInspect", akA2.GetDisplayName())
    Else
        a1[0] = "Babo_Investigation_S01_A02"
        a1[1] = "Babo_Investigation_S02_A02"
        a1[2] = "Babo_Investigation_S03_A02"
        a2[0] = "Babo_Investigation_S01_A01"
        a2[1] = "Babo_Investigation_S02_A01"
        a2[2] = "Babo_Investigation_S03_A01"
        RecordAnimation(akA1, "Investigate", akA2.GetDisplayName())
        s0rot = 180.0
    EndIf

    _CueOngoing("baka_forced", \
        akA1.GetDisplayName() + " " + what + "the helpless " + akA2.GetDisplayName() + "'s body as they lie defeated.", \
        akA1, akA2)
    PlayPanicSound(akA2)
    _StartTears(akA2)

    ; Re-lock the (currently free) attacker; the victim is still owned by the ground window.
    StorageUtil.SetIntValue(akA1, "SNBaka.Locked", 1)
    ; Bring the victim up out of bleedout + clear the ground-hold flags so _SetupPair (inside
    ; PlayPairedSequence) can position and drive their skeleton cleanly.
    akA2.SetRestrained(False)
    akA2.SetDontMove(False)
    _Recover(akA2)
    Utility.Wait(0.3)

    ; Full inspection sequence, NO QTE — it runs every stage through, then _CleanupPair resets.
    PlayPairedSequence(akA1, akA2, 0.0, 0.0, 180.0, a1, a2, fSequenceStageTimer, False, True, s0rot)

    ; Drop the victim straight back down; the ground window resets its timer on return.
    _Bleedout(akA2, akA1)
    Utility.Wait(0.3)
    If akA2 != PlayerRef
        akA2.SetRestrained(True)
        akA2.SetDontMove(True)
        _PacifyActor(akA2, True)
        _HoldActorAI(akA2, True)
    EndIf
    ; Free the attacker again so they stand back over the downed victim.
    _UnlockAttackerOnly(akA1)
    _Log("[SNBaka] _DownedReplay: complete — victim re-downed")
EndFunction

; ============================================================
; CREATURE ESCALATION (opt-in; bestiality content — gated behind bCreatureEscalation, default OFF)
; ============================================================
; Maps a live creature to its Baka paired-QTE animation base by RACE NAME (best-effort, no SexLab/
; OStim needed to identify or play — those are only the optional sex backend). dog == wolf (canine).
; Returns "" for unsupported races. Order matters: more specific names first (Werewolf before Wolf,
; Chaurus Hunter/Reaper before Chaurus, Dwarven Spider before Spider, Giant after Spider).
String Function _CreatureAnimKey(Actor akCreature)
    If !akCreature
        Return ""
    EndIf
    ; Race EditorID first — tied to the actual skeleton, so a renamed/reskinned creature (e.g. a mod's
    ; "Sewer Troll" that's still TrollRace underneath) matches correctly even though its display name
    ; has nothing to do with "troll". Display name stays in the same check as a fallback, for the
    ; reverse case: a wholly custom race whose EditorID doesn't mention a supported type but whose
    ; display name does.
    String n = MiscUtil.GetActorRaceEditorID(akCreature) + "|" + akCreature.GetDisplayName()   ; "TrollRace|Frost Troll"...
    If n == "|"
        Return ""
    EndIf
    If StringUtil.Find(n, "Werewolf") >= 0
        Return "Babo_WerewolfQTE"
    ElseIf StringUtil.Find(n, "Wolf") >= 0 || StringUtil.Find(n, "Dog") >= 0 || StringUtil.Find(n, "Husky") >= 0 || StringUtil.Find(n, "Fox") >= 0 || StringUtil.Find(n, "Hound") >= 0
        ; "Hound": Death Hounds (DLC1DeathHoundRace) run on the canine skeleton, whose Baka Motion
        ; animation list registers the Wolf QTE events -- they were undetected before despite the
        ; animations genuinely supporting them (neither "Wolf" nor "Dog" appears in their race/name).
        Return "Babo_WolfQTE"
    ElseIf StringUtil.Find(n, "Chaurus Hunter") >= 0 || StringUtil.Find(n, "ChaurusHunter") >= 0
        ; Every no-space variant below mirrors the race EditorID convention ("ChaurusHunterRace",
        ; "DwarvenSpiderRace", "DLC2AshHopperRace"...) -- the spaced form only matches the display
        ; name, so a RENAMED creature of these types silently fell through to a more generic match
        ; (or none): a renamed Dwarven Spider hit the plain "Spider" branch and got sent animation
        ; events its skeleton doesn't even have, which plays nothing on the creature at all.
        Return "Babo_ChaurusHunterQTE"
    ElseIf StringUtil.Find(n, "Chaurus Reaper") >= 0 || StringUtil.Find(n, "ChaurusReaper") >= 0
        Return "Babo_ChaurusReaperQTE"
    ElseIf StringUtil.Find(n, "Chaurus") >= 0
        Return "Babo_ChaurusQTE"
    ElseIf StringUtil.Find(n, "Dwarven Spider") >= 0 || StringUtil.Find(n, "DwarvenSpider") >= 0
        Return "Babo_DwarvenSpiderQTE"
    ElseIf StringUtil.Find(n, "Centurion") >= 0
        Return "Babo_DwarvenCenturionQTE"
    ElseIf StringUtil.Find(n, "Spider") >= 0
        ; The Baka Motion pack ships three distinct frostbite-spider QTE sets on the same skeleton --
        ; route the giant and large variants to their own clips instead of always using the base one.
        ; Checked INSIDE the spider branch so "Giant Frostbite Spider" can never leak into the plain
        ; "Giant" (humanoid giant) branch below regardless of check order.
        If StringUtil.Find(n, "Giant") >= 0
            Return "Babo_GiantSpiderQTE"
        ElseIf StringUtil.Find(n, "Large") >= 0
            Return "Babo_LSpiderQTE"
        EndIf
        Return "Babo_SpiderQTE"
    ElseIf StringUtil.Find(n, "Sabre") >= 0
        Return "Babo_SabrecatQTE"
    ElseIf StringUtil.Find(n, "Troll") >= 0
        Return "Babo_TrollQTE"
    ElseIf StringUtil.Find(n, "Bear") >= 0
        Return "Babo_BearQTE"
    ElseIf StringUtil.Find(n, "Falmer") >= 0
        Return "Babo_FalmerQTE"
    ElseIf StringUtil.Find(n, "Draugr") >= 0
        Return "Babo_DraugrQTE"
    ElseIf StringUtil.Find(n, "Skeever") >= 0
        Return "Babo_SkeeverQTE"
    ElseIf StringUtil.Find(n, "Riekling") >= 0
        Return "Babo_RieklingQTE"
    ElseIf StringUtil.Find(n, "Netch") >= 0
        Return "Babo_NetchQTE"
    ElseIf StringUtil.Find(n, "Gargoyle") >= 0
        Return "Babo_GargoyleQTE"
    ElseIf StringUtil.Find(n, "Boar") >= 0
        Return "Babo_BoarQTE"
    ElseIf StringUtil.Find(n, "Ash Hopper") >= 0 || StringUtil.Find(n, "AshHopper") >= 0
        Return "Babo_AshHopperQTE"
    ElseIf StringUtil.Find(n, "Giant") >= 0
        Return "Babo_GiantQTE"
    EndIf
    Return ""
EndFunction

; SkyrimNet entry: the LLM (or the player's power) invokes this with the creature + the victim in
; either order. We sort out which is the creature and escalate. Creatures are ESCALATE-ONLY.
Function CreatureEscalate_Execute(Actor akInitiator, Actor akTarget)
    _Log("[SNBakaACT] CreatureEscalate ENTER")
    If !bCreatureEscalation || !akInitiator || !akTarget
        Return
    EndIf
    Actor creature = akInitiator
    Actor victim   = akTarget
    If _CreatureAnimKey(creature) == ""
        If _CreatureAnimKey(akTarget) != ""
            creature = akTarget
            victim   = akInitiator
        Else
            _Log("[SNBaka] CreatureEscalate: neither actor is a supported creature")
            Return
        EndIf
    EndIf
    _DoCreatureEscalation(creature, victim)
EndFunction

; Extended NOT-YET-DOWNED NPC struggle: PlayPairedSequence's own "just play every stage straight
; through" branch (bResistable=False) was only ever ~3s (2 stages x 1.5s) with zero connection to the
; outcome rolled afterward -- confirmed feedback from testing: reads as far too quick to be a real
; struggle, and a non-player victim never got a distinct win/lose animation at all. This holds the
; shared struggle pose (stage 0) for fCreatureStruggleDuration seconds FIRST, THEN rolls, THEN — only
; if the victim actually wins — plays the clip's own stage 1 ("break free") briefly before releasing.
; A creature win has no separate victory stage to show for a 2-stage clip, so it just stays on the
; struggle pose, which flows straight into _StartSexScene right after this returns.
; Bypasses PlayPairedSequence entirely (rather than adding a 3rd branch to it) so human-vs-human
; Struggle, which shares that function, is untouched. Reuses the exact same setup/protection/cleanup
; calls PlayPairedSequence itself uses (_SetupPair already does StopCombat + Ghost + Pacify + AI-hold +
; Restrained on both actors, which is the same "ignore outside combat" protection any other paired
; scene gets — nothing extra needed there for the longer hold).
; Returns True if the victim escaped.
Bool Function _PlayCreatureStruggleNPC(Actor akCreature, Actor akVictim, String[] animsA1, String[] animsA2)
    ObjectReference marker1 = None
    ObjectReference marker2 = None
    If XMarkerBase
        marker1 = akVictim.PlaceAtMe(XMarkerBase, 1, False, False)
        marker2 = akVictim.PlaceAtMe(XMarkerBase, 1, False, False)
    EndIf
    _ProtectNearbyAllies(akVictim, akCreature, True)
    _SetupPair(akCreature, akVictim, 0.0, 0.0, 0.0, True, marker1, marker2, animsA1[0])

    Bool aborted = _HoldAnim(akCreature, akVictim, animsA1[0], animsA2[0], fCreatureStruggleDuration)

    ; Same rule as the top-level comment on _DoCreatureEscalation: a hit/death/distance-break mid-hold
    ; frees the victim and resumes the fight, same as it always has -- treat that as an escape rather
    ; than rolling for an outcome the interruption already decided.
    Bool escaped = True
    If aborted
        _Log("[SNBaka] _PlayCreatureStruggleNPC: aborted mid-struggle (hit/death/distance) -- counts as escaped")
    Else
        escaped = Utility.RandomInt(1, 100) > iCreatureSuccessPct
        _Log("[SNBaka] _PlayCreatureStruggleNPC: struggle held " + fCreatureStruggleDuration + "s, escaped=" + escaped)
        If escaped
            Debug.SendAnimationEvent(akCreature, animsA1[1])
            Debug.SendAnimationEvent(akVictim, animsA2[1])
            Utility.Wait(1.5)
        EndIf
    EndIf

    _ProtectNearbyAllies(akVictim, akCreature, False)
    _CleanupPair(akCreature, akVictim, marker1, marker2, False, False)
    ; Same post-escape grace the player QTE path gets (see PlayPairedSequence) -- an NPC victim who
    ; broke free was equally getting instantly re-hit the moment the cleanup un-ghosted her.
    If escaped
        _PostEscapeGrace(akVictim)
    EndIf
    Return escaped
EndFunction

; Group escalation (2v1/3v1): finds up to (iCreatureGroupMaxSize - 1) OTHER actors of the SAME
; creature type as akAnchor, near akVictim, to join the scene. akAnchor works as the anchor whether it
; just WON its own 1v1 struggle or was simply the single candidate _TryCreatureEscalateOnDowned found
; for a victim already downed by plain combat (no struggle happened) -- either way, this only asks
; "who else of its kind is nearby to join", which is the same question regardless of how the anchor
; itself got here.
; One scan (not separate "try 3, try 2, try 1" passes) collecting whatever's available and capping at
; the max -- functionally the same "biggest available group, gracefully smaller if not" result without
; wastefully re-scanning per size tier. Plus a single cross-cell supplement (same FindClosestActorFromRef
; technique used everywhere else this blind spot shows up) if the same-cell sweep didn't fill both
; slots -- confirmed in testing that group scenes never formed at all, always landing on the same-cell-
; only limitation this function originally shipped with (dungeon dens are almost always split across
; linked cells, same as every other search in this file that had to learn this the hard way).
; Papyrus array sizes must be compile-time literals (no "new Actor[count]") -- always returns a fixed
; 2-slot array, unused slots left None, instead of a dynamically-sized result. Callers check each slot.
Actor[] Function _FindGroupCompanions(Actor akAnchor, Actor akVictim)
    Actor[] slots = new Actor[2]
    Int wanted = iCreatureGroupMaxSize - 1
    If wanted <= 0 || !akAnchor || !akVictim
        Return slots
    EndIf
    String animKey = _CreatureAnimKey(akAnchor)
    Int count = 0
    ; LOADED-AREA enumeration (po3 Papyrus Extender), same as _TryCreatureEscalateOnDowned's scan and
    ; for the same confirmed reason: cell sweeps miss packmates registered in linked cells, which is
    ; why every group scene came out 1v1. Every same-type creature logs its rejection reason so the
    ; log always explains why a group did or didn't form.
    If animKey != ""
        Actor[] loaded = PO3_SKSEFunctions.GetActorsByProcessingLevel(0)
        Int n = loaded.Length
        Int i = 0
        While i < n && count < wanted && count < 2
            Actor a = loaded[i]
            If a && a != akAnchor && a != akVictim && a != slots[0] && !a.IsDead() && _CreatureAnimKey(a) == animKey
                ; !_HasLiveCombatTarget: same rule the ANCHOR gets ("don't pull it out of a real
                ; fight"); a target that's downed/dead doesn't count as a real fight anymore.
                If IsActorLocked(a)
                    _Log("[SNBaka] _FindGroupCompanions: skipping " + a.GetDisplayName() + " — locked (mid-interaction)")
                ElseIf _IsDownedAny(a)
                    _Log("[SNBaka] _FindGroupCompanions: skipping " + a.GetDisplayName() + " — downed")
                ElseIf _HasLiveCombatTarget(a)
                    _Log("[SNBaka] _FindGroupCompanions: skipping " + a.GetDisplayName() + " — still fighting " + a.GetCombatTarget().GetDisplayName())
                ElseIf a.GetDistance(akVictim) > 1500.0
                    _Log("[SNBaka] _FindGroupCompanions: skipping " + a.GetDisplayName() + " — too far (" + a.GetDistance(akVictim) + ")")
                Else
                    slots[count] = a
                    _Log("[SNBaka] _FindGroupCompanions: found companion " + a.GetDisplayName())
                    count += 1
                EndIf
            EndIf
            i += 1
        EndWhile
    EndIf
    _Log("[SNBaka] _FindGroupCompanions: " + count + " companion(s) found (wanted " + wanted + ", key=" + animKey + ")")
    Return slots
EndFunction

; Setup/teardown for a GROUP companion (not the anchor -- that already gets the full _SetupPair
; treatment). Same ghost/restrained/dontmove/AI-hold profile so it can't wander off, get hurt, or
; interfere, but no positioning: OStim/SexLab's own scene engine places every actor once handed a
; scene ID that actually supports this many participants.
Function _PrepGroupCompanion(Actor a, Bool abPrep)
    If !a
        Return
    EndIf
    If abPrep
        a.StopCombat()
        a.StopCombatAlarm()
        SNBakaUI.SetNoCollision(a, True)
        a.SetGhost(True)
        _HoldActorAI(a, True)
        a.SetRestrained(True)
        a.SetDontMove(True)
        _Log("[SNBaka] _PrepGroupCompanion: prepped " + a.GetDisplayName())
    Else
        a.SetRestrained(False)
        a.SetDontMove(False)
        a.SetGhost(False)
        SNBakaUI.SetNoCollision(a, False)
        _HoldActorAI(a, False)
        a.EvaluatePackage()
        _Log("[SNBaka] _PrepGroupCompanion: released " + a.GetDisplayName())
    EndIf
EndFunction

; The engine: play the creature-matched paired anim, decide the outcome, then start the creature sex
; scene on the chosen backend. PC victim -> QTE; NPC -> iCreatureSuccessPct roll either way (downed or not).
; A hit puts an actor back in combat, which aborts the paired anim (existing _ShouldAbort) AND blocks
; the scene below — so getting hit frees the victim and resumes the fight.
Function _DoCreatureEscalation(Actor akCreature, Actor akVictim)
    _Log("[SNBaka] _DoCreatureEscalation ENTER: creature=" + akCreature + " victim=" + akVictim)
    If !bCreatureEscalation || !akCreature || !akVictim
        _Log("[SNBaka] CreatureEscalate: blocked — escOff/none (esc=" + bCreatureEscalation + ")")
        Return
    EndIf
    If akVictim == PlayerRef && !bCreatureOnPlayer
        _Log("[SNBaka] CreatureEscalate: blocked — player victim, bCreatureOnPlayer OFF")
        Return
    EndIf
    Bool vFemale = akVictim.GetActorBase().GetSex() == 1
    ; iCreatureVictimSex: 0 = Both (allow all), 1 = Female only, 2 = Male only (same scheme as iTargetSex).
    If (iCreatureVictimSex == 1 && !vFemale) || (iCreatureVictimSex == 2 && vFemale)
        _Log("[SNBaka] CreatureEscalate: blocked — victim sex not allowed by MCM (iCreatureVictimSex=" + iCreatureVictimSex + " victimFemale=" + vFemale + ")")
        Return
    EndIf
    String base = _CreatureAnimKey(akCreature)
    If base == ""
        _Log("[SNBaka] CreatureEscalate: blocked — no creature anim key for " + akCreature.GetDisplayName())
        Return
    EndIf
    ; Mid-sex-scene actors are untouchable for paired animations — OStim/SexLab threads from ANY mod
    ; (our own Locked flag only marks ours). Same explicit spec as IsEligible's twin check.
    If IsInSexAnimation(akVictim) || IsInSexAnimation(akCreature)
        _Log("[SNBaka] CreatureEscalate: blocked — a participant is mid sex scene (" + akCreature.GetDisplayName() + " -> " + akVictim.GetDisplayName() + ")")
        Return
    EndIf
    Bool downed = _IsDownedAny(akVictim)
    If !downed && !bCreatureCombatAllowed
        _Log("[SNBaka] CreatureEscalate: blocked — victim not downed and mid-combat escalation disabled")
        Return
    EndIf
    If IsActorLocked(akCreature) || IsActorLocked(akVictim)
        _Log("[SNBaka] CreatureEscalate: blocked — actor already locked (creature=" + IsActorLocked(akCreature) + " victim=" + IsActorLocked(akVictim) + ")")
        Return
    EndIf
    If !LockBoth(akCreature, akVictim)
        _Log("[SNBaka] CreatureEscalate: blocked — LockBoth failed")
        Return
    EndIf
    ; Only now, with the pairing actually committed (every rejection gate above already passed), clear
    ; the Acheron hold/OnGround so the creature anim can position the victim properly. Used to happen in
    ; the CALLER (_TryCreatureEscalateOnDowned) before any of these gates ran, which meant a candidate
    ; rejected by one of them (wrong sex, no anim key, already locked, etc.) still had their downed state
    ; silently wiped for nothing — neither still tracked as down nor actually recovered/stood up.
    ; USER-SPEC (the OSimpleDefeat pattern, extended to struggles): a downed victim is NOT lifted out
    ; of Acheron for the pin/QTE — they stay defeated straight through grab -> struggle -> scene ->
    ; re-down, one unbroken protection. Acheron's defeat is the one state that never leaked; every
    ; rescue-to-animate variant opened the exact window enemies kept aggroing through. Acheron lifts
    ; ONLY when the victim genuinely stands — QTE win / HelpUp / the get-up key — each already wrapped
    ; in the mercy grace (fEscapeGraceDuration) against spawn-kills. The paired anim events drive the
    ; graph over the down pose directly; not-downed victims (mid-combat grapples) are unaffected.
    _ProtectVictimTargeting(akVictim)
    StorageUtil.SetIntValue(akVictim, "SNBaka.OnGround", 0)
    _Log("[SNBaka] CreatureEscalate(" + akVictim.GetDisplayName() + "): locked + starting anim, base=" + base + " downed=" + downed)
    RecordAnimation(akVictim, "CreatureEscalate", akCreature.GetDisplayName())
    _CueOngoing("baka_forced", \
        akCreature.GetDisplayName() + " pins " + akVictim.GetDisplayName() + " down and forces itself on them.", \
        akCreature, akVictim)
    PlayPanicSound(akVictim)
    _StartTears(akVictim)

    ; 2-stage pair: creature plays the _A02 events, the human victim plays _A01. Co-located base
    ; (offset key = a1[0]); tune per creature in SNBaka_Offsets.ini since sizes differ.
    String[] a1 = new String[2]
    String[] a2 = new String[2]
    a1[0] = base + "_S01_A02"
    a1[1] = base + "_S02_A02"
    a2[0] = base + "_S01_A01"
    a2[1] = base + "_S02_A01"

    Bool succeed = False
    If akVictim == PlayerRef
        ; FREEZE BYSTANDERS for the whole QTE, not just the scene prep afterwards. The player victim
        ; isn't Acheron-pacified (native player lockdown — camera), so the OTHER giants re-aggroed the
        ; instant the rescue freed them and kept the combat flag live through the QTE — which then made
        ; the scene gate refuse, re-down, re-escalate: the reported infinite loop. Holding every nearby
        ; actor's AI is what actually eliminates combat toward the pair; the scene path re-holds
        ; idempotently, and every exit (scene end, no-scene, refusal) releases.
        _ProtectNearbyAllies(akVictim, akCreature, True)
        ; Real interactive QTE -- unchanged.
        _bQTEDefeated = False
        ; A dedicated, shorter stage timer here (not fSequenceStageTimer) — that 4.0s default is tuned
        ; for the 5-stage human Struggle sequence, where finishing out the current stage after a QTE
        ; resolves is a small fraction of the whole. This creature sequence only has 2 stages, so the
        ; same 4.0s trailing wait after the outcome is already known is most of the sequence's total
        ; length — confirmed in testing as a visible "still animating" hang after the QTE clearly ended.
        PlayPairedSequence(akCreature, akVictim, 0.0, 0.0, 0.0, a1, a2, 1.5, True)
        succeed = _bQTEDefeated             ; creature won the QTE
        _bQTEDefeated = False
        If succeed
            ; USER-SPEC redesign (every hand-rolled protection kept losing to combat AI): the instant
            ; the QTE is lost, hand the victim STRAIGHT to Acheron — its native defeat is the one
            ; state that provably stops all targeting ("downed victims are never attacked"). The
            ; entire scene prep below now runs with the victim safely parked down; they're rescued
            ; back out at the last possible moment, directly into the scene.
            StorageUtil.SetFormValue(akVictim, "SNBaka.GroundWindowAggressor", akCreature)
            _DelegateDownToAcheron(akVictim)
            _Log("[SNBaka] CreatureEscalate(" + akVictim.GetDisplayName() + "): QTE lost — victim parked in Acheron for the prep window")
        EndIf
    Else
        ; NPC victim, downed or mid-combat: a REAL drawn-out struggle either way — _PlayCreatureStruggleNPC
        ; holds the pin pose fCreatureStruggleDuration seconds (MCM-tunable), THEN rolls
        ; iCreatureSuccessPct, THEN plays the break-free stage only on an actual escape. The
        ; already-downed case used to skip this for an instant roll + one ~1.5s stage — explicit
        ; feedback: "gets decided within seconds", hold the struggle 10-20s like the mid-combat case
        ; before deciding. Same roll odds as the old quick path (escaped = roll > pct ≡ succeed = roll <= pct).
        Bool escaped = _PlayCreatureStruggleNPC(akCreature, akVictim, a1, a2)
        succeed = !escaped
    EndIf

    ; Establish the anti-re-aggro relationship (same fix as the bandit re-aggro bug) as soon as we know
    ; the outcome, regardless of whether a scene actually starts right away.
    If succeed
        ; Re-calm the WINNER in the same beat — _CleanupPair (inside the paired sequence that just
        ; ended) restored its aggression, and the scene path's own re-pacify is seconds away. That gap
        ; is exactly when "the giant that escalated on me attacked me while going to OStim" (confirmed
        ; report). Idempotent with the scene path's later call; every no-scene exit re-downs the victim
        ; with GroundWindowAggressor tracked, so recovery restores the creature's aggression properly.
        _PacifyActor(akCreature, True)
        akCreature.SetRelationshipRank(akVictim, 4)
        If akVictim != PlayerRef
            akVictim.SetRelationshipRank(akCreature, 4)
        EndIf
        _StampDefeatGrace(akVictim)
        Utility.Wait(0.3)
    EndIf

    ; CRE-3: the creature STRUGGLE (above) can bring a victim down mid-combat, but the creature SEX only
    ; waits for the fight to clear when the victim is the PLAYER (same gate as human Escalate) -- the
    ; player has their own agency in an ongoing fight, so starting a scene on them mid-chaos is the one
    ; case actually worth holding off on. An NPC victim (e.g. Joylie) gets claimed the instant the
    ; creature wins, exactly like the falmer case that already worked this way -- explicit call: don't
    ; leave her tracked-down-and-waiting through however long the rest of the fight takes just because
    ; OTHER combatants are still swinging at each other nearby. If the scene starts into active combat
    ; and something hits either participant, the existing mid-scene abort (_HasLiveCombatTarget below)
    ; already force-stops it cleanly -- that's the accepted tradeoff for not waiting.
    If succeed && akVictim == PlayerRef
        ; Victim is parked in Acheron (QTE-loss delegate above) — give the pack a beat to natively
        ; disengage from the downed body BEFORE judging whether combat blocks the scene. Trimmed from
        ; 3.0s: post-QTE pacing read as "very long to decide next steps" (confirmed feedback), and the
        ; park means a slightly-early judgment just re-tries rather than exposing anyone.
        Utility.Wait(1.5)
    EndIf
    Bool combatGateBlocks = akVictim == PlayerRef && _CombatNear(akVictim, fCombatOverRadius)
    _Log("[SNBaka] CreatureEscalate(" + akVictim.GetDisplayName() + "): outcome succeed=" + succeed + " combatGateBlocks=" + combatGateBlocks + " sceneAllowed=" + bCreatureSceneAllowed)
    If succeed && !combatGateBlocks && bCreatureSceneAllowed
        ; PlayPairedSequence's own cleanup (CleanupPair) already un-pacified the creature and gave its
        ; aggression back the moment the struggle ended -- only re-pacify it (which is what actually
        ; calls StopCombat, only on the creature) NOW, immediately before actually claiming the victim
        ; for a scene, not the instant the struggle resolved. Confirmed real bug from testing ("draugr
        ; stuck" mid-fight, generalizes to every creature type since this code path is shared): pacifying
        ; unconditionally on any win left the creature frozen -- unable to fight ANYONE, not just the
        ; victim -- for however long it took the victim's OWN recovery cycle to happen to un-pacify it
        ; as a side effect, whenever the fight wasn't actually over yet (the "NO scene" branch below).
        ; That could be a long, open-ended wait in an active multi-enemy fight. _ForceRecover/Acheron's
        ; _Recover un-pacify whatever's tracked as SNBaka.GroundWindowAggressor on real recovery, so this
        ; still gets undone properly once the scene (and thus the victim's hold) actually ends.
        _PacifyActor(akCreature, True)
        ; FREEZE BYSTANDERS FIRST, before anything else on the scene path -- this used to run only
        ; AFTER _StartSexScene returned, which left the whole prep window (group scan, companion prep,
        ; OStim thread spin-up) open for a nearby enemy to re-aggro and hit the victim. Confirmed real
        ; CRASH from testing: a second falmer re-aggroed the player exactly in that window, re-downing
        ; them WHILE OStim was starting its thread -- OStim is unstable with a player actor entering
        ; combat mid-start. Holding every nearby actor's AI before the prep even begins closes the
        ; window at its source.
        _ProtectNearbyAllies(akVictim, akCreature, True)
        ; Group size decided HERE, only once we know we actually need a scene -- a struggle that fails
        ; or a combat-not-clear outcome above never wastes this scan. Papyrus array sizes must be
        ; compile-time literals, so build one of exactly three fixed shapes instead of a dynamic size.
        Actor[] companions = _FindGroupCompanions(akCreature, akVictim)
        Actor comp1 = companions[0]
        Actor comp2 = companions[1]
        If comp1
            _PrepGroupCompanion(comp1, True)
        EndIf
        If comp2
            _PrepGroupCompanion(comp2, True)
        EndIf
        ; LAST-MOMENT re-check, after the prep and with bystanders held: did combat re-flare on the
        ; victim during the gap between the outcome trace above and here? The AI-hold above can't stop
        ; a hit that already landed mid-prep (or an actor outside the hold's reach), and starting the
        ; OStim thread anyway in that state is the confirmed crash. Bail to the same "leave them
        ; downed" outcome the combat-gate branch below already uses -- the retry pipeline picks the
        ; victim up again once things settle.
        If _HasLiveCombatTarget(akVictim) || (akVictim == PlayerRef && _CombatNear(akVictim, fCombatOverRadius))
            _Log("[SNBaka] CreatureEscalate(" + akVictim.GetDisplayName() + "): combat re-flared during scene prep — aborting scene start, leaving victim downed")
            _ProtectNearbyAllies(akVictim, akCreature, False)
            If comp1
                _PrepGroupCompanion(comp1, False)
            EndIf
            If comp2
                _PrepGroupCompanion(comp2, False)
            EndIf
            StorageUtil.SetFormValue(akVictim, "SNBaka.GroundWindowAggressor", akCreature)
            _DelegateDownToAcheron(akVictim)
            UnlockBoth(akCreature, akVictim)
            Return
        EndIf
        Actor[] sexActors
        If comp1 && comp2
            sexActors = new Actor[4]
            sexActors[2] = comp1
            sexActors[3] = comp2
        ElseIf comp1
            sexActors = new Actor[3]
            sexActors[2] = comp1
        Else
            sexActors = new Actor[2]
        EndIf
        sexActors[0] = akCreature
        sexActors[1] = akVictim
        ; GROUP-SIZE FALLBACK (explicit spec: "first 3 creatures, if not found 2, then 1"): animation
        ; packs often ship PAIR scenes for a creature type but nothing bigger — confirmed live with
        ; rieklings: the 4-actor pick found nothing, the scene was refused, and the retry pipeline
        ; re-grabbed the same victims every ~20s forever. Shrink until a scene exists.
        If iCreatureBackend == 2
            String pickTest = _PickOStimScene(sexActors, "aggressive")
            While pickTest == "" && sexActors.Length > 2
                Actor droppedComp
                If sexActors.Length == 4
                    droppedComp = comp2
                    comp2 = None
                    sexActors = new Actor[3]
                    sexActors[2] = comp1
                Else
                    droppedComp = comp1
                    comp1 = None
                    sexActors = new Actor[2]
                EndIf
                sexActors[0] = akCreature
                sexActors[1] = akVictim
                If droppedComp
                    _PrepGroupCompanion(droppedComp, False)
                EndIf
                _Log("[SNBaka] CreatureEscalate(" + akVictim.GetDisplayName() + "): no animation at that group size — retrying with " + sexActors.Length + " actors")
                pickTest = _PickOStimScene(sexActors, "aggressive")
            EndWhile
            If pickTest == ""
                ; Not even a PAIR animation exists for this creature type — a permanent content gap.
                ; Unwind like the refused-scene branch AND back this victim's pipeline off hard, or the
                ; grab->refuse->re-down loop hammers them every throttle window (the riekling report).
                _Log("[SNBaka] CreatureEscalate(" + akVictim.GetDisplayName() + "): NO OStim animation exists even for a pair with " + akCreature.GetDisplayName() + " — unwinding, 5-minute creature backoff for this victim")
                StorageUtil.SetFloatValue(akVictim, "SNBaka.LastCreatureAttemptRT", Utility.GetCurrentRealTime() + 300.0)
                _ProtectNearbyAllies(akVictim, akCreature, False)
                If comp1
                    _PrepGroupCompanion(comp1, False)
                EndIf
                Debug.SendAnimationEvent(akCreature, "staggerStart")
                Utility.Wait(0.3)
                Debug.SendAnimationEvent(akCreature, "IdleForceDefaultState")
                akCreature.EvaluatePackage()
                akVictim.SetGhost(False)
                StorageUtil.SetFormValue(akVictim, "SNBaka.GroundWindowAggressor", akCreature)
                _DelegateDownToAcheron(akVictim)
                UnlockBoth(akCreature, akVictim)
                Return
            EndIf
        EndIf
        ; The VICTIM is untouchable for the scene's whole duration, same rule as the struggle phase
        ; (_SetupPair) and the human scene path (_EscalationCleanup): the aggressor's own faction
        ; allies won't kill its prey — a stray ally hit whiffs instead of staggering the animation or
        ; feeding OStim a combat transition mid-thread. The CREATURE stays hittable on purpose: a
        ; genuine hit on IT (a rescuer interceding) is what's allowed to break the scene below.
        akVictim.SetGhost(True)
        ; Ghost stops the hits LANDING, but attackers still kept swinging at her for the whole scene
        ; (confirmed report). Acheron's pacify makes combat IGNORE her outright ("ignoring & ignored
        ; by combat" per its API) — they drop her as a target instead of whiffing forever. Scene-scoped:
        ; released right after the wait loop; the post-scene re-down (DefeatActor) re-pacifies her
        ; through Acheron's own defeat state anyway.
        _ProtectVictimTargeting(akVictim)
        ; PLAYER scenes: let the animation graph + control restore from the paired QTE finish settling
        ; before OStim builds its player thread. Confirmed CTD (11:15:03 crash log): OStim's AlignMenu
        ; dereferenced a null thread during scene start exactly 1s after CleanupPair re-enabled player
        ; controls — an OStim-internal race we can only starve, not fix. The final combat CTD guard
        ; inside _StartSexScene runs AFTER this wait, so nothing sneaks past it during the pause.
        If akVictim == PlayerRef
            Utility.Wait(1.0)   ; trimmed from 2.0 — the park makes scene-start state far more stable than the AlignMenu-crash era
        EndIf
        ; The PLAYER stays Acheron-defeated straight through the scene (OSimpleDefeat pattern —
        ; confirmed working live: 'BillyyGiantStandingService-4' ran with victimStillDowned=TRUE).
        ; A defeated NPC is a different story: OStim REJECTS them at thread start (confirmed live:
        ; Joylie's thread got 'actors array was None' and died within the same second — the giant
        ; just walked off). NPCs get the KEEP-PACIFIED rescue instead: the defeat ends, Acheron's
        ; pacify carries over seamlessly (RescueActor abRelease=false), zero targetable gap.
        If akVictim != PlayerRef && _IsDownedAny(akVictim)
            _ClearAcheronHold(akVictim, True, True)
            Utility.Wait(0.3)
        EndIf
        ; The SCENE ACTORS themselves get Acheron's two-way pacify for the scene's duration —
        ; "aggressors mid-animation must be pacified against ANYONE" (confirmed report: the giant on
        ; Claudia acquired the freshly-liberated Joylie as a combat target mid-scene, which tripped
        ; the abort rule and killed the animation). Ignoring & ignored: they can't acquire targets and
        ; nobody targets them. Released right after the wait loop. Known trade-off, per explicit
        ; direction: intercession-by-hit won't break a creature scene anymore (a pacified creature
        ; never re-targets its attacker, so the abort rule can't see the fight).
        If StorageUtil.GetIntValue(PlayerRef, "SNAcheron.Present", 0) == 1
            Acheron.PacifyActor(akCreature)
            If comp1
                Acheron.PacifyActor(comp1)
            EndIf
            If comp2
                Acheron.PacifyActor(comp2)
            EndIf
        EndIf
        _Log("[SNBaka] CreatureEscalate(" + akVictim.GetDisplayName() + "): STARTING creature sex scene (backend=" + iCreatureBackend + ", group size=" + sexActors.Length + ", victimStillDowned=" + _IsDownedAny(akVictim) + ")")
        ; Narrative parity for NPC victims (confirmed feedback: "for other npcs, llm do not get as many
        ; cues as with the player... sometimes it's a bit lost"): the LLM heard the pin start but NOT
        ; that the claim actually proceeded to a scene. Same eventType the pin cue used.
        SkyrimNetApi.RegisterEvent("baka_forced", \
            akCreature.GetDisplayName() + " overpowers the helpless " + akVictim.GetDisplayName() + " completely and claims them right there on the ground.", \
            akCreature, akVictim)
        Int stid = _StartSexScene(sexActors, akVictim, akCreature, "", "aggressive", iCreatureBackend)
        If stid < 0
            ; Scene never started (CTD-guard refusal or OStim failure). This return value used to be
            ; ignored: we fell into the wait loop for a scene that didn't exist and left the creature
            ; looping its pin animation FOREVER (confirmed 15:40:44 log — "REFUSED" then "entering wait
            ; loop"). Unwind like the combat-re-flare bail above, plus the explicit creature pose
            ; liberation the escape branch uses (IdleForceDefaultState alone doesn't reliably break a
            ; creature out of a paired pose). The victim stays Acheron-pacified into the re-down, so
            ; there's no targetable gap; ghost comes off because downed = vanilla mortality by design.
            _Log("[SNBaka] CreatureEscalate(" + akVictim.GetDisplayName() + "): scene never started (tid=" + stid + ") — unwinding, victim re-downed, creature pose reset")
            _ProtectNearbyAllies(akVictim, akCreature, False)
            If comp1
                _PrepGroupCompanion(comp1, False)
            EndIf
            If comp2
                _PrepGroupCompanion(comp2, False)
            EndIf
            Debug.SendAnimationEvent(akCreature, "staggerStart")
            Utility.Wait(0.3)
            Debug.SendAnimationEvent(akCreature, "IdleForceDefaultState")
            akCreature.EvaluatePackage()
            akVictim.SetGhost(False)
            StorageUtil.SetFormValue(akVictim, "SNBaka.GroundWindowAggressor", akCreature)
            _DelegateDownToAcheron(akVictim)
            UnlockBoth(akCreature, akVictim)
            Return
        EndIf
        _Log("[SNBaka] CreatureEscalate(" + akVictim.GetDisplayName() + "): _StartSexScene returned, entering wait loop")
        ; Wait for the scene to actually END before touching anything — this used to fall straight
        ; through to UnlockBoth the instant the scene was merely KICKED OFF, releasing the lock while
        ; OStim/SexLab was still mid-animation (the same "two systems fighting over one actor mid-scene"
        ; hazard _EscalationCleanup's own wait exists to avoid, on the human Escalate path).
        Utility.Wait(2.0)
        Int waited = 0
        Bool sceneCut = False
        ; Force-stop only when a REAL fight reaches the creature -- same refined rule as _ShouldAbort
        ; and the human scene path: combat STATE alone (its own faction alarm reacting to an ally
        ; attacking this very victim) doesn't count; only a live, non-downed combat target OTHER than
        ; the scene's own victim does -- that's what a genuine interceding hit produces (the creature's
        ; target switches to whoever hit it). A falmer does not kill another falmer's prey; an
        ; adventurer attacking the falmer very much still breaks the scene. The victim side isn't
        ; checked at all: they're ghosted above, nothing can land on them.
        While IsInSexAnimation(akVictim) && waited < 900 && !sceneCut   ; 15min hard cap, same as the human path
            Actor crT = akCreature.GetCombatTarget()
            If akCreature.IsInCombat() && crT && crT != akVictim && !crT.IsDead() && !crT.IsDisabled() && !_IsDownedAny(crT)
                _Log("[SNBaka] CreatureEscalate: " + akCreature.GetDisplayName() + " is in a real fight against " + crT.GetDisplayName() + " mid-scene — force-stopping")
                _StopSexScene(akVictim)
                sceneCut = True
            Else
                Utility.Wait(1.0)
                waited += 1
            EndIf
        EndWhile
        _ProtectNearbyAllies(akVictim, akCreature, False)
        ; End the scene-scoped two-way pacify on the scene actors (mirrors the PacifyActor calls at
        ; scene start). The aggressor's ONE-WAY pacify (_PacifyActor: aggression 0) stays until the
        ; victim's recovery un-pacifies the tracked threat, same as always.
        If StorageUtil.GetIntValue(PlayerRef, "SNAcheron.Present", 0) == 1
            Acheron.ReleaseActor(akCreature)
            If comp1
                Acheron.ReleaseActor(comp1)
            EndIf
            If comp2
                Acheron.ReleaseActor(comp2)
            EndIf
        EndIf
        ; Scene over: hold the ghost a few MERCY seconds more before dropping it (no spawn-kills the
        ; frame the protection ends), THEN release the scene-scoped pacify. The downed state that
        ; follows has no protection of its own by design -- vanilla mortality.
        _PostEscapeGrace(akVictim)   ; also ends the scene-scoped pacify; the re-down below re-pacifies via DefeatActor
        If comp1
            _PrepGroupCompanion(comp1, False)
        EndIf
        If comp2
            _PrepGroupCompanion(comp2, False)
        EndIf
        ; RE-DOWN after the creature scene, same as the human Escalate flow's _EscalationCleanup —
        ; missing here entirely before, which is why a victim just stood back up the moment a creature
        ; scene ended, with the creature possibly still standing right there and nothing checking for it.
        ; Re-track the creature as the aggressor for the renewed down cycle (GetCombatTarget() would find
        ; nothing, combat's long since stopped).
        If akVictim && !akVictim.IsDisabled()
            ; Clean graph reset BEFORE the re-down — OStim's own post-scene reset is async, and the
            ; expression addons fight the skeleton at this exact moment (OSED's broken node cleanup,
            ; see the error storm in the log). DefeatActor's collapse starting from a dirty graph is
            ; the intermittent "did not animate correctly after the scene" (frozen/odd pose instead
            ; of a collapse). Reset first, give the graph a beat, THEN hand them down.
            Debug.SendAnimationEvent(akVictim, "IdleForceDefaultState")
            Utility.Wait(0.5)
            StorageUtil.SetFormValue(akVictim, "SNBaka.GroundWindowAggressor", akCreature)
            _DelegateDownToAcheron(akVictim)
            ; POSE ENFORCEMENT: the delegate is async, and a graph fresh out of OStim regularly eats
            ; the native collapse — "defeated but just standing there, not moving" (confirmed report,
            ; still occurring after the pre-delegate reset alone). Give the defeat a beat to land,
            ; then force the vanilla bleedout pose; redundant when the native collapse took.
            If akVictim != PlayerRef
                Utility.Wait(1.5)
                If !akVictim.IsDead()
                    Debug.SendAnimationEvent(akVictim, "BleedoutStart")
                    _Log("[SNBaka] post-scene re-down: BleedoutStart enforced on " + akVictim.GetDisplayName())
                EndIf
            EndIf
        EndIf
    Else
        _Log("[SNBaka] CreatureEscalate(" + akVictim.GetDisplayName() + "): NO scene — succeed/combat gate failed (see outcome line above)")
        _ProtectNearbyAllies(akVictim, akCreature, False)   ; QTE-phase bystander hold ends here on the no-scene path
        ; Struggle WON but the fight's still on: leave her DOWNED (Acheron) so a beast can finish once
        ; combat ends, instead of starting sex mid-combat. If she escaped (not succeed), normal outcome.
        ; Applies to the player too now — skipping it there was the exact bug that let a struggled-down
        ; PC just stand back up mid-combat instead of staying tracked as downed.
        If succeed
            StorageUtil.SetFormValue(akVictim, "SNBaka.GroundWindowAggressor", akCreature)
            _DelegateDownToAcheron(akVictim)
        Else
            ; Victim BROKE FREE — winning the struggle is a genuine LIBERATION for everyone (updated
            ; spec: "Joylie won and she should have been liberated from all states and be free to
            ; attack back, and the giant should aggro her again after a few seconds"). Lift Acheron,
            ; end the one-way pacify, clear the tracked aggressor; the mercy ghost (_PostEscapeGrace,
            ; already run inside the struggle/QTE helper) covers the first seconds, then hostility
            ; resumes naturally — the aggressor's aggression came back in _CleanupPair, so the fight
            ; is back on shortly after the grace.
            If downed && _IsDownedAny(akVictim)
                _ClearAcheronHold(akVictim)
            EndIf
            _PacifyActor(akVictim, False)
            ; Revert every "lover"-rank anti-re-aggro link touching this victim — the current pair's
            ; AND stale ones left by past cycles (they were never reverted anywhere, so past victims
            ; stayed permanently non-hostile to their aggressors: part of why the liberated Joylie
            ; stood there doing nothing, and why the giant she broke free from attacked nobody).
            _ClearAggressorBonds(akVictim)
            StorageUtil.SetFormValue(akVictim, "SNBaka.GroundWindowAggressor", None)
            akVictim.EvaluatePackage()
            ; Narrative parity: without this the LLM never learned an NPC broke free — it last heard
            ; "X pins Y down" and then silence (the "it's a bit lost" report). baka_release is the
            ; existing freed-victim eventType (HelpUp/Release use it).
            SkyrimNetApi.RegisterEvent("baka_release", \
                akVictim.GetDisplayName() + " breaks free of " + akCreature.GetDisplayName() + "'s grip and struggles back to their feet — shaken, but free and ready to fight.", \
                akVictim, akCreature)
            _Log("[SNBaka] CreatureEscalate(" + akVictim.GetDisplayName() + "): victim broke free — fully liberated, fight may resume after the grace window")
            ; Creature LOST the struggle (victim broke free) -- explicitly make sure it's actually back
            ; on its feet and free to act, rather than just trusting PlayPairedSequence's own _CleanupPair
            ; reset to have fully taken. Belt-and-suspenders for the exact "falmer fell and got stuck"
            ; symptom reported in testing: it's the aggressor here, nothing else in this whole flow ever
            ; checks on IT specifically once it's lost, unlike the victim (who gets _DelegateDownToAcheron/
            ; Acheron's own recovery loop either way).
            ; A short beat first, per explicit feedback: firing this the SAME instant the victim's own
            ; concurrent _CleanupPair is still resolving (both threads unwind right on top of each other)
            ; is exactly the kind of race a stray stagger from still-active nearby combat can land in.
            ; Let things settle for a beat before re-asserting the pose (trimmed from 3.0s — "after
            ; winning ending, it's too long, 2 seconds are plenty" — combined with the mercy grace
            ; this keeps the whole win exit around the requested 2s).
            Utility.Wait(1.0)
            _HoldActorAI(akCreature, False)
            ; IdleForceDefaultState alone still left some creatures visibly stuck in the paired
            ; sequence's final frame (confirmed still happening in testing) -- staggerStart is the
            ; same trick _DefeatGroundWindow already relies on to force a real animation-state
            ; transition out of a held pose (see its "Stand Back" branch above), so borrow it here
            ; too instead of trusting the idle reset alone to break the graph out of it.
            Debug.SendAnimationEvent(akCreature, "staggerStart")
            Utility.Wait(0.3)
            Debug.SendAnimationEvent(akCreature, "IdleForceDefaultState")
            akCreature.EvaluatePackage()
            _Log("[SNBaka] CreatureEscalate(" + akVictim.GetDisplayName() + "): " + akCreature.GetDisplayName() + " lost the struggle -- explicit liberation (stagger + AI released, pose reset)")
        EndIf
        _CueResistOutcome("baka_forced", akCreature, akVictim)
    EndIf
    UnlockBoth(akCreature, akVictim)
EndFunction

; Player trigger: aim the interact power at a BEAST and it escalates on the nearest valid victim.
; Returns True if akCreature was a supported creature (i.e. we handled the power press), so the
; effect script knows to stop and not fall through to the normal interact menu.
Bool Function TryCreatureEscalateFromPower(Actor akCreature)
    If !bCreatureEscalation || !akCreature || _CreatureAnimKey(akCreature) == ""
        Return False
    EndIf
    Actor victim = _FindCreatureVictim(akCreature)
    If victim
        _DoCreatureEscalation(akCreature, victim)
    Else
        _Notify("No valid victim near " + akCreature.GetDisplayName() + ".")
    EndIf
    Return True
EndFunction

; Mod-event hook from Downed SkyrimNet (Acheron path): the player just went down in combat — give a
; nearby beast the chance to pounce, since creatures have no LLM brain to choose CreatureEscalate.
; Queued (AcheronIntegration/Downed_SkyrimNet FormListAdd the fresh victim to SNBaka.CreaturePounceQueue
; before sending this event) rather than hardcoded to PlayerRef, so an NPC victim gets the same chance
; for a nearby beast to pounce that the player does — same queue-drain pattern as OnDownRequest.
Event OnTryCreatureOnDowned(String eventName, String strArg, Float numArg, Form sender)
    _Log("[SNBaka] OnTryCreatureOnDowned fired (bCreatureEscalation=" + bCreatureEscalation + " bCreatureOnPlayer=" + bCreatureOnPlayer + " strArg=" + strArg + ")")
    Int cnt = StorageUtil.FormListCount(PlayerRef, "SNBaka.CreaturePounceQueue")
    Int i = 0
    While i < cnt
        Actor v = StorageUtil.FormListGet(PlayerRef, "SNBaka.CreaturePounceQueue", i) as Actor
        If v
            _TryCreatureEscalateOnDowned(v)
        EndIf
        i += 1
    EndWhile
    StorageUtil.FormListClear(PlayerRef, "SNBaka.CreaturePounceQueue")
EndEvent

; Passive creature initiator: a human is DOWN — if the creature opt-in is on, a supported creature is
; nearby, and the chance roll passes, it takes the opportunity. Clears an Acheron bleedout first so the
; paired creature animation positions correctly.
; Combat-gated up front now (see _CombatNear check below) -- confirmed in testing that letting the
; struggle happen mid-combat and only gating the SEX portion on _CombatNear (in _DoCreatureEscalation)
; wasn't just a pacing issue: starting the OStim scene right as combat state is still settling crashed
; the game inside OStim's own AlignMenu code (null actor alignment). Waiting for combat to actually clear
; before even attempting the struggle gives the engine breathing room before OStim's thread is touched.
; The retry mechanisms already in place (Baka's own re-trigger, Acheron's periodic re-roll) mean this
; just quietly waits and tries again later instead of failing outright.
Function _TryCreatureEscalateOnDowned(Actor akVictim)
    _Log("[SNBaka] _TryCreatureEscalateOnDowned ENTER: victim=" + akVictim + " escOn=" + bCreatureEscalation + " onPlayer=" + bCreatureOnPlayer)
    If !bCreatureEscalation
        _Log("[SNBaka] creature: master switch (bCreatureEscalation) is OFF — enable it in the MCM")
        Return
    EndIf
    If !akVictim || akVictim.IsDead() || IsActorLocked(akVictim)
        _Log("[SNBaka] creature: victim none/dead/locked (locked=" + IsActorLocked(akVictim) + ")")
        Return
    EndIf
    ; SNBaka.Locked (checked above) covers scenes WE started, but a victim can be in an OStim/SexLab
    ; scene some other mod started (never Locked by us) -- explicit spec: a downed actor mid-scene is
    ; never a pounce candidate, whoever owns the scene.
    If IsInSexAnimation(akVictim)
        _Log("[SNBaka] creature: victim is in a sex scene — never a pounce candidate mid-scene")
        Return
    EndIf
    If akVictim == PlayerRef && !bCreatureOnPlayer
        _Log("[SNBaka] creature: player victim but bCreatureOnPlayer is OFF — enable it in the MCM")
        Return
    EndIf
    If !_IsDownedAny(akVictim)
        _Log("[SNBaka] creature: victim not downed (OnGround=" + StorageUtil.GetIntValue(akVictim, "SNBaka.OnGround", 0) + " bleeding=" + akVictim.IsBleedingOut() + " acheronHeld=" + StorageUtil.GetIntValue(akVictim, "SNAcheron.Held", 0) + ")")
        Return
    EndIf
    ; Confirmed real bug from testing: a struggle grabbing someone WHILE they're still mid down-transition
    ; (the bleedout/collapse animation hasn't settled) can break the animation state and leave them stuck
    ; perpetually "downing". SNAcheron.FreshDownRT is the shared stamp Acheron's own _CueDowned/
    ; Downed_SkyrimNet.RunConsequence set at the exact moment of a genuinely fresh down (0.0 default if
    ; Acheron isn't installed or this is a pure Baka-native down, which trivially passes this check).
    Float sinceFreshDown = Utility.GetCurrentRealTime() - StorageUtil.GetFloatValue(akVictim, "SNAcheron.FreshDownRT", 0.0)
    If sinceFreshDown < fFreshDownGraceDuration
        _Log("[SNBaka] creature: blocked — " + akVictim.GetDisplayName() + " only " + sinceFreshDown + "s since fresh down, need " + fFreshDownGraceDuration + "s to settle first")
        Return
    EndIf
    ; NOTE: deliberately NOT checking _InDefeatGrace here. That grace window exists to stop a fresh
    ; mid-combat on-hit spam from chaining a second struggle onto the first with zero breathing room
    ; (see OnCreatureHitFollower) -- it is NOT meant to also block the separate, explicitly-requested
    ; "once on the ground, still fair game to nearby proximity actors" behavior this function provides.
    ; Confirmed in testing: applying it here silently ate every downed re-consideration attempt for
    ; the whole 100s window right after a fresh takedown, exactly when a downed victim should still be
    ; up for grabs.
    ; Only the VICTIM's own live combat state gates the struggle attempt now -- an unrelated fight
    ; happening elsewhere in the cell used to block this outright (_CombatNear scanned the whole cell
    ; out to 3000 units), which meant a creature standing right next to an already-downed, defenseless
    ; victim could never even consider her while allies were still busy with a DIFFERENT enemy nearby.
    ; The actual OStim-mid-combat crash this was guarding against is a SCENE-START hazard, not a
    ; struggle hazard -- that gate still exists further down (see the _CombatNear call before
    ; _StartSexScene). The chosen candidate's own combat state is re-checked once "best" is found below.
    If _HasLiveCombatTarget(akVictim)
        _Log("[SNBaka] creature: blocked — " + akVictim.GetDisplayName() + " still has a live combat target, waiting for it to clear before even attempting")
        Return
    EndIf
    ; A beat between attempts — confirmed in testing that a "succeed but combat still near" outcome
    ; re-downs the victim, which immediately re-fires this same event with zero delay, chaining a second
    ; full struggle QTE onto the first with no breathing room at all. This throttles ANY re-entry
    ; (initial pounce, the "loop" re-check, or this kind of immediate re-trigger) to once per few seconds.
    Float now = Utility.GetCurrentRealTime()
    Float lastAttempt = StorageUtil.GetFloatValue(akVictim, "SNBaka.LastCreatureAttemptRT", 0.0)
    If (now - lastAttempt) < 3.0
        _Log("[SNBaka] creature: skipped — only " + (now - lastAttempt) + "s since last attempt, need 3.0s")
        Return
    EndIf
    StorageUtil.SetFloatValue(akVictim, "SNBaka.LastCreatureAttemptRT", now)
    Actor best        = None
    Float bestDist    = 1500.0
    ; Fast path, Yamete Redux style: whoever/whatever downed this victim is already a known reference
    ; (SNBaka.GroundWindowAggressor, set at down-time) — check it directly with GetDistance() before
    ; falling back to the cell sweep below for a DIFFERENT creature that merely wandered up afterward.
    ; Used to lead with Game.FindClosestActorFromRef for cross-cell reach, but that proved unreliable
    ; in testing (same false negative that hit _AnyActorNear).
    Actor threat = StorageUtil.GetFormValue(akVictim, "SNBaka.GroundWindowAggressor") as Actor
    ; Distance check added here — this used to accept the tracked reference unconditionally regardless
    ; of how far away it actually was, letting a creature that had wandered far off still win the "best"
    ; slot (nothing else would beat its huge bestDist unless something closer also happened to be found).
    If threat && threat != akVictim && !threat.IsDead() && !_IsDownedAny(threat) && akVictim.GetDistance(threat) < bestDist
        _Log("[SNBaka] tracked threat: '" + threat.GetDisplayName() + "' key='" + _CreatureAnimKey(threat) + "' locked=" + IsActorLocked(threat) + " dist=" + akVictim.GetDistance(threat))
        ; Check _CreatureAnimKey FIRST, not _IsCreatureActor — Falmer and Draugr are creature-behaving
        ; races that Bethesda still tags with the ActorTypeNPC keyword (the same one every human uses),
        ; so _IsCreatureActor(falmer) reads False. _CreatureAnimKey matches by actual race name and isn't
        ; fooled by that; a race-name match here means it's a supported creature no matter what keyword
        ; it carries.
        If _CreatureAnimKey(threat) != ""
            If threat != PlayerRef && !IsActorLocked(threat)
                best     = threat
                bestDist = akVictim.GetDistance(threat)
            EndIf
        EndIf
        ; A tracked HUMANOID here is deliberately NOT a blocker anymore -- see the witness-rule removal
        ; note on the sweep below.
    EndIf
    ; LOADED-AREA enumeration (po3 Papyrus Extender), not a single-cell sweep: dens and camps span
    ; linked cells, and the victim's own parent cell repeatedly turned up empty of creatures standing
    ; right next to them (confirmed 16:03 session: every player-victim scan logged "no supported
    ; creature near Claudia" while a falmer stood in grabbing range — it was registered in a different
    ; cell, and only Joylie's tracked-aggressor fast path ever found it). Processing level 0 = every
    ; AI-active actor currently loaded, no cell dependence. The old single-closest-actor cross-cell
    ; supplement is gone with it — it only ever sampled ONE actor, usually the other downed follower.
    Actor[] loaded = PO3_SKSEFunctions.GetActorsByProcessingLevel(0)
    Int total = loaded.Length
    Int i = 0
    While i < total
        Actor a = loaded[i]
        If a && a != akVictim && a != PlayerRef && !a.IsDead()
            String ck = _CreatureAnimKey(a)
            If ck != ""
                ; Log every nearby beast we recognise, so we can see what's around when testing.
                _Log("[SNBaka] nearby creature: '" + a.GetDisplayName() + "' key=" + ck + " inCombat=" + a.IsInCombat() + " locked=" + IsActorLocked(a) + " dist=" + a.GetDistance(akVictim))
                If !IsActorLocked(a) && a.GetDistance(akVictim) < bestDist
                    bestDist = a.GetDistance(akVictim)
                    best = a
                EndIf
            EndIf
            ; The humanoid-WITNESS rule that used to live here (any live, non-downed humanoid within
            ; 1500u blocked the attempt entirely) stays REMOVED per explicit spec — the MCM engagement
            ; chance is the only frequency throttle.
        EndIf
        i += 1
    EndWhile
    If !best
        _Log("[SNBaka] _TryCreatureEscalateOnDowned: no supported creature near " + akVictim.GetDisplayName())
        Return
    EndIf
    ; The candidate itself might still be genuinely mid-fight with someone else even though the victim
    ; (checked above) isn't -- don't pull it out of a real fight to do this.
    If _HasLiveCombatTarget(best)
        _Log("[SNBaka] _TryCreatureEscalateOnDowned: found " + best.GetDisplayName() + " but it's still actively fighting someone else")
        Return
    EndIf
    ; No success roll here anymore -- iCreatureSuccessPct is _DoCreatureEscalation's OWN roll (used for
    ; both the not-yet-downed struggle AND, now, the already-downed claim). Rolling a SEPARATE "does the
    ; creature even bother" gate here would double up with that AND with Acheron's own
    ; fCreatureEngageChance roll (the actual, correct throttle on how often this pipeline gets a shot at
    ; all) -- confirmed in testing as a victim left downed for a long time
    ; with nearby creatures repeatedly declining her purely on this redundant coin flip. A creature that
    ; actually finds and commits to an already-downed victim now always takes her, same as the guaranteed
    ; branch _DoCreatureEscalation already has for this exact case.
    ; The downed/hold state is cleared inside _DoCreatureEscalation itself, only once every one of its
    ; own gates (sex restriction, anim key, lock race, etc.) has actually passed — see its comment.
    ; LLM ESCALATION GATE (MCM opt-in): instead of committing automatically, describe the moment to
    ; SkyrimNet and let the LLM answer YES/NO from context (pacing, who's present, what just happened).
    ; Async: stash the pair, fire the prompt, continue in OnEscalationGateResponse. Fail-OPEN — an LLM
    ; outage or template failure behaves like the gate is off; it's advisory, not a kill-switch.
    If bLLMGateEscalation
        Float nowG = Utility.GetCurrentRealTime()
        If _bGatePending && (nowG - _fGateSentRT) < 30.0
            _Log("[SNBaka] _TryCreatureEscalateOnDowned: LLM gate already pending — skipping duplicate ask")
            Return
        EndIf
        _bGatePending = True
        _fGateSentRT  = nowG
        _gateCreature = best
        _gateVictim   = akVictim
        String ctx = "{\"creatureName\":\"" + best.GetDisplayName() + "\",\"victimName\":\"" + akVictim.GetDisplayName() + "\",\"maxRecentEvents\":20}"
        Int sent = SkyrimNetApi.SendCustomPromptToLLM("snbaka_escalation_gate", "", ctx, Self as Quest, "SkyrimNet_BakaIntegration", "OnEscalationGateResponse")
        _Log("[SNBaka] _TryCreatureEscalateOnDowned: LLM gate asked (" + best.GetDisplayName() + " -> " + akVictim.GetDisplayName() + "), sent=" + sent)
        If sent != 1
            _bGatePending = False
            _DoCreatureEscalation(best, akVictim)   ; couldn't even queue the ask — fail open
        EndIf
        Return
    EndIf
    _Log("[SNBaka] _TryCreatureEscalateOnDowned: " + best.GetDisplayName() + " attempts downed " + akVictim.GetDisplayName())
    _DoCreatureEscalation(best, akVictim)
EndFunction

; SendCustomPromptToLLM callback for the escalation gate (snbaka_escalation_gate.prompt asks for a
; single-word YES/NO). success 1 = real answer; 0 = render/network failure, which fails OPEN.
Function OnEscalationGateResponse(String response, Int success)
    Actor c = _gateCreature
    Actor v = _gateVictim
    _gateCreature = None
    _gateVictim   = None
    _bGatePending = False
    If !c || !v
        Return
    EndIf
    Bool allow = True
    If success == 1
        allow = StringUtil.Find(response, "YES") >= 0 || StringUtil.Find(response, "Yes") >= 0 || StringUtil.Find(response, "yes") >= 0
        _Log("[SNBaka] OnEscalationGateResponse: LLM said '" + response + "' -> allow=" + allow)
    Else
        _Log("[SNBaka] OnEscalationGateResponse: gate errored ('" + response + "') — failing OPEN")
    EndIf
    If !allow
        ; A NO backs this victim's pipeline off ~30s (vs the usual 3s retry) so the same question isn't
        ; peppered at the LLM every engagement roll. Stamping the last-attempt clock into the future
        ; extends the existing throttle without a new key.
        StorageUtil.SetFloatValue(v, "SNBaka.LastCreatureAttemptRT", Utility.GetCurrentRealTime() + 27.0)
        Return
    EndIf
    ; The answer took real seconds — re-validate the moment before committing.
    If v.IsDead() || c.IsDead() || !_IsDownedAny(v) || IsActorLocked(c) || IsActorLocked(v)
        _Log("[SNBaka] OnEscalationGateResponse: situation changed while the LLM was thinking — dropping")
        Return
    EndIf
    _DoCreatureEscalation(c, v)
EndFunction

; Native hit-event hook (HitEventSink.cpp): a creature just landed a melee hit on a player-teammate
; (follower) OR the player themselves. Unlike _TryCreatureEscalateOnDowned, this fires straight off
; the hit -- no need for the victim to be downed first, which is the whole point (mid-combat
; escalation). Aggressor resolution differs by victim: a follower has real AI combat targeting, so
; GetCombatTarget() is reliable; the player doesn't necessarily, so SNBakaUI.GetLastHitAggressor asks
; the native side for the actual hit-event cause instead (cached at the exact moment it fired).
; AND-gated: bCreatureEscalateFollowersOnHit AND bCreatureCombatAllowed here, plus bCreatureOnPlayer
; when the victim is the player, then _DoCreatureEscalation's own master switch/sex filter/lock checks
; -- every one of them has to agree, turn any single one off and this never fires. The 3s throttle is
; shared with _TryCreatureEscalateOnDowned's own (same victim, same purpose: don't chain a second full
; struggle onto the first with zero breathing room).
Event OnCreatureHitFollower(string eventName, string strArg, float numArg, Form sender)
    _Log("[SNBaka] OnCreatureHitFollower ENTER: sender=" + sender + " followerToggle=" + bCreatureEscalateFollowersOnHit + " combatAllowed=" + bCreatureCombatAllowed)
    If !bCreatureEscalateFollowersOnHit || !bCreatureCombatAllowed
        _Log("[SNBaka] OnCreatureHitFollower: blocked — bCreatureEscalateFollowersOnHit or bCreatureCombatAllowed is off in MCM")
        Return
    EndIf
    Actor victim = sender as Actor
    If !victim
        _Log("[SNBaka] OnCreatureHitFollower: blocked — sender wasn't an Actor")
        Return
    EndIf
    If victim.IsDead() || IsActorLocked(victim)
        _Log("[SNBaka] OnCreatureHitFollower: blocked — victim=" + victim.GetDisplayName() + " dead=" + victim.IsDead() + " locked=" + IsActorLocked(victim))
        Return
    EndIf
    If IsInSexAnimation(victim)
        _Log("[SNBaka] OnCreatureHitFollower: blocked — " + victim.GetDisplayName() + " is mid sex scene (any framework/any mod)")
        Return
    EndIf
    Bool victimIsPlayer = (victim == PlayerRef)
    If victimIsPlayer && !bCreatureOnPlayer
        _Log("[SNBaka] OnCreatureHitFollower: blocked — player victim but bCreatureOnPlayer is OFF in MCM")
        Return
    EndIf
    If _InDefeatGrace(victim)
        _Log("[SNBaka] OnCreatureHitFollower: blocked — " + victim.GetDisplayName() + " is still in their post-defeat grace window")
        Return
    EndIf
    ; GetCombatTarget() first for a follower (usually right, no native round-trip needed) but fall back
    ; to the native hit-cache either way -- confirmed in testing that a follower JUST released from a
    ; struggle/pairing can read a stale/empty GetCombatTarget() for a beat even though a fresh hit just
    ; landed (StopCombat()-heavy cleanup a moment earlier hadn't been re-acquired by AI yet). The native
    ; cache is ground truth from the actual hit event regardless of victim type.
    Actor aggressor = None
    If !victimIsPlayer
        aggressor = victim.GetCombatTarget()
    EndIf
    If !aggressor
        aggressor = SNBakaUI.GetLastHitAggressor(victim)
    EndIf
    If !aggressor
        _Log("[SNBaka] OnCreatureHitFollower: blocked — could not resolve an aggressor for " + victim.GetDisplayName())
        Return
    EndIf
    If aggressor.IsDead()
        _Log("[SNBaka] OnCreatureHitFollower: blocked — aggressor=" + aggressor.GetDisplayName() + " is dead")
        Return
    EndIf
    ; Which pipeline handles this aggressor? A supported creature takes the creature path below; a
    ; HUMANOID takes the human on-hit path (own MCM toggle/chance, dispatches to the ordinary Struggle
    ; action); an unsupported creature type (horker, rabbit...) takes neither.
    String aggKey = _CreatureAnimKey(aggressor)
    Bool humanPath = False
    If aggKey == ""
        If !bHumanEscalateOnHit || _IsCreatureActor(aggressor)
            _Log("[SNBaka] OnCreatureHitFollower: blocked — aggressor=" + aggressor.GetDisplayName() + " not a supported creature (humanOnHit=" + bHumanEscalateOnHit + " isCreature=" + _IsCreatureActor(aggressor) + ")")
            Return
        EndIf
        If _IsDownedAny(aggressor) || IsActorLocked(aggressor)
            _Log("[SNBaka] OnCreatureHitFollower: blocked — humanoid aggressor " + aggressor.GetDisplayName() + " is downed/locked")
            Return
        EndIf
        ; Friendly-fire guard, humanoid path only -- the native hit sink fires for ANY non-player
        ; aggressor, and the log shows followers landing stray hits on each other mid-melee (Joylie
        ; showing up as "aggressor" against Claudia). A creature reaching this handler is essentially
        ; always a real enemy; a humanoid needs the actual hostility check or allies would grapple
        ; each other off accidental hits.
        If !aggressor.IsHostileToActor(victim)
            _Log("[SNBaka] OnCreatureHitFollower: blocked — humanoid " + aggressor.GetDisplayName() + " is not hostile to " + victim.GetDisplayName() + " (stray/friendly hit)")
            Return
        EndIf
        humanPath = True
    EndIf
    ; Player + OStim-buggy-combat carve-out: OStim can crash if combat resettles while its own thread
    ; is running (confirmed via CrashLoggerSSE earlier), so for the player specifically, when OStim
    ; would be the resolved backend, don't even ATTEMPT the struggle while combat is still live for
    ; them -- wait for it to clear first. NPCs, and player+SexLab, keep the existing behavior: the
    ; struggle can start mid-combat, only the SCENE itself waits for combat to clear (_CombatNear
    ; before _StartSexScene). Creature-path only: a human struggle never chains straight into a scene
    ; (a lost struggle ends in the ground window; the scene needs a separate, already combat-gated
    ; Escalate), so there's no OStim thread at risk on that path.
    If !humanPath && victimIsPlayer && _ResolveSexBackend(iCreatureBackend) == 2 && _HasLiveCombatTarget(victim)
        _Log("[SNBaka] OnCreatureHitFollower: blocked — player + OStim backend, waiting for combat to clear first")
        Return
    EndIf
    ; Shared per-victim throttle across BOTH paths (same key), so a creature and a human can't chain
    ; grabs on the same victim back-to-back.
    Float now = Utility.GetCurrentRealTime()
    Float lastAttempt = StorageUtil.GetFloatValue(victim, "SNBaka.LastCreatureAttemptRT", 0.0)
    If (now - lastAttempt) < 3.0
        _Log("[SNBaka] OnCreatureHitFollower: blocked — only " + (now - lastAttempt) + "s since last attempt on " + victim.GetDisplayName() + ", need 3.0s")
        Return
    EndIf
    StorageUtil.SetFloatValue(victim, "SNBaka.LastCreatureAttemptRT", now)
    Int need = iCreatureHitEngageChance
    If humanPath
        need = iHumanHitEngageChance
    EndIf
    Int roll = Utility.RandomInt(1, 100)
    If roll > need
        _Log("[SNBaka] OnCreatureHitFollower: skipped by chance roll — rolled " + roll + ", need <= " + need + " (humanPath=" + humanPath + ")")
        Return
    EndIf
    If humanPath
        _Log("[SNBaka] OnCreatureHitFollower: humanoid " + aggressor.GetDisplayName() + " hit " + victim.GetDisplayName() + " -- attempting mid-combat Struggle (rolled " + roll + ")")
        ; The ordinary Struggle action: QTE for a player victim, timed roll for NPCs, ground window on
        ; a loss -- every existing Struggle gate (IsEligible: master switch, sex filter, player-target
        ; permission, locks) still applies and traces its own rejection if it blocks. abFromHit=True
        ; relaxes only IsEligible's attacker-in-combat gate, which would otherwise reject every on-hit
        ; attempt by definition (the attacker just landed a combat hit).
        Struggle_Execute(aggressor, victim, True)
    Else
        _Log("[SNBaka] OnCreatureHitFollower: " + aggressor.GetDisplayName() + " hit " + victim.GetDisplayName() + " -- attempting mid-combat escalation (rolled " + roll + ")")
        _DoCreatureEscalation(aggressor, victim)
    EndIf
EndEvent

; Nearest valid human near the creature: not a creature, alive, victim-sex allowed, player only if
; permitted, and (when combat escalation is off) already downed/bleeding out.
Actor Function _FindCreatureVictim(Actor akCreature)
    Cell c = akCreature.GetParentCell()
    If !c
        Return None
    EndIf
    Bool needDowned = !bCreatureCombatAllowed
    Actor best     = None
    Float bestDist = 99999.0
    Int total = c.GetNumRefs(62)
    Int i = 0
    While i < total
        Actor a = c.GetNthRef(i, 62) as Actor
        If a && a != akCreature && !a.IsDead() && _CreatureAnimKey(a) == ""
            Bool ok = True
            If a == PlayerRef && !bCreatureOnPlayer
                ok = False
            EndIf
            If ok
                Bool female = a.GetActorBase().GetSex() == 1
                ; 0 = Both, 1 = Female only, 2 = Male only (same scheme as iTargetSex).
                If (iCreatureVictimSex == 1 && !female) || (iCreatureVictimSex == 2 && female)
                    ok = False
                EndIf
            EndIf
            If ok && needDowned
                If !_IsDownedAny(a)
                    ok = False
                EndIf
            EndIf
            If ok
                Float d = akCreature.GetDistance(a)
                If d < bestDist
                    bestDist = d
                    best = a
                EndIf
            EndIf
        EndIf
        i += 1
    EndWhile
    Return best
EndFunction

; ============================================================
; SOLO POSES (SNBaka_Pose) — single-actor, LLM-driven idle / gesture / submission
; ============================================================
; Play one anim event on an NPC and hold it (re-asserted each tick) for fSoloPoseDuration, ending
; early on combat or death. Mirrors the paired-hold approach but for a single actor, no positioning.
; bLockMove = SetDontMove (for kneel/grovel a bump shouldn't break). Never the player.
Function _PlaySoloHold(Actor ak, String animEvent, Bool bLockMove = False)
    If !ak || ak == PlayerRef || ak.IsDead() || ak.IsInCombat()
        Return
    EndIf
    _HoldActorAI(ak, True)
    _PacifyActor(ak, True)
    ak.SetRestrained(True)
    If bLockMove
        ak.SetDontMove(True)
    EndIf
    Debug.SendAnimationEvent(ak, "IdleForceDefaultState")
    Utility.Wait(0.15)
    Float elapsed = 0.0
    Float tick    = 2.0
    Bool aborted  = False
    While elapsed < fSoloPoseDuration && !aborted
        Debug.SendAnimationEvent(ak, animEvent)              ; re-assert so nothing drifts them off it
        Float step = tick
        If elapsed + step > fSoloPoseDuration
            step = fSoloPoseDuration - elapsed
        EndIf
        ; _WaitOrAbort polls _ShouldAbort every 0.5s: death, disabled, combat (attacked), teleport, stop.
        aborted = _WaitOrAbort(ak, ak, step)
        elapsed += step
    EndWhile
    ; Cleanup ALWAYS runs (incl. on abort/death) so the actor is never left restrained/pacified/ghosted.
    ak.SetRestrained(False)
    If bLockMove
        ak.SetDontMove(False)
    EndIf
    _PacifyActor(ak, False)
    _HoldActorAI(ak, False)
    Debug.SendAnimationEvent(ak, "IdleForceDefaultState")
    ak.EvaluatePackage()
EndFunction

; --- SkyrimNet pose action (single param dispatcher; replaces the old one-yaml-per-pose set) ---
; poseName selects the clip; PoseAroused/PoseDrink/PoseFood keep their own functions below since
; they carry real extra logic (gendered variants, blackout/reaction rolls) beyond a plain hold.
Function Pose_Execute(Actor akInitiator, String poseName)
    _Log("[SNBakaACT] Pose ENTER poseName=" + poseName)
    If poseName == "Aroused"
        PoseAroused_Execute(akInitiator)
        Return
    ElseIf poseName == "Drink"
        PoseDrink_Execute(akInitiator)
        Return
    ElseIf poseName == "Food"
        PoseFood_Execute(akInitiator)
        Return
    EndIf
    String anim = ""
    Bool lockMove = False
    If poseName == "Kneel"
        anim = "Babo_Kneel"
        lockMove = True
    ElseIf poseName == "Dogeza"
        anim = "Babo_Dogeja"
        lockMove = True
    ElseIf poseName == "Meditate"
        anim = "BaboMeditate"
    ElseIf poseName == "Crouch"
        anim = "BaboCrouchM"
    ElseIf poseName == "Sleep"
        anim = "BaboSleeponBedRoll"
        lockMove = True
    ElseIf poseName == "ScratchHead"
        anim = "BaboIdleScratchingHead"
    ElseIf poseName == "BraceArm"
        anim = "BaboIdleHoldon"
    ElseIf poseName == "HandOnFace"
        anim = "BaboHandonFace"
    ElseIf poseName == "HandOnChin"
        anim = "BaboHandonChin"
    ElseIf poseName == "Drool"
        anim = "BaboDroolingFace"
    ElseIf poseName == "Autograph"
        anim = "BaboAutograph"
    ElseIf poseName == "Pickpocket"
        anim = "BaboExPocketPullout"
    EndIf
    If anim == ""
        _Log("[SNBaka] Pose_Execute: unrecognized poseName '" + poseName + "'")
        Return
    EndIf
    RecordAnimation(akInitiator, "Pose" + poseName, "")
    _PlaySoloHold(akInitiator, anim, lockMove)
EndFunction

; Arousal idle — gendered clip (male/female variants), random of two.
Function PoseAroused_Execute(Actor akInitiator)
    _Log("[SNBakaACT] PoseAroused ENTER")
    RecordAnimation(akInitiator, "PoseAroused", "")
    String ev
    If akInitiator.GetActorBase().GetSex() == 1   ; female
        If Utility.RandomInt(1, 2) == 1
            ev = "BaboArousedFemale01"
        Else
            ev = "BaboArousedFemale02"
        EndIf
    Else
        If Utility.RandomInt(1, 2) == 1
            ev = "BaboArousedMale01"
        Else
            ev = "BaboArousedMale02"
        EndIf
    EndIf
    _PlaySoloHold(akInitiator, ev, False)
EndFunction

; Drink (female): normally just a drinking idle, but with iDrinkBlackoutChance% she drinks herself
; into a stupor and slumps unconscious — pacified + held, and a baka_opportunity cue invites a nearby
; malicious NPC's DrunkExploit / the player's power. (Blackout is a Start->Loop sequence, so it is sent
; ONCE and held without re-asserting — _PlaySoloHold's per-tick re-assert would restart the intro.)
Function PoseDrink_Execute(Actor akInitiator)
    _Log("[SNBakaACT] PoseDrink ENTER")
    If !akInitiator || !HasFemaleBody(akInitiator) || akInitiator == PlayerRef
        Return
    EndIf
    RecordAnimation(akInitiator, "PoseDrink", "")
    If Utility.RandomInt(1, 100) <= iDrinkBlackoutChance
        SkyrimNetApi.RegisterEvent("baka_opportunity", \
            akInitiator.GetDisplayName() + " has drunk herself into a stupor and slumped down — helpless, defenseless and unaware.", \
            akInitiator, None)
        _HoldActorAI(akInitiator, True)
        _PacifyActor(akInitiator, True)
        akInitiator.SetRestrained(True)
        akInitiator.SetDontMove(True)
        Debug.SendAnimationEvent(akInitiator, "IdleForceDefaultState")
        Utility.Wait(0.15)
        Debug.SendAnimationEvent(akInitiator, "BaboDrinkBlackOut")   ; Start -> BlackOutLoop; held, not re-asserted
        _WaitOrAbort(akInitiator, akInitiator, fSoloPoseDuration)
        akInitiator.SetRestrained(False)
        akInitiator.SetDontMove(False)
        _PacifyActor(akInitiator, False)
        _HoldActorAI(akInitiator, False)
        Debug.SendAnimationEvent(akInitiator, "IdleForceDefaultState")
        akInitiator.EvaluatePackage()
    Else
        _PlaySoloHold(akInitiator, "BaboDrinkNormal", False)
    EndIf
EndFunction

; Food (female): a reaction idle — eats anyway, or recoils in disgust (random). Pure flavor.
Function PoseFood_Execute(Actor akInitiator)
    _Log("[SNBakaACT] PoseFood ENTER")
    If !akInitiator || !HasFemaleBody(akInitiator)
        Return
    EndIf
    RecordAnimation(akInitiator, "PoseFood", "")
    String ev = "Babo_FoodEatAnyway"
    If Utility.RandomInt(1, 2) == 2
        ev = "Babo_FoodDisgusting"
    EndIf
    _PlaySoloHold(akInitiator, ev, False)
EndFunction

; ============================================================
; SPANK SYSTEM (merged from SkyrimNet_SlapDaButt)
; ============================================================

; ---- Tat fade timer ----
; Decorators live in SkyrimNet's runtime memory and are NOT saved with the game, so they
; must be re-asserted on every load. The quest's OnPlayerLoadGame never fires (Quest scripts
; don't receive it), so we re-register here from the persistent game-time heartbeat below as
; well as on first init. RegisterDecorator is idempotent, so re-calling is harmless.
; Mod-event listeners (RegisterForModEvent) do NOT persist across save/load and Setup()'s
; OnPlayerLoadGame doesn't fire on a Quest — so, like the decorators, they must be re-asserted from the
; persistent game-time self-heal (OnUpdateGameTime). Without this the creature hand-off (and AEL/menu
; events) silently stop working after the first reload. Idempotent, so re-calling is harmless.
Function _RegisterModEvents()
    RegisterForModEvent("AEL_GameEnd",                "OnAELGameEnd")
    RegisterForModEvent("SNBaka_MenuChoice",          "OnSNBakaMenuChoice")
    RegisterForModEvent("SNBaka_TryCreatureOnDowned", "OnTryCreatureOnDowned")
    RegisterForModEvent("SNBaka_CreatureHitFollower", "OnCreatureHitFollower")
    RegisterForModEvent("SNAcheron_RequestForceRecover", "OnAcheronForceRecoverRequest")
    RegisterForModEvent("SNBaka_DefeatedExecuted",       "OnDefeatedExecuted")
    RegisterForModEvent("SNAcheron_HunterPrideChoice", "OnHunterPrideChoice")
    ; Mirrors SNAcheron.Present (set by the Acheron bridge) — lets Acheron's standalone install detect
    ; whether we're actually here to answer SNBaka_TryCreatureOnDowned before it bothers waiting on us.
    If PlayerRef
        StorageUtil.SetIntValue(PlayerRef, "SNBaka.Present", 1)
        _Log("[SNBaka] _RegisterModEvents: SNBaka.Present set to 1 on " + PlayerRef + " (readback=" + StorageUtil.GetIntValue(PlayerRef, "SNBaka.Present", -99) + ")")
    Else
        _Log("[SNBaka] _RegisterModEvents: PlayerRef is None -- SNBaka.Present NOT set this call")
    EndIf
EndFunction

; Acheron's player self-recovery QTE (hold-key) asks us to force-recover an actor it can't fully clean
; up itself (e.g. it was Baka's own local ground window holding them, not an Acheron hold) — same
; queue-drain pattern as every other cross-mod request here. _ForceRecover is a no-op if the actor
; wasn't downed by us in the first place, so this is safe to call regardless of who actually held them.
; Native hit sink (HitEventSink.cpp): a PHYSICAL hit landed on an Acheron-DEFEATED non-player actor.
; Vanilla-mortality spec for the helpless — a deliberate strike on a defeated body kills it. The kill
; is applied HERE (not natively) so the remaining protections still count: essential/protected actors
; survive (Actor.Kill respects the essential flag), and anyone locked in one of our interactions or a
; sex scene is exempt (their ghost normally stops the hit ever registering; belt and suspenders).
Event OnDefeatedExecuted(String eventName, String strArg, Float numArg, Form sender)
    Actor victim = sender as Actor
    If !victim || victim.IsDead() || victim == PlayerRef
        Return
    EndIf
    If IsActorLocked(victim) || IsInSexAnimation(victim)
        Return
    EndIf
    _Log("[SNBaka] OnDefeatedExecuted: " + victim.GetDisplayName() + " takes a killing blow while defeated")
    SkyrimNetApi.RegisterEvent("baka_execution", \
        victim.GetDisplayName() + " is struck while lying defeated on the ground — the blow is final.", \
        None, victim)
    StorageUtil.SetIntValue(victim, "SNAcheron.Held", 0)   ; release our claim so nothing fights the corpse
    victim.Kill(None)
EndEvent

Event OnAcheronForceRecoverRequest(String eventName, String strArg, Float numArg, Form sender)
    Int cnt = StorageUtil.FormListCount(PlayerRef, "SNAcheron.ForceRecoverQueue")
    Int i = 0
    While i < cnt
        Actor a = StorageUtil.FormListGet(PlayerRef, "SNAcheron.ForceRecoverQueue", i) as Actor
        If a
            _ForceRecover(a)
        EndIf
        i += 1
    EndWhile
    StorageUtil.FormListClear(PlayerRef, "SNAcheron.ForceRecoverQueue")
EndEvent

; Acheron Integration registered our downed-victim actions into AcheronNG's own native "Hunter's Pride"
; on-screen option menu (shown on plain E/activate against a defeated actor) — it can't call our Execute
; functions directly (no hard script reference between the two mods, by design), so it stashes the
; target and fires this event with the choice as a plain string instead, same "stash + mod event"
; pattern as every other cross-mod hand-off here. Reuses _DispatchDownedAction's existing choice
; dispatch verbatim (0=Escalate, 1=Investigate, 2=Inspect, 3=Stand Back, 4=Help Up) rather than
; duplicating it — the player is always the caster here since this only ever fires from a native
; vanilla-activate selection.
Event OnHunterPrideChoice(String eventName, String strArg, Float numArg, Form sender)
    Actor target = StorageUtil.GetFormValue(PlayerRef, "SNAcheron.HunterPrideTarget") as Actor
    If !target
        Return
    EndIf
    Int choice = -1
    If strArg == "escalate"
        choice = 0
    ElseIf strArg == "investigate"
        choice = 1
    ElseIf strArg == "inspect"
        choice = 2
    ElseIf strArg == "standback"
        choice = 3
    ElseIf strArg == "helpup"
        choice = 4
    EndIf
    If choice >= 0
        _DispatchDownedAction(choice, PlayerRef, target)
    EndIf
EndEvent

Function _RegisterDecorators()
    SkyrimNetApi.RegisterDecorator("get_baka_state",              "SkyrimNet_BakaIntegration", "GetBakaState")
    SkyrimNetApi.RegisterDecorator("is_in_baka_animation",        "SkyrimNet_BakaIntegration", "IsInBakaAnimation")
    SkyrimNetApi.RegisterDecorator("get_spank_state",             "SkyrimNet_BakaIntegration", "GetSpankState")
    SkyrimNetApi.RegisterDecorator("get_nearby_furniture_actors", "SkyrimNet_BakaIntegration", "GetNearbyFurnitureActors")
    ; baka_flirted decorator removed — the flirt escalations self-gate via their descriptions now.
    ; (GetFlirted is kept below, unused, so any stale SkyrimNet registration still resolves cleanly.)
EndFunction

Event OnUpdateGameTime()
    _Log("[SNBaka] OnUpdateGameTime ENTER: PlayerRef=" + PlayerRef + " gameTime=" + Utility.GetCurrentGameTime())
    UnregisterForUpdateGameTime()
    ; PlayerRef must be refreshed BEFORE _RegisterModEvents() -- confirmed bug from testing:
    ; _RegisterModEvents() only sets SNBaka.Present behind an "If PlayerRef" guard, but doesn't
    ; check RegisterForModEvent's listeners (which don't need PlayerRef at all). If PlayerRef had
    ; gone stale/None across a reload, the listeners kept registering fine every heartbeat while
    ; the Present flag silently never got set again -- Acheron's own creature-handoff check reads
    ; that flag and would skip every roll forever, even though Baka was actually alive and
    ; listening (its own SNBaka_TryCreatureOnDowned handler could still fire directly).
    If !PlayerRef
        PlayerRef = Game.GetPlayer()
    EndIf
    ; Re-assert decorators AND mod-event listeners after a save load (neither persists; Setup doesn't
    ; run on reload). This is what keeps the creature hand-off (and AEL/menu events) alive across loads.
    _RegisterDecorators()
    _RegisterModEvents()
    Float currentTime = Utility.GetCurrentGameTime()
    If _lastSpankFadeTime <= 0.0
        _lastSpankFadeTime = currentTime
    EndIf
    ; Only do the (slow) spank-tattoo fade pass when SpankTatFadeRate hours have actually elapsed. The
    ; registration above runs on the faster heartbeat below, so listeners self-heal within ~seconds of a
    ; load instead of waiting a full fade interval (GetCurrentGameTime is in DAYS; rate is in HOURS).
    If (currentTime - _lastSpankFadeTime) >= (SpankTatFadeRate / 24.0)
        _lastSpankFadeTime = currentTime
        Int fi = 0
        Int fcount = StorageUtil.FormListCount(Self, "SkyrimNetSDB.SpankedActors")
        While fi < fcount
            Actor fa = StorageUtil.FormListGet(Self, "SkyrimNetSDB.SpankedActors", fi) as Actor
            If fa
                FadeActorTats(fa)
                Int remainHeat = StorageUtil.GetIntValue(fa, "SkyrimNetSDB.SpankHeat", 0)
                Int remainTear = StorageUtil.GetIntValue(fa, "SkyrimNetSDB.TearHeat",  0)
                If remainHeat <= 0 && remainTear <= 0
                    StorageUtil.FormListRemoveAt(Self, "SkyrimNetSDB.SpankedActors", fi)
                    fcount -= 1
                Else
                    fi += 1
                EndIf
            Else
                StorageUtil.FormListRemoveAt(Self, "SkyrimNetSDB.SpankedActors", fi)
                fcount -= 1
            EndIf
        EndWhile
    EndIf
    ; Heartbeat slowed 5x (audit finding: this was one of two perpetual self-renewing update chains,
    ; re-running 6 RegisterForModEvent calls every ~18s real-time forever). OnPlayerLoadGame/Setup
    ; cover the normal re-registration cases; this is only the belt-and-suspenders fallback.
    _Log("[SNBaka] OnUpdateGameTime: reached tail, re-arming for +0.5 game-hours")
    RegisterForSingleUpdateGameTime(0.5)
EndEvent

; Called by MCM when HealFactor changes — restarts the fade timer at the new rate.
Function ApplyFadeSettings()
    SpankTatFadeRate = SpankHealFactor as Float
    If SpankTatFadeRate < 0.1
        SpankTatFadeRate = 0.1
    EndIf
    UnregisterForUpdateGameTime()
    RegisterForSingleUpdateGameTime(SpankTatFadeRate)
EndFunction

; ---- Main spank dispatch ----
Function SpankTarget_Execute(Actor akSpanker, Actor akTarget, Bool akForceButt = False)
    _Log("[SNBakaACT] SpankTarget ENTER")
    _Log("[SNBaka] SpankTarget_Execute: spanker=" + akSpanker.GetDisplayName() + " target=" + akTarget.GetDisplayName())
    If !bEnabled || !akSpanker || !akTarget || akTarget.IsDead() || akSpanker.IsDead()
        _Log("[SNBaka] SpankTarget: disabled or dead actor.")
        Return
    EndIf
    If !bPlayerCanBeSpanked && akTarget == PlayerRef
        _Log("[SNBaka] SpankTarget: player-as-target is disabled.")
        Return
    EndIf
    If !bSpankMaleTargets && akTarget.GetActorBase().GetSex() == 0
        _Log("[SNBaka] SpankTarget: target is male — toggle 'Allow Male Targets' in MCM.")
        Return
    EndIf
    Float lastSpank = StorageUtil.GetFloatValue(None, "SkyrimNetSDB.LastSpankTime", 0.0)
    Float nowTime   = Utility.GetCurrentGameTime()
    Bool duringSex  = IsInSexAnimation(akTarget) || IsInSexAnimation(akSpanker)
    Float cooldown  = fSpankCooldown
    If duringSex
        cooldown = fSpankCooldownSex
    EndIf
    If nowTime - lastSpank < (cooldown / 86400.0)
        _Log("[SNBaka] SpankTarget: cooldown active (" + (nowTime - lastSpank) * 86400.0 + "s < " + cooldown + "s)")
        Return
    EndIf
    _Log("[SNBaka] SpankTarget: proceeding — duringSex=" + duringSex)
    StorageUtil.SetFloatValue(None, "SkyrimNetSDB.LastSpankTime", nowTime)
    If !duringSex
        If LockBoth(akSpanker, akTarget)
            ; Babo anim plays its own impact slap — suppress ours; moan at mid-anim.
            PlayPairedSimpleAnim(akSpanker, akTarget, \
                0.0, 0.0, 0.0, \
                "BaboSpankingM", "BaboSpankingF", \
                0.3, False, False, True)   ; was 1.0 — trimmed the post-slap hold (~1s too long)
            ApplyButtReaction(akTarget)
            UnlockBoth(akSpanker, akTarget)
        Else
            ; No paired anim (couldn't lock) — our slap IS the only sound here.
            _DoSpank(akSpanker, akTarget, SpankImpactSound, True)
            ApplyButtReaction(akTarget)
        EndIf
    Else
        ; During sex there's no Babo paired anim, so play our slap+moan directly.
        _PlaySpankSound(akTarget, SpankImpactSound)
    EndIf
    ApplySpankMark(akTarget)
    ApplyFaceMarks(akTarget)
    _StartTears(akTarget)
    RecordSpank(akTarget, akSpanker.GetDisplayName())
    Bool atFurniture = bSpankFurnitureTriggers && akTarget.GetFurnitureReference() != None
    String desc
    If atFurniture
        desc = akSpanker.GetDisplayName() + " slapped " + akTarget.GetDisplayName() + "'s ass while they were bent over."
    Else
        desc = akSpanker.GetDisplayName() + " spanked " + akTarget.GetDisplayName() + "."
    EndIf
    SkyrimNetApi.RegisterEvent("sdb_spanked", desc, akSpanker, akTarget)
EndFunction

Function SlapFace_Execute(Actor akSlapper, Actor akTarget)
    _Log("[SNBakaACT] SlapFace ENTER")
    _Log("[SNBaka] SlapFace_Execute: slapper=" + akSlapper.GetDisplayName() + " target=" + akTarget.GetDisplayName())
    If !bEnabled || !akSlapper || !akTarget || akTarget.IsDead() || akSlapper.IsDead()
        _Log("[SNBaka] SlapFace_Execute: early exit — bEnabled=" + bEnabled + " dead/None check")
        Return
    EndIf
    If !bPlayerCanBeSpanked && akTarget == PlayerRef
        Return
    EndIf
    Float lastSpank = StorageUtil.GetFloatValue(None, "SkyrimNetSDB.LastSpankTime", 0.0)
    Float nowTime   = Utility.GetCurrentGameTime()
    Bool duringSex  = IsInSexAnimation(akTarget) || IsInSexAnimation(akSlapper)
    Float cooldown  = fSpankCooldown
    If duringSex
        cooldown = fSpankCooldownSex
    EndIf
    If nowTime - lastSpank < (cooldown / 86400.0)
        Return
    EndIf
    StorageUtil.SetFloatValue(None, "SkyrimNetSDB.LastSpankTime", nowTime)
    If !duringSex
        _DoSpank(akSlapper, akTarget, SpankFaceSlapSound, False)
    Else
        PlaySmackSound(akTarget)
    EndIf
    ApplyFaceMarks(akTarget)
    _StartTears(akTarget)
    RecordSpank(akTarget, akSlapper.GetDisplayName())
    String desc = akSlapper.GetDisplayName() + " slapped " + akTarget.GetDisplayName() + " across the face."
    SkyrimNetApi.RegisterEvent("sdb_slapped", desc, akSlapper, akTarget)
EndFunction

Function BreastSlap_Execute(Actor akSpanker, Actor akTarget)
    _Log("[SNBakaACT] BreastSlap ENTER")
    If !bEnabled || !akSpanker || !akTarget || akTarget.IsDead() || akSpanker.IsDead()
        Return
    EndIf
    ; Breast slap targets NPCs only — never the player.
    If akTarget == PlayerRef
        _Log("[SNBaka] BreastSlap_Execute: player-as-target is not allowed.")
        Return
    EndIf
    If akTarget.GetActorBase().GetSex() != 1
        Return
    EndIf
    Float lastSpank = StorageUtil.GetFloatValue(None, "SkyrimNetSDB.LastSpankTime", 0.0)
    Float nowTime   = Utility.GetCurrentGameTime()
    Bool duringSex  = IsInSexAnimation(akTarget) || IsInSexAnimation(akSpanker)
    Float cooldown  = fSpankCooldown
    If duringSex
        cooldown = fSpankCooldownSex
    EndIf
    If nowTime - lastSpank < (cooldown / 86400.0)
        Return
    EndIf
    StorageUtil.SetFloatValue(None, "SkyrimNetSDB.LastSpankTime", nowTime)
    If !duringSex
        _DoSpank(akSpanker, akTarget, SpankBreastSlapSound, False)
        ApplyBreastReaction(akTarget)
    Else
        PlaySmackSound(akTarget)
        If akTarget.GetActorBase().GetSex() == 1 && SpankMoanSound
            ; 0.5s so the smack finishes first (shared output model steals the voice otherwise).
            Utility.Wait(0.5)
            SpankMoanSound.Play(akTarget)
        EndIf
    EndIf
    ApplyBreastMark(akTarget)
    ApplyFaceMarks(akTarget)
    _StartTears(akTarget)
    RecordSpank(akTarget, akSpanker.GetDisplayName())
    String desc = akSpanker.GetDisplayName() + " slapped " + akTarget.GetDisplayName() + " across the chest."
    SkyrimNetApi.RegisterEvent("sdb_spanked", desc, akSpanker, akTarget)
EndFunction

; ---- Animation dispatch ----
Function _DoSpank(Actor akSpanker, Actor akTarget, Sound akImpact = None, Bool bForwardReact = True)
    Bool atFurniture = akTarget.GetFurnitureReference() != None
    If bForwardReact && akSpanker == PlayerRef
        Debug.SendAnimationEvent(akSpanker, "SMplayerslaps")
    Else
        Debug.SendAnimationEvent(akSpanker, "IdleTake")
    EndIf
    Utility.Wait(0.15)
    _PlaySpankSound(akTarget, akImpact)
    If akTarget == PlayerRef
        If akTarget.GetActorBase().GetSex() == 1
            If bForwardReact
                Debug.SendAnimationEvent(akTarget, "Sta_slap_forward")
            Else
                Debug.SendAnimationEvent(akTarget, "Sta_slap_backward")
            EndIf
        ElseIf !atFurniture
            Debug.SendAnimationEvent(akTarget, "staggerStart")
        EndIf
    ElseIf !atFurniture
        Debug.SendAnimationEvent(akTarget, "staggerStart")
    EndIf
    Utility.Wait(0.4)
    Debug.SendAnimationEvent(akSpanker, "idleforcedefaultstate")
EndFunction

Function _PlaySpankSound(Actor akTarget, Sound akImpact = None)
    Sound impact = akImpact
    If !impact
        impact = SpankImpactSound
    EndIf

    ; Diagnostics: is the target the one we expect, loaded, and near the camera?
    Bool  loaded = akTarget.Is3DLoaded()
    Float dist   = akTarget.GetDistance(PlayerRef)
    _Log("[SNBaka] _PlaySpankSound: target=" + akTarget.GetDisplayName() + \
        " 3DLoaded=" + loaded + " distToPlayer=" + dist + \
        " impactForm=" + impact + " moanForm=" + SpankMoanSound)

    ; Force the instance to FULL volume after Play — this is what the proven-loud
    ; SkyrimNet_SlapDaButt does (Sound.SetInstanceVolume(handle, 1.0)) and it's how
    ; it stays audible DURING sex: SexLab ducks the SFX category, but pinning this
    ; instance to 1.0 overrides the duck for our slap/moan.  Guard handle > 0.
    ; (Earlier I removed this entirely, and once wrongly used 0.5 — half volume.)
    If impact
        Int handle = impact.Play(akTarget)
        If handle > 0
            Sound.SetInstanceVolume(handle, 1.0)
        EndIf
        _Log("[SNBaka] _PlaySpankSound: impact handle=" + handle)
    Else
        _Log("[SNBaka] _PlaySpankSound: SpankImpactSound is NONE")
    EndIf

    Bool isFemale = akTarget.GetActorBase().GetSex() == 1
    If isFemale && SpankMoanSound
        Utility.Wait(0.1)
        Int moan = SpankMoanSound.Play(akTarget)
        If moan > 0
            Sound.SetInstanceVolume(moan, 1.0)
        EndIf
        _Log("[SNBaka] _PlaySpankSound: moan handle=" + moan)
    ElseIf !isFemale
        _Log("[SNBaka] _PlaySpankSound: no moan — target not female")
    ElseIf !SpankMoanSound
        _Log("[SNBaka] _PlaySpankSound: no moan — SpankMoanSound is NONE")
    EndIf
EndFunction

; Moan only — no impact slap.  Used for the OUT-OF-SEX paired spank, where the
; Babo spanking animation plays its OWN impact slap ~1.5 s in.  Playing our slap
; too made a double sound, so out of sex we suppress our slap and call this right
; after the paired anim returns (~when the Babo impact lands) for just the moan.
Function _PlaySpankMoanOnly(Actor akTarget)
    If !akTarget || akTarget.GetActorBase().GetSex() != 1 || !SpankMoanSound
        Return
    EndIf
    Int moan = SpankMoanSound.Play(akTarget)
    If moan > 0
        Sound.SetInstanceVolume(moan, 1.0)
    EndIf
    _Log("[SNBaka] _PlaySpankMoanOnly: target=" + akTarget.GetDisplayName() + " moan handle=" + moan)
EndFunction

; ---- Reaction spells ----
Function ApplyButtReaction(Actor akTarget)
    If !ButtReactionSpell || !akTarget || akTarget.GetActorBase().GetSex() != 1
        Return
    EndIf
    If akTarget.IsInCombat() || akTarget.IsDead()
        Return
    EndIf
    akTarget.RemoveSpell(ButtReactionSpell)
    akTarget.AddSpell(ButtReactionSpell, False)
EndFunction

Function ApplyBreastReaction(Actor akTarget)
    If !BreastReactionSpell || !akTarget || akTarget.GetActorBase().GetSex() != 1
        Return
    EndIf
    If akTarget.IsInCombat() || akTarget.IsDead()
        Return
    EndIf
    akTarget.RemoveSpell(BreastReactionSpell)
    akTarget.AddSpell(BreastReactionSpell, False)
EndFunction

; ---- Tattoo system ----
Function ApplySpankMark(Actor akTarget)
    If !akTarget || akTarget.GetActorBase().GetSex() != 1
        Return
    EndIf
    Int maxHeat = SpankTatIntensity * 4
    Int heat    = StorageUtil.GetIntValue(akTarget, "SkyrimNetSDB.SpankHeat", 0) + 1
    If heat > maxHeat
        heat = maxHeat
    EndIf
    StorageUtil.SetIntValue(akTarget, "SkyrimNetSDB.SpankHeat", heat)
    Int oldStage = StorageUtil.GetIntValue(akTarget, "SkyrimNetSDB.AssTatStage", 0)
    Int newStage = GetHeatStage(heat, SpankTatIntensity)
    If newStage != oldStage
        If oldStage > 0
            SlaveTats.simple_remove_tattoo(akTarget, "SkyrimNet Spank", GetAssTatNameForStage(oldStage), True, False)
        EndIf
        SlaveTats.simple_add_tattoo(akTarget, "SkyrimNet Spank", GetAssTatNameForStage(newStage), 0, True, True, 1.0)
        StorageUtil.SetIntValue(akTarget, "SkyrimNetSDB.AssTatStage", newStage)
    EndIf
    StorageUtil.FormListAdd(Self, "SkyrimNetSDB.SpankedActors", akTarget, True)
EndFunction

Function ApplyBreastMark(Actor akTarget)
    If !akTarget || akTarget.GetActorBase().GetSex() != 1
        Return
    EndIf
    StorageUtil.SetIntValue(akTarget, "SkyrimNetSDB.HasBreastTat", 1)
    SlaveTats.simple_remove_tattoo(akTarget, "SkyrimNet Spank", "spank_breasts", True, False)
    SlaveTats.simple_add_tattoo(akTarget, "SkyrimNet Spank", "spank_breasts", 0, True, True, 1.0)
    StorageUtil.FormListAdd(Self, "SkyrimNetSDB.SpankedActors", akTarget, True)
EndFunction

Function ApplyFaceMarks(Actor akTarget)
    If !akTarget || akTarget.GetActorBase().GetSex() != 1
        Return
    EndIf
    Int maxTear  = SpankTatIntensity * 4
    Int tearHeat = StorageUtil.GetIntValue(akTarget, "SkyrimNetSDB.TearHeat", 0) + 1
    If tearHeat > maxTear
        tearHeat = maxTear
    EndIf
    StorageUtil.SetIntValue(akTarget, "SkyrimNetSDB.TearHeat", tearHeat)
    UpdateFaceMarks(akTarget, tearHeat)
    StorageUtil.FormListAdd(Self, "SkyrimNetSDB.SpankedActors", akTarget, True)
EndFunction

Function UpdateFaceMarks(Actor akTarget, Int tearHeat)
    If !akTarget || akTarget.GetActorBase().GetSex() != 1
        Return
    EndIf
    ClearFaceMarks(akTarget)
    If tearHeat >= SpankTatIntensity * 3
        SlaveTats.simple_add_tattoo(akTarget, "SkyrimNet Spank", "tears3", 0, True, False, 1.0)
        SlaveTats.simple_add_tattoo(akTarget, "SkyrimNet Spank", "sob2",   0, True, False, 1.0)
        SlaveTats.simple_add_tattoo(akTarget, "SkyrimNet Spank", "drool1", 0, True, True,  1.0)
    ElseIf tearHeat >= SpankTatIntensity * 2
        SlaveTats.simple_add_tattoo(akTarget, "SkyrimNet Spank", "tears2", 0, True, False, 1.0)
        SlaveTats.simple_add_tattoo(akTarget, "SkyrimNet Spank", "sob1",   0, True, True,  1.0)
    ElseIf tearHeat >= SpankTatIntensity
        SlaveTats.simple_add_tattoo(akTarget, "SkyrimNet Spank", "tears1", 0, True, True, 1.0)
    Else
        SlaveTats.simple_add_tattoo(akTarget, "SkyrimNet Spank", "tears1", 0, True, True, 0.0)
    EndIf
EndFunction

Function ClearFaceMarks(Actor akTarget)
    If !akTarget || akTarget.GetActorBase().GetSex() != 1
        Return
    EndIf
    SlaveTats.simple_remove_tattoo(akTarget, "SkyrimNet Spank", "tears1", True, False)
    SlaveTats.simple_remove_tattoo(akTarget, "SkyrimNet Spank", "tears2", True, False)
    SlaveTats.simple_remove_tattoo(akTarget, "SkyrimNet Spank", "tears3", True, False)
    SlaveTats.simple_remove_tattoo(akTarget, "SkyrimNet Spank", "sob1",   True, False)
    SlaveTats.simple_remove_tattoo(akTarget, "SkyrimNet Spank", "sob2",   True, False)
    SlaveTats.simple_remove_tattoo(akTarget, "SkyrimNet Spank", "drool1", True, False)
EndFunction

Function FadeActorTats(Actor akTarget)
    If !akTarget || akTarget.GetActorBase().GetSex() != 1
        Return
    EndIf
    Int tearHeat    = StorageUtil.GetIntValue(akTarget, "SkyrimNetSDB.TearHeat", 0)
    Int newTearHeat = tearHeat - SpankTatIntensity
    If newTearHeat < 0
        newTearHeat = 0
    EndIf
    If newTearHeat != tearHeat
        StorageUtil.SetIntValue(akTarget, "SkyrimNetSDB.TearHeat", newTearHeat)
        UpdateFaceMarks(akTarget, newTearHeat)
    EndIf
    Int heat = StorageUtil.GetIntValue(akTarget, "SkyrimNetSDB.SpankHeat", 0)
    If heat <= 0
        Int hasBreast = StorageUtil.GetIntValue(akTarget, "SkyrimNetSDB.HasBreastTat", 0)
        If hasBreast > 0 && newTearHeat <= 0
            SlaveTats.simple_remove_tattoo(akTarget, "SkyrimNet Spank", "spank_breasts", True, False)
            SlaveTats.simple_add_tattoo(akTarget, "SkyrimNet Spank", "spank_breasts", 0, True, True, 0.0)
            StorageUtil.SetIntValue(akTarget, "SkyrimNetSDB.HasBreastTat", 0)
        EndIf
        Return
    EndIf
    Int newHeat  = heat - SpankTatIntensity
    If newHeat < 0
        newHeat = 0
    EndIf
    StorageUtil.SetIntValue(akTarget, "SkyrimNetSDB.SpankHeat", newHeat)
    Int oldStage = StorageUtil.GetIntValue(akTarget, "SkyrimNetSDB.AssTatStage", 0)
    Int newStage = GetHeatStage(newHeat, SpankTatIntensity)
    If newStage != oldStage && oldStage > 0
        If newStage > 0
            SlaveTats.simple_remove_tattoo(akTarget, "SkyrimNet Spank", GetAssTatNameForStage(oldStage), True, False)
            SlaveTats.simple_add_tattoo(akTarget, "SkyrimNet Spank", GetAssTatNameForStage(newStage), 0, True, True, 1.0)
        Else
            SlaveTats.simple_remove_tattoo(akTarget, "SkyrimNet Spank", GetAssTatNameForStage(oldStage), True, False)
            SlaveTats.simple_add_tattoo(akTarget, "SkyrimNet Spank", GetAssTatNameForStage(oldStage), 0, True, True, 0.0)
        EndIf
        StorageUtil.SetIntValue(akTarget, "SkyrimNetSDB.AssTatStage", newStage)
    EndIf
    Int hasBreast = StorageUtil.GetIntValue(akTarget, "SkyrimNetSDB.HasBreastTat", 0)
    If hasBreast > 0 && newHeat <= 0
        SlaveTats.simple_remove_tattoo(akTarget, "SkyrimNet Spank", "spank_breasts", True, False)
        SlaveTats.simple_add_tattoo(akTarget, "SkyrimNet Spank", "spank_breasts", 0, True, True, 0.0)
        StorageUtil.SetIntValue(akTarget, "SkyrimNetSDB.HasBreastTat", 0)
    EndIf
EndFunction

; ---- Tracking ----
Function RecordSpank(Actor akTarget, String spankerName)
    If !akTarget
        Return
    EndIf
    Int count = StorageUtil.GetIntValue(akTarget, "SkyrimNetSDB.SpankCount", 0) + 1
    StorageUtil.SetIntValue(akTarget,    "SkyrimNetSDB.SpankCount",    count)
    StorageUtil.SetFloatValue(akTarget,  "SkyrimNetSDB.LastSpankTime", Utility.GetCurrentGameTime())
    StorageUtil.SetStringValue(akTarget, "SkyrimNetSDB.LastSpanker",   spankerName)
EndFunction

; ---- Sex / actor helpers ----
Actor Function FindSexPartner(Actor akCaster)
    ; Use cell iteration — does not depend on SexLab thread API.
    ; Finds the nearest actor in the same cell that is in a sex animation.
    If !akCaster
        Return None
    EndIf
    Cell c = akCaster.GetParentCell()
    If !c
        Return None
    EndIf
    Actor nearest = None
    Float nearestDist = 99999.0
    Int count = c.GetNumRefs(62)
    Int i = 0
    While i < count
        Actor candidate = c.GetNthRef(i, 62) as Actor
        If candidate && candidate != akCaster && !candidate.IsDead()
            If IsInSexAnimation(candidate)
                Float d = akCaster.GetDistance(candidate)
                If d < 400.0 && d < nearestDist
                    nearestDist = d
                    nearest = candidate
                EndIf
            EndIf
        EndIf
        i += 1
    EndWhile
    _Log("[SNBaka] FindSexPartner: result=" + nearest)
    Return nearest
EndFunction

; ============================================================
; Sex spank — menu-driven partner selection during sex scenes
; ============================================================

; Fills result[0..2] with up to 3 non-player actors currently in a sex animation
; in the same cell as akCaster. result must be a pre-allocated Actor[3].
; Checks SexLab AnimatingFaction AND OStim ExcitementFaction so the menu
; is populated regardless of which sex framework is running the scene.
Function _GetSexSceneNPCs(Actor akCaster, Actor[] result)
    ; OStim SA fast path: OThread already tracks exactly who's in the scene (the thread roster), so
    ; ask it directly instead of scanning the cell and checking faction membership — no guessing, no
    ; radius, no false negatives. Falls through to the scan below for SexLab scenes (no thread concept)
    ; or if OStim isn't installed / the caster isn't currently in a thread.
    Faction osStimFaction = _OStimSceneFaction()
    If osStimFaction
        Int threadID = OActor.GetThreadID(akCaster)
        If threadID >= 0
            Actor[] threadActors = OThread.GetActors(threadID)
            Int slot = 0
            Int t = 0
            While t < threadActors.Length && slot < 3
                Actor candidate = threadActors[t]
                If candidate && candidate != PlayerRef && candidate != akCaster && !candidate.IsDead()
                    result[slot] = candidate
                    slot += 1
                EndIf
                t += 1
            EndWhile
            If slot > 0
                _Log("[SNBaka] _GetSexSceneNPCs: found " + slot + " NPC(s) via OStim thread " + threadID)
                Return
            EndIf
        EndIf
    EndIf

    ; Resolve SexLab faction
    Faction slFaction = SexLabAnimatingFaction
    If !slFaction
        slFaction = SkyrimNet_BakaSL.AnimFaction()
    EndIf

    ; Need at least one faction to detect anything
    If !slFaction && !osStimFaction
        _Log("[SNBaka] _GetSexSceneNPCs: no sex faction resolved (no SexLab faction and OStim not installed)")
        Return
    EndIf

    Cell c = akCaster.GetParentCell()
    If !c
        Return
    EndIf

    Int slot  = 0
    Int total = c.GetNumRefs(62)
    Int i     = 0
    While i < total && slot < 3
        Actor candidate = c.GetNthRef(i, 62) as Actor
        If candidate && candidate != PlayerRef && !candidate.IsDead()
            Bool inScene = False
            If slFaction && candidate.GetFactionRank(slFaction) >= 0
                inScene = True
            EndIf
            If !inScene && osStimFaction && candidate.GetFactionRank(osStimFaction) >= 0
                inScene = True
            EndIf
            If inScene
                result[slot] = candidate
                slot += 1
            EndIf
        EndIf
        i += 1
    EndWhile
    _Log("[SNBaka] _GetSexSceneNPCs: found " + slot + " NPC(s) in scene")
EndFunction

; Applies a full sex-safe spank: impact + moan + tats + face marks + tears.
; akSpanker may be None (self-spank). No paired animation — safe inside sex scenes.
Function _SexSpank_Execute(Actor akSpanker, Actor akTarget)
    _Log("[SNBakaACT] _SexSpank ENTER")
    If !akTarget
        Return
    EndIf
    _PlaySpankSound(akTarget, SpankImpactSound)
    ApplySpankMark(akTarget)
    ApplyFaceMarks(akTarget)
    _StartTears(akTarget)
    String spankerName = "You"
    If akSpanker
        spankerName = akSpanker.GetDisplayName()
    EndIf
    Actor actor1 = akTarget
    If akSpanker
        actor1 = akSpanker
    EndIf
    SkyrimNetApi.RegisterEvent("baka_sex_spank", \
        spankerName + " spanks " + akTarget.GetDisplayName() + " during sex.", \
        actor1, akTarget)
    StorageUtil.SetFloatValue(None, "SkyrimNetSDB.LastSpankTime", Utility.GetCurrentGameTime())
EndFunction

; Secondary menu: who spanks the player?
Function _SexSpank_ShowByWhom(Actor[] sceneNPCs, Int npcCount)
    String info = "Spanked by: "
    If sceneNPCs[0]
        info += "1=" + sceneNPCs[0].GetDisplayName() + "  "
    EndIf
    If sceneNPCs[1]
        info += "2=" + sceneNPCs[1].GetDisplayName() + "  "
    EndIf
    If sceneNPCs[2]
        info += "3=" + sceneNPCs[2].GetDisplayName() + "  "
    EndIf
    info += "4=Yourself"
    _Notify(info)
    If !SexSpankByWhomMenu
        _SexSpank_Execute(None, PlayerRef)
        Return
    EndIf
    Int choice = SexSpankByWhomMenu.Show()
    If choice == 4
        Return  ; Cancel
    EndIf
    If choice == 3
        _SexSpank_Execute(None, PlayerRef)
        Return
    EndIf
    If choice < npcCount && sceneNPCs[choice]
        _SexSpank_Execute(sceneNPCs[choice], PlayerRef)
    EndIf
EndFunction

; Primary menu shown when the interact power fires during a sex scene.
; Collects all scene participants, shows a notification mapping numbers → names,
; then shows a menu (Person 1 / Person 2 / Person 3 / You / Cancel).
; Selecting "You" opens a second menu for who does the spanking.
Function SexSpank_ShowMenu(Actor akCaster)
    ; Cooldown check
    Float nowTime = Utility.GetCurrentGameTime()
    Float lastSpank = StorageUtil.GetFloatValue(None, "SkyrimNetSDB.LastSpankTime", 0.0)
    If nowTime - lastSpank < (fSpankCooldownSex / 86400.0)
        Return
    EndIf

    ; Collect NPCs in the sex scene
    Actor[] sceneNPCs = new Actor[3]
    _GetSexSceneNPCs(akCaster, sceneNPCs)

    ; Is the player also in the sex animation? Use the SAME both-framework check the power used to
    ; get here (SexLab AND OStim) — the old SexLab-only check made this False in OStim scenes.
    Bool playerInScene = IsInSexAnimation(PlayerRef)

    ; Count valid NPCs
    Int npcCount = 0
    If sceneNPCs[0]
        npcCount += 1
    EndIf
    If sceneNPCs[1]
        npcCount += 1
    EndIf
    If sceneNPCs[2]
        npcCount += 1
    EndIf

    If npcCount == 0 && !playerInScene
        Return
    EndIf

    ; ── PrismaUI path (async) ─────────────────────────────────────────────────
    If SNBakaUI.IsAvailable()
        _pendingSexCaster = akCaster
        _pendingSexNPC0   = sceneNPCs[0]
        _pendingSexNPC1   = sceneNPCs[1]
        _pendingSexNPC2   = sceneNPCs[2]
        _pendingTarget    = None  ; signals _DispatchSexSpankAction not interact

        ; Build JSON: {"names":["Lydia","Serana"],"playerInScene":true}
        String json = "{\"names\":["
        Bool first = True
        If sceneNPCs[0]
            json += "\"" + sceneNPCs[0].GetDisplayName() + "\""
            first = False
        EndIf
        If sceneNPCs[1]
            If !first
                json += ","
            EndIf
            json += "\"" + sceneNPCs[1].GetDisplayName() + "\""
            first = False
        EndIf
        If sceneNPCs[2]
            If !first
                json += ","
            EndIf
            json += "\"" + sceneNPCs[2].GetDisplayName() + "\""
        EndIf
        If playerInScene
            json += "],\"playerInScene\":true}"
        Else
            json += "],\"playerInScene\":false}"
        EndIf
        SNBakaUI.ShowSexSpankMenu(json)
        Return  ; result arrives via OnSNBakaMenuChoice
    EndIf

    ; ── Vanilla fallback ──────────────────────────────────────────────────────
    If !SexSpankWhoMenu
        Actor sexTarget = FindSexPartner(akCaster)
        If sexTarget && sexTarget != akCaster
            _SexSpank_Execute(akCaster, sexTarget)
        EndIf
        Return
    EndIf

    String info = "Spank: "
    If sceneNPCs[0]
        info += "1=" + sceneNPCs[0].GetDisplayName() + "  "
    EndIf
    If sceneNPCs[1]
        info += "2=" + sceneNPCs[1].GetDisplayName() + "  "
    EndIf
    If sceneNPCs[2]
        info += "3=" + sceneNPCs[2].GetDisplayName() + "  "
    EndIf
    If playerInScene
        info += "4=You"
    EndIf
    _Notify(info)

    Int choice = SexSpankWhoMenu.Show()

    If choice == 4
        Return
    EndIf
    If choice == 3
        If playerInScene
            _SexSpank_ShowByWhom(sceneNPCs, npcCount)
        EndIf
        Return
    EndIf
    If choice < npcCount && sceneNPCs[choice]
        _SexSpank_Execute(akCaster, sceneNPCs[choice])
    EndIf
EndFunction

; ---- LLM action callbacks (called from YAML via quest instance) ----
Function SpankButt_Action(Actor akInitiator, Actor akTarget)
    If akTarget
        SpankTarget_Execute(akInitiator, akTarget, True)
    EndIf
EndFunction

Function SpankBreast_Action(Actor akInitiator, Actor akTarget)
    If akTarget
        BreastSlap_Execute(akInitiator, akTarget)
    EndIf
EndFunction

Function SlapFace_Action(Actor akInitiator, Actor akTarget)
    If akTarget
        SlapFace_Execute(akInitiator, akTarget)
    EndIf
EndFunction

; ---- Decorators (Global) ----
String Function GetSpankState(Actor akActor) Global
    If !akActor
        Return "{}"
    EndIf
    Int    count       = StorageUtil.GetIntValue(akActor,   "SkyrimNetSDB.SpankCount",    0)
    Float  lastTime    = StorageUtil.GetFloatValue(akActor,  "SkyrimNetSDB.LastSpankTime", 0.0)
    String lastSpanker = StorageUtil.GetStringValue(akActor, "SkyrimNetSDB.LastSpanker",   "")
    String recency = "none"
    If lastTime > 0.0
        Float hoursSince = (Utility.GetCurrentGameTime() - lastTime) * 24.0
        If hoursSince < 0.5
            recency = "just now"
        ElseIf hoursSince < 2.0
            recency = "very recent"
        ElseIf hoursSince < 8.0
            recency = "recent"
        ElseIf hoursSince < 24.0
            recency = "hours ago"
        Else
            recency = "distant"
        EndIf
    EndIf
    Int heat = StorageUtil.GetIntValue(akActor, "SkyrimNetSDB.SpankHeat", 0)
    SkyrimNet_BakaIntegration q = SkyrimNet_BakaIntegration.GetMain()
    Int factor = 2
    If q
        factor = q.SpankTatIntensity
    EndIf
    String markLevel = "none"
    If heat >= factor * 3
        markLevel = "heavy"
    ElseIf heat >= factor * 2
        markLevel = "medium"
    ElseIf heat >= factor
        markLevel = "light"
    EndIf
    String json = "{"
    json += "\"has_been_spanked\":"     + (count > 0)   + ","
    json += "\"spank_count\":"          + count          + ","
    json += "\"last_spanker\":\""       + lastSpanker    + "\","
    json += "\"recency\":\""            + recency        + "\","
    json += "\"mark_level\":\""         + markLevel      + "\","
    json += "\"available_during_sex\":true"
    json += "}"
    Return json
EndFunction

String Function GetNearbyFurnitureActors(Actor akActor) Global
    Actor akPlayer = Game.GetPlayer()
    If !akPlayer
        Return "[]"
    EndIf
    Cell currentCell = akPlayer.GetParentCell()
    If !currentCell
        Return "[]"
    EndIf
    String result = "["
    Bool first = True
    Int count = currentCell.GetNumRefs(62)
    Int i = 0
    While i < count
        Actor target = currentCell.GetNthRef(i, 62) as Actor
        ; Include the player (so a crafting player is a valid spank target); only exclude
        ; the speaker NPC.  Only surface alchemy labs / enchanting tables — chairs, beds,
        ; forges, etc. are not spank furniture.
        If target && target != akActor && !target.IsDead()
            ObjectReference furnRef = target.GetFurnitureReference()
            If furnRef != None && target.GetDistance(akPlayer) < 1500.0 && SNBakaUI.IsCraftingTemptation(furnRef)
                Bool isFemale  = target.GetActorBase().GetSex() == 1
                Bool tempting  = isFemale
                String sexStr  = "male"
                If isFemale
                    sexStr = "female"
                EndIf
                String poseStr = "standing at an alchemy lab or enchanting table"
                If tempting
                    ; Female bent over an alchemy lab / enchanting table - hips raised,
                    ; backside presented. Strongly nudges the LLM toward spank_butt.
                    poseStr = "bent over an alchemy lab or enchanting table, hips raised and backside presented - a near-irresistible invitation to be spanked"
                EndIf
                If !first
                    result += ","
                EndIf
                result += "{\"name\":\"" + target.GetDisplayName() + "\",\"sex\":\"" + sexStr + "\",\"state\":\"" + poseStr + "\""
                If tempting
                    result += ",\"spank_temptation\":\"very_high\""
                EndIf
                result += "}"
                first = False
            EndIf
        EndIf
        i += 1
    EndWhile
    result += "]"
    Return result
EndFunction

; ---- Heat/stage helpers (Global) ----
Int Function GetHeatStage(Int heat, Int factor = 2) Global
    If factor <= 0
        Return 0
    EndIf
    If heat >= factor * 4
        Return 4
    ElseIf heat >= factor * 3
        Return 3
    ElseIf heat >= factor * 2
        Return 2
    ElseIf heat >= factor
        Return 1
    EndIf
    Return 0
EndFunction

String Function GetAssTatNameForStage(Int stage) Global
    If stage == 1
        Return "spank03"
    ElseIf stage == 2
        Return "spank01"
    ElseIf stage == 3
        Return "spank02"
    ElseIf stage == 4
        Return "spank_ass"
    EndIf
    Return ""
EndFunction
