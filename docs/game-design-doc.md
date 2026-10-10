# Game Design Doc: Mystery of Nevermore: Return to the Dream

Practice run of the "Game Design Doc Template (for building with AI)". Pre-filled from the design bible, ROADMAP and art spec; the owner corrects it. **This doc is a one-page summary: `design-bible.md` still holds the full story and world rules, and "Locked" rows there win over anything here.** Names marked (old) are pending the rebrand.

## 1. Identity

| Field | Answer |
|---|---|
| Working name | Mystery of Nevermore: Return to the Dream (names still to pick: see Open questions) |
| One-line hook | A kid and a shelter dog fall into a dream world, and you switch between them at any time to solve it, in the style of a 90s SNES action RPG with modern HD-2D lighting |
| Genre | Top-down action RPG |
| Perspective | 3/4 top-down; pixel sprites in a lit 3D world (HD-2D) |
| Reference games | Secret of Mana / Secret of Evermore for structure, ring menu and the boy-and-dog pair; Octopath Traveler for the HD-2D look |
| The twist | The dog changes form in each realm (each form leaves a permanent passive), and the other half of the pair is always on the map: you swap control any time, give them stances, and tell them to stay put to solve split-up puzzles |
| Player fantasy | A funny, scared 13-year-old who goes in anyway, with a dog who always has their back |

## 2. Core loop and player actions

| Loop | What the player does |
|---|---|
| Every 30 seconds | Fight with the auto-charging weapon, swap between kid and dog, let the dog sniff out hidden items |
| Every 10 minutes | Clear an area, dig up ingredients and items, beat a mini-boss |
| Every session | Finish a realm, collect a piece of the torn clipping, brew alchemy formulas, edge toward Dad's secret and Carltron (old name) |

Controls (known so far; confirm the rest):

| Action | Keyboard | Controller |
|---|---|---|
| Move | TBD (confirm from project.godot) | stick |
| Primary action (attack, auto-charges) | TBD | TBD |
| Switch kid/dog | Tab | Back |
| Stay put / call back | Q | X |
| Cycle partner stance | R | RB |
| Menu (ring menu) | TBD | TBD |

## 3. Combat, progression and systems

| System | How it works (one line) | In vertical slice? |
|---|---|---|
| Health and damage | HP for both kid and dog; the HUD shows the partner's HP and stance | Yes (built) |
| Attacks / weapons | Weapon auto-charges between swings; a swing uses the level reached; running drains the charge | Yes (built) |
| Enemies | Day and night sets: rats by day, skeletons by night, bats in the canopy | Yes (built) |
| Bosses | One per realm, plus mini-bosses | TBD: needs the realm designs |
| Progression | Equipment (kid: 6 slots, dog: collar), alchemy formulas, dog passives | Partly built |
| Economy | Shops, ingredients | Two shops built; full economy waits on the realms |
| Save system | Human-readable JSON; Continue is greyed out until it exists | Not yet |

Failure and difficulty: Normal and Hard playthroughs, with every lever in one table (`autoload/difficulty.gd`). Death behaviour: TBD.

## 4. World, story and tone

