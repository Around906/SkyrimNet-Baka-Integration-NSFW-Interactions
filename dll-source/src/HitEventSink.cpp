#include "HitEventSink.h"

using namespace std::literals;

HitEventSink* HitEventSink::GetSingleton() noexcept {
    static HitEventSink instance;
    return &instance;
}

RE::BSEventNotifyControl HitEventSink::ProcessEvent(const RE::TESHitEvent* a_event,
                                                     RE::BSTEventSource<RE::TESHitEvent>*) {
    if (!a_event) return RE::BSEventNotifyControl::kContinue;

    auto* target = skyrim_cast<RE::Actor*>(a_event->target.get());
    auto* player = RE::PlayerCharacter::GetSingleton();
    if (!target || target->IsDead()) {
        return RE::BSEventNotifyControl::kContinue;
    }

    // DOWNED EXECUTIONS -- Acheron's defeated actors are natively damage-immune, which made a downed
    // enemy unkillable no matter what (confirmed repeated report; explicit spec: "they should be
    // killable if hit, not necessarily aggroed"). A PHYSICAL hit (weapon/unarmed -- no projectiles,
    // no magic, same filter as the grapple path below) on a defeated NON-player actor is forwarded
    // to Papyrus as an execution; Papyrus applies the kill so essential/protected flags and scene
    // locks are still respected there. The defeated PLAYER stays immune -- their defeat IS the
    // death alternative.
    static RE::BGSKeyword* s_defeatedKW = nullptr;
    if (!s_defeatedKW) {
        s_defeatedKW = RE::TESForm::LookupByEditorID<RE::BGSKeyword>("AcheronDefeated");
    }
    if (s_defeatedKW && target != player && target->HasKeyword(s_defeatedKW)) {
        auto* execCause = skyrim_cast<RE::Actor*>(a_event->cause.get());
        if (execCause && !execCause->IsDead()) {
            // Weapon-delivered only: melee swings, FISTS (source==0), and ARROWS/BOLTS (source is the
            // bow/crossbow, projectile set) all execute -- explicit spec. Spells, enchant procs, and
            // poison spit have a non-Weapon source and stay excluded, so a stray firebolt or an AoE
            // from a fight nearby can't accidentally execute a downed body.
            auto* execSrc = a_event->source ? RE::TESForm::LookupByID(a_event->source) : nullptr;
            if (!execSrc || execSrc->GetFormType() == RE::FormType::Weapon) {
                SKSE::log::info("HitEventSink: execution -- weapon hit on defeated '{}' by '{}' (projectile={})",
                                target->GetDisplayFullName(), execCause->GetDisplayFullName(),
                                a_event->projectile != 0);
                SKSE::ModCallbackEvent ev{"SNBaka_DefeatedExecuted"sv, ""sv, 0.0f, target};
                SKSE::GetModCallbackEventSource()->SendEvent(&ev);
            }
        }
        return RE::BSEventNotifyControl::kContinue;  // defeated targets never feed the grapple path below
    }

    // Cheap native filter -- only a player-teammate (current follower) OR the player themselves
    // getting hit is worth ever bothering Papyrus about for the GRAPPLE pipeline; everything else
    // (the vast majority of hits in a busy fight) is skipped right here instead of round-tripping
    // into the VM.
    if (!target->IsPlayerTeammate() && target != player) {
        return RE::BSEventNotifyControl::kContinue;
    }

    auto* cause = skyrim_cast<RE::Actor*>(a_event->cause.get());
    if (!cause || cause->IsDead() || cause == player) {
        return RE::BSEventNotifyControl::kContinue;
    }

    {
        std::lock_guard lock(s_mutex);
        s_lastAggressor[target->GetFormID()] = cause->GetFormID();
    }

    // Physical strikes only from here down -- TESHitEvent also fires for spells, shouts, enchant
    // procs, and poison projectiles (a falmer's poison spit arrives here with the spell as `source`),
    // and those were triggering grapple attempts like melee blows did (confirmed report: "a falmer
    // poisons me, it counts as a melee attack"). The aggressor CACHE above deliberately still records
    // every hit type -- a mage who downs someone is still the correct tracked aggressor -- only the
    // escalation mod event below is gated to actual weapon/unarmed contact.
    if (a_event->projectile != 0) {
        return RE::BSEventNotifyControl::kContinue;  // arrows, bolts, poison spit -- any projectile
    }
    if (a_event->source != 0) {
        auto* src = RE::TESForm::LookupByID(a_event->source);
        if (!src || src->GetFormType() != RE::FormType::Weapon) {
            return RE::BSEventNotifyControl::kContinue;  // spells, enchantments, poisons, hazards
        }
    }

    SKSE::log::info("HitEventSink: '{}' physically hit by '{}'", target->GetDisplayFullName(),
                     cause->GetDisplayFullName());

    // Real decision (is this actually a supported creature, MCM toggle, sex filter, cooldown) lives
    // in Papyrus -- OnCreatureHitFollower resolves the aggressor for a follower victim via
    // GetCombatTarget() (reliable there), or via GetLastAggressor above for the player.
    SKSE::ModCallbackEvent modEvent{"SNBaka_CreatureHitFollower"sv, ""sv, 0.0f, target};
    SKSE::GetModCallbackEventSource()->SendEvent(&modEvent);

    return RE::BSEventNotifyControl::kContinue;
}

RE::Actor* HitEventSink::GetLastAggressor(RE::Actor* target) noexcept {
    if (!target) return nullptr;
    std::lock_guard lock(s_mutex);
    const auto it = s_lastAggressor.find(target->GetFormID());
    if (it == s_lastAggressor.end()) return nullptr;
    auto* form = RE::TESForm::LookupByID(it->second);
    return form ? form->As<RE::Actor>() : nullptr;
}
