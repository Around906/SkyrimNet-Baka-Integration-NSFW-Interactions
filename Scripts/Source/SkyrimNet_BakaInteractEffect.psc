Scriptname SkyrimNet_BakaInteractEffect extends ActiveMagicEffect
{ Interact power: spank during sex, downed-victim menu (PrismaUI) otherwise. }

SkyrimNet_BakaIntegration Property BakaMain Auto

Event OnEffectStart(Actor akTarget, Actor akCaster)
    If !BakaMain || !akCaster
        Debug.Notification("[SNBaka] InteractEffect: BakaMain or caster None")
        Return
    EndIf

    Bool dbg = BakaMain.bDebugLog
    If dbg
        Debug.Trace("[SNBaka][POWER] interact power pressed by " + akCaster.GetDisplayName())
    EndIf

    ; The interact power is self-delivered, so akTarget is always the player.
    ; In a sex scene we don't need a target — the spank menu finds partners itself.
    If BakaMain.IsInSexAnimation(akCaster)
        If dbg
            Debug.Notification("[Baka] power: spank menu (in a sex scene)")
        EndIf
        BakaMain.SexSpank_ShowMenu(akCaster)
        Return
    EndIf

    ; Resolve the actor the player is aiming at (crosshair, then nearest). Includes creatures.
    Actor realTarget = SNBakaUI.GetInteractTarget()

    ; HARD GUARD (explicit spec): the power must never touch an actor who is already mid-interaction —
    ; locked in a struggle/paired animation, or inside an OStim/SexLab scene (ANY mod's; our Locked
    ; flag only covers our own). Opening menus or firing an escalation on them yanks a running
    ; interaction apart. (The CASTER's own in-scene case was already handled above — that's the
    ; sex-spank menu, which exists precisely FOR scenes.)
    ;
    ; EXCEPTION: a defeated victim stays SNBaka.Locked=1 for the entire ground window (Struggle/
    ; ChokeHug's own aftermath — _DefeatGroundWindow deliberately keeps them locked so a third party
    ; can't grab them mid-decision) while it waits for the SAME aggressor to pick Escalate/HelpUp/
    ; Release/etc. via exactly this power -> Interact_ShowMenu -> the downed menu. Without this carve-
    ; out the power refused every follow-up press for the window's whole duration, which read as the
    ; NPC being permanently "busy" (confirmed bug report: standalone play, no AEL Struggle QTE addon
    ; and no Acheron Integration, where nothing else ever clears the lock for you). Same ownership
    ; check LockBoth already uses for its own ground-window carve-out — a third party still gets
    ; refused, only the aggressor who actually owns this window gets through.
    If realTarget && BakaMain.IsInSexAnimation(realTarget)
        If dbg
            Debug.Notification("[Baka] power: " + realTarget.GetDisplayName() + " is busy (scene) — not interrupting")
            Debug.Trace("[SNBaka][POWER] blocked — target " + realTarget.GetDisplayName() + " is mid-scene")
        EndIf
        Return
    EndIf
    If realTarget && BakaMain.IsActorLocked(realTarget) && !BakaMain._IsGroundWindowOwner(akCaster, realTarget)
        If dbg
            Debug.Notification("[Baka] power: " + realTarget.GetDisplayName() + " is busy (struggle) — not interrupting")
            Debug.Trace("[SNBaka][POWER] blocked — target " + realTarget.GetDisplayName() + " is locked by someone else")
        EndIf
        Return
    EndIf

    ; Aim at a BEAST -> creature escalation on the nearest valid victim (handles its own gating).
    ; Returns True only if it WAS a supported creature, so we stop here.
    If realTarget && BakaMain.TryCreatureEscalateFromPower(realTarget)
        If dbg
            Debug.Notification("[Baka] power: creature escalation -> " + realTarget.GetDisplayName())
        EndIf
        Return
    EndIf
    If !realTarget
        If dbg
            Debug.Notification("[Baka] power pressed — no target on the crosshair")
            Debug.Trace("[SNBaka][POWER] no interact target (no actor on crosshair / in range)")
        EndIf
        Return
    EndIf

    If dbg
        Debug.Notification("[Baka] power -> " + realTarget.GetDisplayName())
        Debug.Trace("[SNBaka][POWER] target=" + realTarget.GetDisplayName() + " bleedingOut=" + realTarget.IsBleedingOut())
    EndIf

    ; Used to auto-escalate straight to sex here whenever the target was bleeding out, bypassing
    ; Interact_ShowMenu (and its PrismaUI downed-menu) entirely for that one case. That's exactly the
    ; "we always escalate, where's the menu" bug: Interact_ShowMenu already routes ANY downed target
    ; (bleedout included, via _IsDownedAny) to SNBakaUI.ShowDownedMenu on its own -- this was a leftover
    ; shortcut from before that menu existed, silently overriding it for the bleedout case specifically.
    BakaMain.Interact_ShowMenu(realTarget, akCaster)
EndEvent