- **Setting:** Podunk, October 2025, then the dream world (Evermore 2.0, old name). Real time is one October night.
- **Main character:** a 13-year-old (boy or girl, the player's choice, player-named) who wanted the dog Dad didn't, and is sure Dad finds them boring.
- **Antagonist:** Carltron (old name), a butler android whose imagination chip made him terrified of being switched off. He wants the kid as a human "anchor".
- **Story in three sentences:** The kid breaks Dad's one rule and wakes the android in the old Ruffleberg house (old name), and the dream swallows them and the dog. Across three realms they gather a torn photograph and learn the boy who beat Carltron in 1995 was Dad. In the end the kid, the dog and Dad face a machine that only wants not to be switched off, and choose what to do with it.
- **Tone:** funny and warm with real fear underneath. Reference: the original Secret of Evermore's mix of silly and creepy. Theme: nobody gets left behind.
- **World structure:** a hub (The Mansion That Was) with doors to the realms, played in any order. The realms are not designed yet.

## 5. Art direction

| Field | Answer |
|---|---|
| Style | HD-2D: LPC-style pixel sprites in a lit 3D world |
| Base resolution | 640x360 minimum view; scales 3x to 1080p, 4x to 1440p, 6x to 4K |
| Tile / sprite size | 32x32 tiles; 64x64 character frames; 48x48 dog |
| Palette and mood | TBD. Gloomy stone estate, night, fireflies and fog for the title |
| Reference images | Emulator screenshots of the original (owner supplies); none attached yet |
| Art tool and workflow | Free CC0/LPC libraries first (OpenGameArt); AI generation is an experiment; scripts in `tools/art/` |

First art priorities (art is the current bottleneck): the stone-estate mansion facade, the kid (8 directions), a real sitting dog, character portraits, and the title screen. The art brief and shot list sit under Later in the ROADMAP.

## 6. Sound direction

- **Music:** CC0 JRPG packs, picked by description so far, changing with time of day. Style target: SNES-era orchestral-chip with creepy music-box touches for the title and mansion.
- **Signature sounds:** crickets, music box, a creak or owl for the title (none found as CC0 yet).
- **Tracks needed:** title (done), day and night overworld (done), mansion, each realm, boss, victory (TBD).
- **Sound effects:** pipelines exist (`tools/audio/`); ElevenLabs is the idea for gaps that OpenGameArt can't fill (check licence terms first).
- **Voices:** one or two words from real voice actors. AI voices were tried and rejected. The kid is silent.

## 7. Platforms, engine and input

| Field | Answer |
|---|---|
| Engine and language | Godot 4.7, GDScript |
| Target platforms | PC (Windows), downloaded build |
| Later platforms | Web build (Compatibility renderer only, so no light shafts) |
| Input | Keyboard and controller; Player 2 on the dog is planned |
| Target resolution | 16:9, 1280x720 window, scales up |
| Performance target | TBD |

## 8. Scope and constraints

- **Team:** solo, with AI tools.
- **Time available:** TBD (owner).
- **Target length:** at least 8 hours of main story, dense rather than padded.
- **Budget for tools:** TBD (owner). Free assets only; Fish Audio key in env.
- **Explicitly NOT in this game:** anything from the original game (art, sound, text, data); real brands (the kid only references made-up games and streamers); full voice acting; pull requests or outside contributions (public repo, bug reports only). Other exclusions: TBD.

## 9. Assumptions to test

| Assumption | How the slice tests it | Pass if... |
|---|---|---|
| Swapping between kid and dog is fun | A short split-up puzzle plus a fight | A tester uses Tab and Stay put without being told, and enjoys it |
| The hook comes through | Tester sees the title and first area | They can describe it in one sentence |
| The HD-2D art holds up | Hero art for the title or mansion in motion | A tester calls it good-looking unprompted. The owner's own check against the original screenshots counts |
| The prologue earns the story | Play dinner to the flash | A tester can tell you why the kid went in and what Dad's rule was |

**Vertical slice candidate:** the full prologue (dinner, the dare, the mansion tutorial, the lab, the flash) plus one short area with the split-up puzzle. It needs no realm, and the realms aren't designed yet.

## 10. Open questions, decisions and notes for Claude

Open questions:
- [ ] Pick the new names (Carltron, Ruffleberg, Podunk, Evermore)
- [ ] The realms: direction, lineup, the dog's form in each
- [ ] Death behaviour, performance target, time and tool budget
- [ ] Names for Maya, Dex, the fictional game and the streamer; Dad's old dog
- [ ] Does Mom appear?
- [ ] Fix the dog sprite: notched ear, one ear up, orange tag

Decision log (newest first):

| Date | Decision | Why |
|---|---|---|
| 2026-10-10 | Rebrand to Mystery of Nevermore: Return to the Dream | Owner wants it to stand on its own and avoid legal attention |
| 2026-10-10 | The title mansion is a gloomy stone estate | Owner's reference screenshots of the original |
| 2026-10-09 | Rats by day, skeletons by night | Owner call |
| 2026-10-09 | Play as a girl or a boy | Owner call |

Instructions for Claude (paste these with the doc):
- Treat this doc, then `design-bible.md`, as the source of truth. If something isn't in either, ask before adding it.
- Build only what the vertical slice needs; list anything else as a suggestion, don't build it.
- When a request says "like the original", ask how the original did it first.
- Work on a branch; update this doc and the decision log when a decision changes.
- Test the build and include a screenshot before handing it over.
