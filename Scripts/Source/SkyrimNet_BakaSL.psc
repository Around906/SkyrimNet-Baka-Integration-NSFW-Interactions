Scriptname SkyrimNet_BakaSL
; SexLab bridge. ALL SexLab script types (SexLabFramework, sslBaseAnimation) live ONLY in here, so
; the main script references none of them and the mod loads/runs WITHOUT SexLab installed. These are
; global functions called by name; if SexLab is absent this script just no-ops (Installed() = false),
; it does not break the caller.

; Cached: on a modlist without SexLab.esm at all (e.g. OStim-only, like this one), an uncached
; Game.GetFormFromFile("SexLab.esm") logs a hard Papyrus ERROR — not a silent None — on every single
; call. _SL() is reached from IsInSexAnimation(), which is polled every ~0.2s in several wait loops
; (_DefeatGroundWindow, _PollResist, etc.), so uncached this spammed 50+ errors per session in testing —
; real Papyrus VM load stacking up right as other mods are also erroring at scene-end. The error only
; fires when the plugin is ABSENT (a present plugin just resolves, no error either way), so caching
; "confirmed absent" as a plain Int (this StorageUtil stub has no Form storage functions) is enough to
; skip every subsequent lookup once we know there's nothing to find.
SexLabFramework Function _SL() Global
    If StorageUtil.GetIntValue(None, "SNBakaSL.Absent", 0) == 1
        Return None
    EndIf
    SexLabFramework sl = Game.GetFormFromFile(0x000D62, "SexLab.esm") as SexLabFramework
    If !sl
        StorageUtil.SetIntValue(None, "SNBakaSL.Absent", 1)
    EndIf
    Return sl
EndFunction

Bool Function Installed() Global
    Return _SL() != None
EndFunction

Faction Function AnimFaction() Global
    SexLabFramework sl = _SL()
    If sl
        Return sl.AnimatingFaction
    EndIf
    Return None
EndFunction

String Function _IntensityTags(String intensity) Global
    If intensity == "aggressive"
        Return "Aggressive,Rough,Forced,Rape,Hardcore,Dom,Domination,Defeat,Brutal,Forsaken,Bound,Spanking,Violent,Painful"
    ElseIf intensity == "loving"
        Return "Loving,Hugging,Kissing,Caressing,Cuddle,Tender,Romantic,Sensual,Passionate,Gentle"
    EndIf
    Return ""
EndFunction

String Function _ExcludeTags(String position, String intensity) Global
    String ex = ""
    If intensity == "aggressive"
        ex = "Loving,Hugging,Caressing,Cuddle,Tender,Romantic,Sensual,Gentle,Foreplay"
    ElseIf intensity == "loving"
        ex = "Aggressive,Rough,Forced,Rape,Hardcore,Dom,Domination,Defeat,Brutal,Violent,Painful"
    EndIf
    String posEx = ""
    If position == "vaginal"
        posEx = "Anal,Oral"
    ElseIf position == "anal"
        posEx = "Vaginal,Oral"
    ElseIf position == "oral"
        posEx = "Vaginal,Anal"
    EndIf
    If ex != "" && posEx != ""
        Return ex + "," + posEx
    ElseIf posEx != ""
        Return posEx
    EndIf
    Return ex
EndFunction

; Starts a SexLab scene with the position/intensity tag filter. Returns the thread id, or -1 if
; SexLab isn't installed. (Tag-match logic moved verbatim from the old main-script _ResolveSexAnims.)
Int Function StartScene(Actor[] akActors, Actor akVictim, Actor akAggressor, String position, String intensity) Global
    SexLabFramework sl = _SL()
    If !sl
        Return -1
    EndIf
    String intTags = _IntensityTags(intensity)
    sslBaseAnimation[] anims
    ; GetAnimationsByTags only ever searches HUMAN animation slots — confirmed by reading
    ; SexLabFramework.psc itself: it's a thin wrapper around AnimSlots.GetByTags, and never touches
    ; CreatureSlots. For a creature pair it silently returns nothing usable, so SexLab falls back to
    ; picking blind and frequently fails to start at all. GetCreatureAnimationsByActorsTags is the
    ; public, documented creature-aware equivalent (same official pattern SexLabFramework's own
    ; QuickStart() uses internally to decide between the two).
    If SkyrimNet_BakaIntegration._AnyCreatureIn(akActors)
        If intTags != ""
            anims = sl.GetCreatureAnimationsByActorsTags(akActors.Length, akActors, intTags, _ExcludeTags(position, intensity), False)
            If !(anims && anims.Length > 0)
                anims = sl.GetCreatureAnimationsByActorsTags(akActors.Length, akActors, intTags, _ExcludeTags("", intensity), False)
            EndIf
        EndIf
        If !(anims && anims.Length > 0)
            anims = sl.GetCreatureAnimationsByActors(akActors.Length, akActors)
        EndIf
    ElseIf intTags != ""
        anims = sl.GetAnimationsByTags(2, intTags, _ExcludeTags(position, intensity), False)
        If !(anims && anims.Length > 0)
            anims = sl.GetAnimationsByTags(2, intTags, _ExcludeTags("", intensity), False)
        EndIf
    ElseIf position != ""
        anims = sl.GetAnimationsByTags(2, position, "", False)
    EndIf
    ; anims may be None/empty here -> SexLab picks from everything.
    Return sl.StartSex(akActors, anims, akVictim, akAggressor, True, "")
EndFunction
