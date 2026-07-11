#pragma once

#include <array>
#include <atomic>
#include <string>
#include <vector>

#include "PrismaUI_API.h"

namespace RE { class Actor; }

class PrismaUIBridge {
public:
    static void RequestAPI() noexcept;
    static void CreateMenuView() noexcept;
    static bool IsAvailable() noexcept;

    // Separate, always-on ambient overlay view (never Focus()'d/paused, unlike the modal wizard views
    // above) -- same pattern as Ostim_interactions' OII_Hud. Currently just the get-up-key charge bar,
    // but any future passive HUD element belongs here, not on s_view.
    static void CreateHudView() noexcept;
    // Updates the get-up-key "charging toward 3s" bar. pct in [0,1]; negative hides it.
    static void SetGetUpCharge(float pct) noexcept;
    static bool IsMenuOpen() noexcept;
    static void CancelMenu() noexcept;
    static void ShowInteractMenu(RE::Actor* caster, RE::Actor* target) noexcept;
    static void ShowSexSpankMenu(const std::string& json) noexcept;

    // Multi-step SexLab encounter setup (Roles -> Intensity -> Flavor -> Type).
    // The player's picks come back as a "role;intensity;flavor;type" spec string
    // (or "cancel") and are dispatched to Papyrus _StartSexLabScene with these actors.
    static void ShowEncounterMenu(RE::Actor* aggressor, RE::Actor* victim) noexcept;

    // Downed-victim menu (Escalate / Investigate / Inspect / Stand Back / Help Up). The pick
    // comes back to Papyrus _DispatchDownedAction(choice, caster, victim).
    static void ShowDownedMenu(RE::Actor* caster, RE::Actor* victim) noexcept;

    // Resolves the NPC the player is targeting (crosshair, then nearest-actor
    // fallback).  Returns nullptr if none / only the player.  Called from
    // OnEffectStart so Papyrus runs its sex/escalate/interact checks on the
    // real target even though the spell is self-delivered.
    static RE::Actor* GetInteractTarget() noexcept;

    // Restore original Havok bumper-capsule radius on every actor we previously shrank.
    // Called on game load to clean up anything left dangling after a crash/reload.
    static void RestoreTrackedCollision() noexcept;

    // Shrinks (disable=true) or restores (disable=false) an actor's Havok character-bumper
    // capsule -- the shape responsible for pushing other actors away when they get close.
    // Called per-animation from Papyrus for both participants so a paired sequence doesn't
    // shove them apart.
    static void SetActorCollision(RE::Actor* actor, bool disable) noexcept;

    // True if the furniture is an alchemy lab or enchanting table (incl. experiment
    // variants).  Used to bias the SkyrimNet spank action toward those stations.
    static bool IsAlchemyOrEnchantingFurniture(RE::TESObjectREFR* furniture) noexcept;

private:
    static void OnJSChoice(const char* value) noexcept;

    enum class MenuMode { None, Interact, SexSpank, Encounter, Downed };

    static inline PRISMA_UI_API::IVPrismaUI1* s_prisma = nullptr;
    static inline PRISMA_UI_API::IVPrismaUI2* s_prismav2 = nullptr;
    static inline PrismaView                  s_view   = 0;
    static inline PrismaView                  s_hudView = 0;
    static inline std::atomic<MenuMode>       s_mode   = MenuMode::None;

    // When Papyrus-side sex scene detection returns no NPCs we fall back to a
    // C++ proximity scan.  We store FormIDs (not raw pointers) so they remain
    // valid across frame boundaries.  s_usingCppSexActors gates the alternate
    // dispatch path in OnJSChoice.
    static inline bool                      s_usingCppSexActors = false;
    static inline std::array<RE::FormID, 3> s_sexActorIds       = {};
    static inline std::uint8_t              s_sexActorCount     = 0;

    // Interact actors captured at menu-open, dispatched back when the player
    // picks an action.  Held as FormIDs so they survive the open-menu gap and
    // can't be clobbered by Papyrus re-entry (the game runs unpaused).
    static inline RE::FormID s_interactCaster = 0;
    static inline RE::FormID s_interactTarget = 0;

    // Encounter actors captured at menu-open, used when the spec comes back.
    static inline RE::FormID s_encAggressor = 0;
    static inline RE::FormID s_encVictim    = 0;

    // Downed-menu actors captured at menu-open, used when the choice comes back.
    static inline RE::FormID s_downedCaster = 0;
    static inline RE::FormID s_downedVictim = 0;
};
