<p align="center">
  <img src="logo.png" alt="SkyrimNet Baka Integration" width="640">
</p>

<h1 align="center">SkyrimNet Baka Integration — NSFW Interactions</h1>

<p align="center">
  <em>LLM-driven physical &amp; intimate interactions and facial expressions for
  <a href="https://goncalo22.github.io/SkyrimNet-GamePlugin/Installation%20Guide/skyrimnet-installation/">SkyrimNet</a>.</em>
</p>

> ⚠️ **Adult content (18+).** This addon adds non-consensual / NSFW interactions. Use responsibly.

---

## What it does

This is an addon for **SkyrimNet** — it lets the AI driving your NPCs choose, in context, to
perform physical and intimate actions and react with facial expressions during roleplay. It hooks
into SkyrimNet through custom **actions, triggers, and decorators**.

*(add screenshots / a short demo clip here)*

## What to expect

Once everything is installed, your NPCs can — when it fits the scene and their personality —
**start or be drawn into these interactions on their own**, decided by SkyrimNet's model rather than
menus or hotkeys. Expect *emergent, unscripted* moments: a dominant NPC spanking someone bent over a
table, a captor escalating on a defeated victim, faces shifting to fear or pain in the moment, or
characters striking fitting body language while they speak.

- It is **player- and NPC-targetable** and leans **dark / non-consensual** by design; the tone follows
  the characters and context you set.
- Nothing fires at random — give characters fitting personalities and the LLM drives the rest. Master
  toggles and an intensity slider let you dial it back.
- It needs several frameworks and an animation pack (see **Requirements**) — without them, the relevant
  pieces simply do nothing rather than break.

## Features

- **Physical interactions** the LLM picks contextually:
  - Spanking — butt / face / breast slaps, with accumulating skin marks &amp; tattoos, impact sounds, and reactions
  - Grab hold, choke hold, struggle — paired animations with a resist QTE
  - Drug-food &amp; drunk exploit (incapacitate), womb hit
  - Forced kiss, fondle, touch / suck breasts, oral, examine / inspect
- **Escalation → SexLab or OStim** aggressive scenes, with defeat / bleedout &amp; recovery
- **Facial expressions** — happy / angry / afraid / sad / pained / surprised / confused
  - LLM-triggerable *and* automatic in-scene (fear in a struggle, pain on a choke / bleedout, sadness while crying)
  - Adjustable intensity
- **Reactions** — animated tears, face / tear overlays that survive sex scenes, cover-self after a spank
- **PrismaUI menus** for choosing interactions and setting up encounters

## Compatibility

Skyrim **SE (1.5.97)**, **AE (1.6.x)**, and **VR**. The SKSE plugin is built with
**CommonLibSSE-NG / CommonLibVR**, so a single `SkyrimNet_BakaIntegration.dll` runs on all three
runtimes. (VR additionally needs SkyrimNet and PrismaUI themselves to work in VR.)

## Requirements

