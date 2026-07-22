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

## How it works

### The Interact power

Everything the LLM can do on its own, you can also trigger yourself with the **Interact power** — a
lesser power added to your spell list automatically once the mod is set up. It's aimed like any other
power or shout:

- Point your crosshair at an NPC and cast it — a PrismaUI menu opens with **Affectionate / Forced /
  Sexual** categories to pick an action from.
- Aim it at someone **downed or bleeding out** instead, and you get a different menu — Escalate, Help
  Up, Tie Up, Execute, Release, and so on.
- Cast it **during your own sex scene** (no target needed) to open a spank menu for your partner(s).
- Aim it at a **supported hostile creature** and, if creature escalation is enabled, it attempts to pin
  the nearest valid victim directly instead of opening a menu.
- A target already locked in another interaction or mid-scene is refused outright — the power won't
  interrupt something already running.

Think of it as the deliberate, player-driven half of the mod; the LLM-driven half is the same set of
actions chosen contextually by SkyrimNet's model during roleplay.

### MCM options

Settings are split across six pages:

- **General** — master enable, whether the player can be targeted, target-sex filter, animated tears,
  AI action cooldown; a **Capture** section (Sell to Slavery, Follower Enslavement, and the
  player-distance gate for it); and an emergency **panic reset** for stuck actor states.
- **Timing** — how long each paired animation loop/stage holds (hug, molest, kiss, touch, sequence
  stages).
- **Resist** — the struggle QTE (on/off, escape difficulty), NPC-vs-NPC auto-rolled struggles (escape
  chance, stage duration, post-escape grace), and the fallback defeat window/QTE difficulty.
- **Spank** — behaviour toggles (player can be spanked, male targets, furniture reactions) and
  tattoo-mark pacing (spanks per stage, hours per stage).
- **Scenes & FX** — sex framework selector (Auto/SexLab/OStim); facial expressions (on/off +
  intensity); the whole **Creatures** block (master toggle, can-target-the-player, mid-combat,
  escalate-on-hit chance, escalate-to-sex, LLM-gated escalations, victim-sex filter, framework,
  success chance, group size, and more); corner notifications and debug logging; and the humanoid
  mid-combat escalate-on-hit settings.
- **Plugins** — toggles for optional third-party integrations, each auto-greyed-out when the
  corresponding mod isn't installed.

## Features

- **Physical interactions** the LLM picks contextually:
  - Spanking — butt / face / breast slaps, with accumulating skin marks &amp; tattoos, impact sounds, and reactions
  - Grab hold, choke hold, struggle — paired animations with a resist QTE
  - Drug-food &amp; drunk exploit (incapacitate), womb hit
  - Forced kiss, fondle, touch / suck breasts, oral, examine / inspect
- **Escalation → SexLab or OStim** aggressive scenes, with defeat / bleedout &amp; recovery
- **Creature encounters (opt-in, OFF by default)** — supported creature types (falmer, draugr,
  giants, wolves, rieklings, spiders, chaurus, trolls…) can pin a victim in a paired struggle QTE
  and, on a win, claim them in a scene:
  - Proximity attempts on **downed** victims every few seconds, plus optional **on-hit mid-combat
    grapples** (own toggle + chance slider) for followers and the player
  - **Struggle vs escalate split** — "Escalate to Sex After Win" OFF gives pure predator struggles:
    a beast mauling its prey, no scene ever starts, no adult creature animation packs needed
  - **Group scenes** — up to two same-type companions join (3v1 / 2v1), automatically falling back
    3 → 2 → pair until your animation library actually has a scene for that size and creature type
  - Optional **LLM gate** — SkyrimNet's model answers a strict yes/no ("should this escalation
    happen right now?") before any downed-victim claim; pacing control by the narrator itself
- **Downed = vanilla mortality + executions** — no artificial invulnerability while defeated: any
  weapon-delivered hit (melee, **fists**, **arrows/bolts** — never spells or stray magic) on a
  defeated actor is a killing blow. Essential/protected actors survive it; victims mid-struggle or
  mid-scene are untouchable, and every exit carries a short post-escape mercy window so nobody gets
  spawn-killed the frame protection drops. An **Execute** action (menu button + LLM-callable) gives a
  guaranteed finishing blow that doesn't depend on a weapon hit actually landing and registering.
- **Tied prisoners** — bind a defeated victim (**TieUp**) instead of resolving them immediately: they
  stay down for an MCM-configured number of game hours (default 12), can't struggle free or
  auto-recover while bound, and can still be escalated on and returned to their bound pose
  afterward. **Untie** cuts them loose to a normal down; **HelpUp** does both at once. Bindings also
  loosen on their own once the timer runs out.
- **Facial expressions** — happy / angry / afraid / sad / pained / surprised / confused
  - LLM-triggerable *and* automatic in-scene (fear in a struggle, pain on a choke / bleedout, sadness while crying)
  - Adjustable intensity
