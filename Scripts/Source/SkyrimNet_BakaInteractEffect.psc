Scriptname SkyrimNet_BakaInteractEffect extends ActiveMagicEffect
{ Interact power: spank during sex, escalate on bleedout, menu otherwise. }

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

    ; Downed victim -> escalate (choke -> sex).  Both the bleedout state and the
    ; SNBaka.OnGround flag (checked inside Interact_ShowMenu) route here.
    If realTarget.IsBleedingOut()
        BakaMain.Escalate_Execute(akCaster, realTarget)
        Return
    EndIf
    BakaMain.Interact_ShowMenu(realTarget, akCaster)
EndEvent