**Core**
- [SkyrimNet](https://goncalo22.github.io/SkyrimNet-GamePlugin/Installation%20Guide/skyrimnet-installation/) (+ SKSE64, [Address Library](https://www.nexusmods.com/skyrimspecialedition/mods/32444))
- [PrismaUI](https://www.nexusmods.com/skyrimspecialedition/mods/148718)
- [PapyrusUtil](https://www.nexusmods.com/skyrimspecialedition/mods/13048), [MfgFix](https://www.nexusmods.com/skyrimspecialedition/mods/11669), [powerofthree's Papyrus Extender](https://www.nexusmods.com/skyrimspecialedition/mods/22854)
- [SlaveTatsNG](https://www.loverslab.com/files/file/35989-slavetatsng/) (or classic [SlaveTats](https://www.loverslab.com/files/file/619-slavetats/)) — for spank marks &amp; the sex-tear overlay. This mod bundles the `blank.dds` clear-texture, so SlaveTatsNG works without the old SlaveTats SE installed.
- **A sex framework for escalation scenes — SexLab _or_ OStim.** Pick it in the MCM (Auto uses whichever is installed). Neither is a hard requirement; without one, escalation just won't start a scene.
- [Emotional Tears Effect (EmoTears)](https://www.nexusmods.com/skyrimspecialedition/mods/122296) — for animated tears
- [Baka Motion Data Pack](https://www.loverslab.com/files/file/26992-baka-motion-data-pack/) — the paired interaction animations; build with **FNIS / Nemesis / Pandora**

**Optional (degrades gracefully if absent)**
- [Flash Games – Struggling QTE](https://www.nexusmods.com/skyrimspecialedition/mods/121909), [Dynamic Feminine Female Modesty Animations OAR](https://www.nexusmods.com/skyrimspecialedition/mods/104374)
- **SeverActions – SkyrimNet Action Pack** — *recommended for the downed/capture flow.* Not called by this mod and not a hard requirement, but its actions are automatically available to the LLM when installed, giving captors richer consequences on a beaten target: cease fighting, adjust relationship, take prisoner / arrest, add to debt or demand a ransom, transfer to a retainer, dismiss/recruit. The Baka downed cues invite these outcomes, so they "just work" alongside Baka's own choke/pin/grope/escalate actions.
- **Simple Slavery Plus Plus (SS++)** — *required for the `SellToSlavery` action to actually do anything.* This mod hands off to SS++'s own "SSLV Entry" mod event; without it installed, `SellToSlavery` just narrates the capture and nothing mechanical happens (no crash, no error, just no auction).
- **SkyrimNet Acheron Integration** — a separate, optional companion addon that manages the ongoing "downed" hold/recovery state after a combat defeat (as opposed to Baka's own QTE-based defeats, which this mod always handles by itself). **Baka Integration works fully standalone without it.** When both are installed, they hand a downed victim back and forth and even coordinate on creature encounters — but neither one requires the other.

## Installation

1. Install all requirements above.
2. Install this mod with your mod manager (MO2/Vortex), let it win conflicts for its own files.
3. Run **FNIS / Nemesis / Pandora** to generate the bundled paired animations.
4. Launch once so SkyrimNet loads the bundled action configs (`SKSE/Plugins/SkyrimNet/config/`).

## Configuration

MCM (and script properties) expose toggles:
- Scene framework selector (Auto / SexLab / OStim)
- `bExpressionsEnabled` — facial-expression master switch
- `fExpressionIntensity` (0.0–1.0) — how strong faces look
- spank cooldowns, male-target / player-target allowances, animated tears, etc.

## Notes & tips

- Run **Pandora / FNIS / Nemesis** after installing, or the paired animations will T-pose.
- Faces feel too strong or too flat? Adjust **`fExpressionIntensity`** (0.0–1.0) — there's no single right value, it depends on your follower/face setup.
- Actions are chosen by SkyrimNet's model **in context** — give your characters fitting personalities and dispositions, and the scene mostly drives itself. The action descriptions tell the model *when* each one fits.
- After updating, **reload SkyrimNet's config** (or restart) so new/changed actions are picked up.
- This addon contains explicit and **non-consensual** themes. It is fiction for adult roleplay — use it within your own comfort and local laws.

## Building from source

This mod's own Papyrus scripts are in `Scripts/Source/` (`SkyrimNet_Baka*.psc`, `SNBakaUI.psc`) — shared
so anyone can read, fork, or improve the logic. To **recompile** them you also need minimal compile stubs
for the dependency APIs (SkyrimNet, SexLab, OStim `OThread`, `MfgConsoleFunc`, po3, `SKI_ConfigBase`, etc.)
on the compiler import path; those aren't bundled here since they belong to their respective mods. Point the
Papyrus compiler at this `Scripts/Source/` folder **plus** the dependency mods' script sources.

The C++ source for `SkyrimNet_BakaIntegration.dll` is published in [`dll-source/`](dll-source/) (a
CommonLibSSE-NG / CommonLibVR project — see [`dll-source/BUILD.md`](dll-source/BUILD.md)). It's there
for transparency and forking; it is **excluded from the release archive** (end users only need the
prebuilt DLL). CommonLibVR is vendored as a git submodule, so clone with `--recurse-submodules`.

## Credits

- **SkyrimNet** — the framework this builds on
- Paired interaction animations — *Babo / SLAP* animation authors
- Cover-self reaction — driven by the *Dynamic Feminine Female Modesty Animations OAR* mod (Kahvipannu84 / Gunslicer); install it for that feature (no animations are bundled here)
- Facial-expression morph values — [Additional Expressions Project](https://www.nexusmods.com/skyrimspecialedition/mods/72337) (optional; the values are baked in, so it isn't required at runtime)
- Frameworks — SexLab, PrismaUI, PapyrusUtil, MfgFix, po3 Papyrus Extender, SlaveTats, EmoTears4NPCs
- CommonLibSSE-NG / CommonLibVR migration (single SE/AE/VR build) — **langfod**

> Bundled third-party animations/assets remain the property of their original authors and are
> included per their permissions. If you are an author and want something removed, open an issue.

## Links

- Nexus: **[add link]**
- Discord: **[add link]**
