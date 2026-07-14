#include "SkyrimNetBridge.h"

namespace {
    // --- Sex-scene factions (resolved lazily; null when the framework isn't installed) ---
    // Mirrors the Papyrus gating: SexLabAnimatingFaction (SexLab.esm 0xE50F) and
    // OStimActorCountFaction (OStim.esp 0xECA) = "currently in an active sex scene".
    RE::TESFaction* g_sexlabAnimating  = nullptr;
    RE::TESFaction* g_ostimActorCount  = nullptr;
    bool            g_factionsResolved = false;

    void ResolveFactions() {
        if (g_factionsResolved) {
            return;
        }
        g_factionsResolved = true;
        if (auto* dh = RE::TESDataHandler::GetSingleton()) {
            g_sexlabAnimating = dh->LookupForm<RE::TESFaction>(0x00E50F, "SexLab.esm");
            g_ostimActorCount = dh->LookupForm<RE::TESFaction>(0x000ECA, "OStim.esp");
        }
    }

    bool InSexScene(RE::Actor* a) {
        ResolveFactions();
        if (g_sexlabAnimating && a->IsInFaction(g_sexlabAnimating)) {
            return true;
        }
        if (g_ostimActorCount && a->IsInFaction(g_ostimActorCount)) {
            return true;
        }
        return false;
    }

    // Eligibility predicates (visibility gates). NOTE: SkyrimNet may invoke these off the
    // main thread, so they only do cheap, read-only actor queries.
    bool NotInCombat(RE::Actor* a)   { return a && !a->IsInCombat(); }
    bool PreSexContact(RE::Actor* a) { return a && !a->IsInCombat() && !InSexScene(a); }

    // Register one top-level category (customParentCategory = "" => top level). The YAML
    // actions nest into it by setting `customCategory: <id>` to the same id string.
    void RegisterOne(const char* id, const char* description, std::function<bool(RE::Actor*)> elig) {
        const bool ok = PublicRegisterCPPSubCategory(
            id,                 // name (unique identifier)
            description,        // shown to the LLM at category-selection time
            std::move(elig),    // visibility gate
            "",                 // triggeringEventTypesCSV
            50,                 // priority
            "{}",               // parameterSchemaJSON (reserved)
            id,                 // customCategory (what YAML actions reference)
            "",                 // customParentCategory ("" = top level)
            "");                // tagsCSV
        SKSE::log::info("RegisterSubCategory '{}' -> {}", id, ok);
    }

    void RegisterCategories() {
        RegisterOne("SNBaka_Spank",
            "Open-handed strikes and blows for impact, punishment, or dominance: spank or smack the butt, "
            "slap the face/cheek, slap or strike the breasts/chest, strike the belly. Bare-hand impact, not weapon combat.",
            [](RE::Actor* a) { return NotInCombat(a); });

        RegisterOne("SNBaka_Grab",
            "Seizing, restraining, choking, and subduing BEFORE any sex scene: hug/embrace from front or behind, "
            "grab or grope from behind against their will, choke/strangle/throttle by the throat, wrestle/struggle/pin, "
            "spike a drink or drug their food, exploit a drunk or incapacitated target.",
            [](RE::Actor* a) { return PreSexContact(a); });

        RegisterOne("SNBaka_Intimate",
            "Sexual touching, kissing, and oral contact short of a full sex scene: kiss (forced or loving), "
            "touch/grope/fondle breasts, suck breasts, touch or play with the genitals/privates, examine the intimate "
            "lower body, kneel and perform oral.",
            [](RE::Actor* a) { return PreSexContact(a); });

        RegisterOne("SNBaka_Display",
            "Provocative, performative display FOR another character to see — flirt, tease, seduce, make eyes, "
            "or show off your body for them. Always has a target watching or being addressed: a brief social "
            "beat, NOT a held solo pose (use SNBaka_Pose for striking and holding a pose on your own). "
            "No physical contact.",
            [](RE::Actor* a) { return NotInCombat(a); });

        RegisterOne("SNBaka_Scene",
            "Manage or control a capture/defeat encounter: escalate on a downed victim, release/free the victim, "
            "call off or abort, interrupt/stop an active scene, inspect a captive or investigate a restrained target.",
            [](RE::Actor* a) { return NotInCombat(a); });

        RegisterOne("SNBaka_Expression",
            "Make the speaker's FACE show an emotion for a few seconds (facial expression only, no body action): "
            "happy, angry, afraid, sad, pained, surprised, or confused. Use to react emotionally to what was said or done.",
            [](RE::Actor* a) { return NotInCombat(a); });

        // Shared across mods: SkyrimNet_AnimationsGS's own GSPoser pose actions (Dance, Seduce,
        // Stretch, etc.) join this same category by setting customCategory: SNBaka_Pose in their own
        // YAML -- one registration, referenced by two mods, same "solo body pose/gesture" concept
        // regardless of which animation backend actually plays it.
        RegisterOne("SNBaka_Pose",
            "Hold a SOLO body pose or gesture — no target, nobody needs to be watching, no physical contact "
            "with anyone: kneel, meditate, sleep, crouch, stretch, dance, strike a suggestive idle stance, "
            "and more. Held in place until you stop it, combat starts, or it times out on its own (unlike "
            "SNBaka_Display, which is a brief beat performed FOR someone else).",
            [](RE::Actor* a) { return NotInCombat(a); });
    }
}

void SkyrimNetBridge::Init() {
    if (!FindFunctions()) {
        SKSE::log::warn("SkyrimNet.dll not found - action categories not registered.");
        return;
    }
    const int ver = PublicGetVersion ? PublicGetVersion() : 0;
    SKSE::log::info("SkyrimNet C++ API v{} detected.", ver);

    if (!PublicRegisterCPPSubCategory) {
        SKSE::log::warn("PublicRegisterCPPSubCategory unavailable (needs SkyrimNet API v2+); skipping categories.");
        return;
    }
    RegisterCategories();
    SKSE::log::info("Category registration complete.");
}
