#include "PapyrusFunctions.h"
#include "PrismaUIBridge.h"
#include "HitEventSink.h"

#include <cctype>
#include <fstream>
#include <unordered_map>

static constexpr const char* kScriptName     = "SNBakaUI";
static constexpr const char* kOffsetsIniPath = "Data/SKSE/Plugins/SNBaka_Offsets.ini";

namespace {
    std::unordered_map<std::string, float> g_offsets;
    bool                                   g_offsetsLoaded = false;

    std::string ToLower(std::string s) {
        for (auto& c : s) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
        return s;
    }

    std::string Trim(const std::string& s) {
        const auto first = s.find_first_not_of(" \t\r\n");
        if (first == std::string::npos) return "";
        const auto last = s.find_last_not_of(" \t\r\n");
        return s.substr(first, last - first + 1);
    }

    // Parses "key.axis = value" lines from SNBaka_Offsets.ini into a flat lowercase map.
    // Not a real [section] ini -- just flat key=value pairs, '#'/';' comments, blank lines skipped.
    void LoadOffsets() {
        g_offsets.clear();
        std::ifstream file(kOffsetsIniPath);
        if (!file.is_open()) {
            SKSE::log::warn("LoadOffsets: could not open '{}' -- all GetOffset calls will use their passed-in default.", kOffsetsIniPath);
            g_offsetsLoaded = true;
            return;
        }
        std::string line;
        int count = 0;
        while (std::getline(file, line)) {
            const std::string trimmed = Trim(line);
            if (trimmed.empty() || trimmed[0] == '#' || trimmed[0] == ';') continue;
            const auto eq = trimmed.find('=');
            if (eq == std::string::npos) continue;
            const std::string key = ToLower(Trim(trimmed.substr(0, eq)));
            const std::string val = Trim(trimmed.substr(eq + 1));
            if (key.empty() || val.empty()) continue;
            try {
                g_offsets[key] = std::stof(val);
                ++count;
            } catch (...) {
                SKSE::log::warn("LoadOffsets: bad float value for key '{}': '{}'", key, val);
            }
        }
        g_offsetsLoaded = true;
        SKSE::log::info("LoadOffsets: loaded {} offset entries from '{}'.", count, kOffsetsIniPath);
    }
}

static bool SNBakaUI_IsAvailable(RE::StaticFunctionTag*) {
    const bool result = PrismaUIBridge::IsAvailable();
    if (!result)
        SKSE::log::warn("IsAvailable() = false — view invalid, will try to recover.");
    return result;
}

static void SNBakaUI_ShowInteractMenu(RE::StaticFunctionTag*,
                                      RE::Actor* akCaster, RE::Actor* akTarget) {
    PrismaUIBridge::ShowInteractMenu(akCaster, akTarget);
}

static RE::Actor* SNBakaUI_GetInteractTarget(RE::StaticFunctionTag*) {
    return PrismaUIBridge::GetInteractTarget();
}

static void SNBakaUI_SetNoCollision(RE::StaticFunctionTag*, RE::Actor* akActor, bool abDisable) {
    PrismaUIBridge::SetActorCollision(akActor, abDisable);
}

static bool SNBakaUI_IsCraftingTemptation(RE::StaticFunctionTag*, RE::TESObjectREFR* akFurniture) {
    return PrismaUIBridge::IsAlchemyOrEnchantingFurniture(akFurniture);
}

static void SNBakaUI_ShowSexSpankMenu(RE::StaticFunctionTag*,
                                      RE::BSFixedString json) {
    SKSE::log::info("ShowSexSpankMenu native called.");
    PrismaUIBridge::ShowSexSpankMenu(json.c_str() ? json.c_str() : "{}");
}

static void SNBakaUI_ShowEncounterMenu(RE::StaticFunctionTag*,
                                       RE::Actor* akAggressor, RE::Actor* akVictim) {
    PrismaUIBridge::ShowEncounterMenu(akAggressor, akVictim);
}

static void SNBakaUI_ShowDownedMenu(RE::StaticFunctionTag*,
                                    RE::Actor* akCaster, RE::Actor* akVictim) {
    PrismaUIBridge::ShowDownedMenu(akCaster, akVictim);
}

static float SNBakaUI_GetOffset(RE::StaticFunctionTag*,
                                RE::BSFixedString asKey, RE::BSFixedString asAxis, float afDefault) {
    if (!g_offsetsLoaded) LoadOffsets();
    const std::string key  = ToLower(asKey.c_str()  ? asKey.c_str()  : "");
    const std::string axis = ToLower(asAxis.c_str() ? asAxis.c_str() : "");
    const auto it = g_offsets.find(key + "." + axis);
    return it != g_offsets.end() ? it->second : afDefault;
}

static void SNBakaUI_ReloadOffsets(RE::StaticFunctionTag*) {
    LoadOffsets();
}

static RE::Actor* SNBakaUI_GetLastHitAggressor(RE::StaticFunctionTag*, RE::Actor* akTarget) {
    return HitEventSink::GetLastAggressor(akTarget);
}

static void SNBakaUI_SetGetUpCharge(RE::StaticFunctionTag*, float afPct) {
    PrismaUIBridge::SetGetUpCharge(afPct);
}

bool PapyrusFunctions::Register(RE::BSScript::IVirtualMachine* vm) {
    vm->RegisterFunction("IsAvailable",       kScriptName, SNBakaUI_IsAvailable);
    vm->RegisterFunction("ShowInteractMenu",  kScriptName, SNBakaUI_ShowInteractMenu);
    vm->RegisterFunction("ShowSexSpankMenu",  kScriptName, SNBakaUI_ShowSexSpankMenu);
    vm->RegisterFunction("GetInteractTarget",   kScriptName, SNBakaUI_GetInteractTarget);
    vm->RegisterFunction("SetNoCollision",      kScriptName, SNBakaUI_SetNoCollision);
    vm->RegisterFunction("IsCraftingTemptation", kScriptName, SNBakaUI_IsCraftingTemptation);
    vm->RegisterFunction("ShowEncounterMenu",   kScriptName, SNBakaUI_ShowEncounterMenu);
    vm->RegisterFunction("ShowDownedMenu",      kScriptName, SNBakaUI_ShowDownedMenu);
    vm->RegisterFunction("GetOffset",           kScriptName, SNBakaUI_GetOffset);
    vm->RegisterFunction("ReloadOffsets",       kScriptName, SNBakaUI_ReloadOffsets);
    vm->RegisterFunction("GetLastHitAggressor", kScriptName, SNBakaUI_GetLastHitAggressor);
    vm->RegisterFunction("SetGetUpCharge",      kScriptName, SNBakaUI_SetGetUpCharge);
    SKSE::log::info("Papyrus functions registered.");
    return true;
}
