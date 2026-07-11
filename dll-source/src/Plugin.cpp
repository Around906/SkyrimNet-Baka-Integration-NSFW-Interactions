#include <spdlog/sinks/basic_file_sink.h>

#include "HitEventSink.h"
#include "PapyrusFunctions.h"
#include "PrismaUIBridge.h"
#include "SkyrimNetBridge.h"


// Closes the active PrismaUI menu on ESC or Tab so the player isn't stuck.
class MenuInputHandler : public RE::BSTEventSink<RE::InputEvent*> {
public:
    static MenuInputHandler* GetSingleton() {
        static MenuInputHandler instance;
        return &instance;
    }

    RE::BSEventNotifyControl ProcessEvent(RE::InputEvent* const* a_event,
                                          RE::BSTEventSource<RE::InputEvent*>*) override {
        if (!a_event || !PrismaUIBridge::IsMenuOpen())
            return RE::BSEventNotifyControl::kContinue;

        for (auto* ev = *a_event; ev; ev = ev->next) {            
            if (ev->GetEventType() != RE::INPUT_EVENT_TYPE::kButton) continue;
            if (ev->GetDevice() != RE::INPUT_DEVICE::kKeyboard)   continue;
            auto* btn = ev->AsButtonEvent();
            if (!btn || !btn->IsDown()) continue;

            constexpr std::uint32_t kEscape = 1;
            constexpr std::uint32_t kTab    = 15;
            if (btn->GetIDCode() == kEscape || btn->GetIDCode() == kTab) {
                PrismaUIBridge::CancelMenu();
                return RE::BSEventNotifyControl::kStop;
            }
        }
        return RE::BSEventNotifyControl::kContinue;
    }
};

bool SetupLog() {
    auto logsFolder = SKSE::log::log_directory();
    if (!logsFolder) return false;

    auto pluginName = SKSE::PluginDeclaration::GetSingleton()->GetName();
    auto logPath = *logsFolder / std::format("{}.log", pluginName);
    std::shared_ptr<spdlog::logger> logger;
    try {
      auto sink = std::make_shared<spdlog::sinks::basic_file_sink_mt>(logPath.string(), true);
      logger = std::make_shared<spdlog::logger>(static_cast<std::string>(pluginName), std::move(sink));
    } catch (const std::exception& e) {
      SKSE::stl::report_and_fail(std::format("{} Failed to open log file '{}': {}",
                                           static_cast<std::string>(pluginName), logPath.string(), e.what()));
      return false;
    }
    logger->set_pattern("[%Y-%m-%d %T.%e] [%l] [%s:%#] %v");
    logger->set_level(spdlog::level::trace);
    logger->flush_on(spdlog::level::trace);
    spdlog::set_default_logger(std::move(logger));

    return true;
}

SKSEPluginLoad(const SKSE::LoadInterface* skse) {
    SKSE::Init(skse, false);
    if (!SetupLog()) {
        return false;
    }      
    SKSE::log::info("{} {} loaded", SKSE::GetPluginName(), SKSE::GetPluginVersion());
    SKSE::log::info(" CommonLibSSE-NG v{}", COMMONLIBSSE_VERSION);
    SKSE::log::info(" Running on Skyrim v{}", REL::Module::get().version().string());

    SKSE::GetMessagingInterface()->RegisterListener([](SKSE::MessagingInterface::Message* msg) {
        switch (msg->type) {
        case SKSE::MessagingInterface::kPostLoad:
            PrismaUIBridge::RequestAPI();
            break;
        case SKSE::MessagingInterface::kDataLoaded:
            // View created exactly once here — never re-created on save load,
            // matching the known-good behaviour.  ShowInteractMenu self-heals
            // lazily if PrismaUI ever reports the view invalid.
            PrismaUIBridge::CreateMenuView();
            PrismaUIBridge::CreateHudView();
            RE::BSInputDeviceManager::GetSingleton()->AddEventSink(MenuInputHandler::GetSingleton());
            SKSE::log::info("Input handler registered.");
            RE::ScriptEventSourceHolder::GetSingleton()->AddEventSink<RE::TESHitEvent>(HitEventSink::GetSingleton());
            SKSE::log::info("Hit event sink registered.");
            // Resolve SkyrimNet's C++ API and register our action categories.
            SkyrimNetBridge::Init();
            break;
        case SKSE::MessagingInterface::kPostLoadGame:
        case SKSE::MessagingInterface::kNewGame:
            // Clear any no-collision flags left dangling from a prior session.
            // No-op on a fresh process (tracking list is empty).
            PrismaUIBridge::RestoreTrackedCollision();
            break;
        }
    });

    SKSE::GetPapyrusInterface()->Register(PapyrusFunctions::Register);
    return true;
}