- **Reactions** — animated tears, face / tear overlays that survive sex scenes, cover-self after a spank
- **PrismaUI menus** for choosing interactions and setting up encounters
- **Paired-animation physics fix** — both actors' Havok bumper capsules shrink to 5% of vanilla for
  the duration of any paired animation (exact radii cached per actor and restored afterward, never a
  shrink-of-a-shrink), so partners stop physically shoving each other out of alignment mid-pose

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
- **A sex framework for escalation scenes — SexLab _or_ [OStim Standalone (OStim SA)](https://www.nexusmods.com/skyrimspecialedition/mods/98163).** Pick it in the MCM (Auto uses whichever is installed). Neither is a hard requirement; without one, escalation just won't start a scene.
- [Emotional Tears Effect (EmoTears)](https://www.nexusmods.com/skyrimspecialedition/mods/122296) — for animated tears
- [Baka Motion Data Pack](https://www.loverslab.com/files/file/26992-baka-motion-data-pack/) — the paired interaction animations; build with **FNIS / Nemesis / Pandora**

**Optional (degrades gracefully if absent)**
- [Flash Games – Struggling QTE](https://www.nexusmods.com/skyrimspecialedition/mods/121909), [Dynamic Feminine Female Modesty Animations OAR](https://www.nexusmods.com/skyrimspecialedition/mods/104374)
- [OCreatures Revived](https://www.loverslab.com/files/file/49059-ocreatures-revived/) — *needed for the creature escalation feature to actually produce a scene.* This mod doesn't call OCreatures directly; it hands a downed victim and a nearby beast off to your sex framework (SexLab/OStim) the same way any human escalation does. OCreatures is what makes non-vanilla creature races compatible with that framework in the first place — without it, creature escalation can still trigger narratively but the resulting scene may not work correctly. **You also need creature animation packs** (e.g. Billyy's, Anub's) actually covering each creature type: scenes are only started when a matching animation exists (group sizes fall back 3 → 2 → pair automatically; a type with no pair animation at all gets a clean refusal + a 5-minute backoff instead of a retry loop). The struggle/pin phase itself uses the bundled Baka Motion Data Pack and needs nothing extra.
- **SeverActions – SkyrimNet Action Pack** — *recommended for the downed/capture flow.* Not called by this mod and not a hard requirement, but its actions are automatically available to the LLM when installed, giving captors richer consequences on a beaten target: cease fighting, adjust relationship, take prisoner / arrest, add to debt or demand a ransom, transfer to a retainer, dismiss/recruit. The Baka downed cues invite these outcomes, so they "just work" alongside Baka's own choke/pin/grope/escalate actions.
- **Simple Slavery Plus Plus (SS++)** — *required for the `SellToSlavery` action to actually do anything.* This mod hands off to SS++'s own "SSLV Entry" mod event; without it installed, `SellToSlavery` just narrates the capture and nothing mechanical happens (no crash, no error, just no auction). Targets the defeated **player** only — the follower counterpart is the Follower Slavery Mod hand-off below, and the two are deliberately kept disjoint so the LLM can never confuse them.
- **Follower Slavery Mod (FSM)** — *required for the `EnslaveFollower` action to do anything.* Lets NPCs drag the player's **downed follower** off into FSM's own enslavement questline (via its documented `fsm_enslavefollower` mod event, with the captor offered as master) — but only while the player is downed too or farther away than an MCM-configurable distance, so it can never happen under your nose. **OFF by default** (it permanently removes a follower from the party until freed through FSM); the action is removed from the LLM's menu entirely whenever FSM is absent, not yet initialized in its own MCM, or the toggle is off.
- **SkyrimNet Acheron Integration** — a separate, optional companion addon ([GitHub](https://github.com/Around906/SkyrimNet-Acheron-Integration)) that manages the ongoing "downed" hold/recovery state after a combat defeat (as opposed to Baka's own QTE-based defeats, which this mod always handles by itself). **Baka Integration works fully standalone without it.** When both are installed they hand a downed victim back and forth seamlessly — including the "park" design, where a victim who loses a struggle rides Acheron's protected defeat state straight through scene prep and the scene itself, with no unprotected handoff windows for enemies to exploit — and they coordinate on creature encounters, the get-up key's charge bar, and recovery. Neither one requires the other.

## Installation

1. Install all requirements above.
2. Install this mod with your mod manager (MO2/Vortex), let it win conflicts for its own files.
3. Run **FNIS / Nemesis / Pandora** to generate the bundled paired animations.
4. Launch once so SkyrimNet loads the bundled action configs (`SKSE/Plugins/SkyrimNet/config/`).

## Configuration

MCM (and script properties) expose toggles:
- Scene framework selector (Auto / SexLab / OStim)
- **Creatures block** (all opt-in): master toggle, can-target-the-player, allow mid-combat,
  escalate-on-hit (+ chance), **Escalate to Sex After Win** (OFF = struggle-only predator mode),
  NPC success chance, struggle duration, **LLM Decides Escalations**
- **Slavery pair**: *Sell to Slavery* (defeated player → Simple Slavery++) and *Follower
  Enslavement* (downed follower → Follower Slavery Mod) with its player-distance slider — each
  grayed out until its mod is detected, each removable from the LLM's menu independently
- **Tied Hours** — how many game hours a `TieUp` prisoner stays bound before the ropes loosen on
  their own (default 12)
- **Post-Escape Grace** — the untouchable mercy window after every struggle/scene exit
- `bExpressionsEnabled` — facial-expression master switch
- `fExpressionIntensity` (0.0–1.0) — how strong faces look
- **Show Corner Notifications** / **Enable Debug Logging** — clean-HUD and clean-log switches for
  normal play (keep logging ON when reporting issues)
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
