#pragma once

#include <mutex>
#include <unordered_map>

// Detects a creature landing a melee hit on a player-teammate (follower) OR the player themselves,
// and forwards it to Papyrus as a plain ModEvent (sender = the victim). All the real decision-making
// (is the aggressor actually a supported creature, MCM toggle, sex filter, cooldown, the combat-near
// gate before the scene itself) already lives in Papyrus for the passive/downed escalation path --
// this only detects the moment and gets out of the way, same division of labor as HotkeyInputHandler
// in Ostim_interactions.
class HitEventSink : public RE::BSTEventSink<RE::TESHitEvent> {
public:
    static HitEventSink* GetSingleton() noexcept;

    RE::BSEventNotifyControl ProcessEvent(const RE::TESHitEvent* a_event,
                                          RE::BSTEventSource<RE::TESHitEvent>*) override;

    // The Papyrus side resolves the aggressor via GetCombatTarget() for a follower victim, which is
    // reliable since followers have real AI combat targeting -- but the PLAYER doesn't necessarily
    // have a meaningful GetCombatTarget() pointed at whoever just hit them. Cache the actual hit-event
    // cause here (ground truth, no guessing) so Papyrus can ask for it directly instead.
    static RE::Actor* GetLastAggressor(RE::Actor* target) noexcept;

private:
    HitEventSink() = default;

    static inline std::mutex s_mutex;
    static inline std::unordered_map<RE::FormID, RE::FormID> s_lastAggressor;
};
