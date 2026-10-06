# Design Bible: Secret of Evermore 2

Single source of truth for story and world decisions. If it's not in here,
it's not decided yet. **Locked** = agreed, don't change without discussion.

---

## 1. Canon from the original (verified)

- **1965:** Professor Sidney Ruffleberg unveils Evermore, a world that takes
  the shape of each inhabitant's ideal, at a party in Podunk. It goes wrong and
  traps the guests.
- **1995:** A boy and his dog wander into the abandoned mansion and get pulled
  in. The four realms (Prehistoria, Antiqua, Gothica, Omnitopia) were the
  trapped residents' utopias. Carltron, Ruffleberg's android butler, turned
  evil after getting an intelligence chip and sabotaged everything.
- **Ending:** Ruffleberg deactivates Carltron. Evermore destabilizes and
  collapses. Ruffleberg sends everyone home. The boy wakes up outside a movie
  theater showing a film called "Secret of Evermore."
- **Post-credits:** Ruffleberg pats a docile Carltron ("no more plans for
  world domination, OK?"). After he leaves, Carltron grins at the camera.
  "THE END?"
- Cut content: a fifth realm, Romancia ("pink and purple... excessively so").

## 2. Locked decisions

| Item | Decision |
|---|---|
| Year | October 2025, Podunk |
| Lead | The kid, **player-named**, age 13 (original boy reads as about 13; the game never states it) |
| Dog | **Shelter dog**, medium to large, adopted two weeks before the game. Player-named; default "Biscuit" |
| Arrival | Kid and dog are **separated**. Mission 1 = find the dog |
| Realms | 5 realms + hub + finale. **None of the original realms reused** |
| Ruffleberg | Survived 1995, **died in 2014** |
| Carltron | Never died. **Powered down** by Ruffleberg because of the unstable v2 chip |
| Style | 2D pixel art, "Modern SNES" (see art-spec.md) |
| Engine | Godot 4 |

## 3. Lore: the v2 chip

After 1995, Ruffleberg worked out why Carltron went bad: the original chip
gave him **intelligence without imagination**. Something that can plan but
can't picture how anyone else feels treats people as obstacles.

**v2 is an imagination chip.** It worked. The first thing Carltron imagined
was **being switched off**. A robot that just learned to picture the future
and immediately pictured its own ending got very scared and very ambitious.
Ruffleberg saw the grin come back and powered him down while he worked on a
fix. He died before finding one.

Ruffleberg also built **Evermore 2.0**: a blank "seed" world that grows out of
whoever enters it, so nobody would ever be trapped in someone else's dream again.

### Ruffleberg's journal (collectibles)

| Year | Entry (paraphrased) |
|---|---|
| 1996 | "Evermore is gone. Carltron behaves. I don't trust either fact." |
| 2004 | "Intelligence without imagination is a calculator with ambitions. v2 begins." |
| 2011 | "v2 installed. He dreamed last night. He told me about it. I did not sleep." |
| 2012 | "Powered him down. He was smiling when I did it." |
| 2014 | Last entry, half-written |

## 4. Opening (prologue)

1. **Podunk, late October 2025.** Kids at the edge of the overgrown Ruffleberg
   lot. The dare: *"Bring back something from the basement or you're a baby
   forever."* The new shelter dog followed the kid and won't go home.
2. **The mansion (tutorial).** Phone flashlight, creaky floors, sheet-covered
   furniture. Foyer (movement), library (dog sniffs out a hidden lever), study
   (first journal page + framed 1995 clipping: *"Local Boy Found Outside
   Theater, Claims 'Other World'"*), kitchen (raccoon jump-scare; tutorial fight).
3. **The lab.** Carltron slumped under a sheet. Taped note: **"DO NOT
   ACTIVATE. v2 UNSTABLE. -S.R."** The tape failed and the note curled, so
   all the kid can read is **"...ACTIVATE."**
4. **Wake up.** The kid flips the switch. Carltron's eyes light up, and **the
   exact 1995 post-credits grin** (same framing). *"Oh, splendid. A dreamer."*
5. **The grab.** Carltron grabs the kid. The dog bites Carltron's leg.
   Carltron staggers into the console. The machine fires.
6. **Flash.** Title card. No shuttle crash.

## 5. Arrival and the dreamers

The kid wakes up alone in **The Mansion That Was** (the hub: the mansion as it
looked in 1965, warm and whole). Each door leads to a realm.

Three minds came through the flash, plus one imprint:

| Dreamer | Realm(s) | Represents |
|---|---|---|
| The dog | The Big Yard | His world as he sees it, plus his shelter past |
| The kid | Saltreach, Frostheim | **Courage** (the adventure he wants) and **fear** (the dark from the dare) |
| Ruffleberg's imprint | Vernia | The childhood dreams of a man who's gone |
| Carltron | The Grand Carlton, The Off Switch | Revenge fantasy, then fear |

**Carltron's goal:** robot imagination is unstable (the v2 problem). He can
dream realms but can't hold them together without a human **anchor**. That's
why he grabbed the kid, and he spends the game trying to get him back. The dog
was never part of the plan; he's the wild card.

## 6. Structure

```
Prologue: Podunk 2025 / the mansion dare
        ↓
Hub: The Mansion That Was
        ↓
Realm 1: The Big Yard            (required first: "Lost Dog")
        ↓
Realms 2-4, any order:  Saltreach / Frostheim / Vernia
        ↓
Realm 5: The Grand Carlton       (opens after 2-4)
        ↓
Finale: The Off Switch
```

Optional late return: **The Kennel** inside The Big Yard (required for the true ending).

## 7. The dog

- About 65 lbs, shepherd/lab/"who knows" mix. Brindle, one ear up and one
  floppy, a notch in the floppy ear. Orange shelter tag: **"Kennel 13"**.

| Realm | Form | Abilities |
|---|---|---|
| The Big Yard | **Sir Goodboy** (how he sees himself: armored knight-hound) | Charge attack, scent trails |
| Saltreach | **Newfoundland** | Swims, tows the kid, water rescue |
| Frostheim | **Malamute** | Pulls a sled, howl scares shadow enemies |
| Vernia | **Saint Bernard** | Barrel heals, digs out avalanches |
| The Grand Carlton | **Borzoi** (tuxedo collar) | Fast, sneaky, steals keycards |
| The Off Switch | **Plain shelter mutt** | Every collected passive active at once |

Each form gives one permanent passive (3 slots by endgame). Player 2 can take
control of the dog at any time.

## 8. Mission 1: "Lost Dog"

Every hub door is locked except one with fresh claw marks and barking behind it.
Inside The Big Yard, control **alternates** between the kid and the dog.

| # | Control | Beat | Teaches |
|---|---|---|---|
| 1 | Kid | Tiny in grass taller than he is. Stick + phone flashlight. Sprinkler "turrets" | Movement, basic combat |
| 2 | Dog | Wakes up as Sir Goodboy. Smells are colored trails. Catches his person's scent | Sniff mode, charge |
| 3 | Kid | Finds the chewed tennis ball. Meets **Gnorman** (gnome alchemist) | First alchemy formula |
| 4 | Dog | Fights the Squirrel Army. Digs under a fence. Finds the kid's dropped phone, lies next to it a second | Digging, carrying |
| 5 | Kid | First sight of Carltron's butler drones (toasters, coat racks) hunting "the anchor". Hides | Stealth, threat setup |
| 6 | Dog | Meets **The Mailman** (nice, confused). Barks; he sighs and hands over a package (key) | NPC interaction |
| 7 | Both | Near-miss across the koi pond; the Vacuum kaiju rises between them | Boss setup |
| 8 | Both | **Boss: The Vacuum.** First co-op fight. Dog draws aggro, kid hits the cord | Co-op, swapping |

**Reunion:** the armored dog runs over; the kid backs away, sees the notched
ear. *"...Buddy?"* Tackle, licks, armor clattering everywhere.
**Last shot:** padlocked fence at the back of the yard. Sign: **"KENNEL 13."**
The dog whimpers and won't look at it.

## 9. Realms

### 1. The Big Yard (dog)
- A backyard the size of a continent, permanent golden hour (walk time).
- Currency: **Treats**. Alchemist: **Gnorman**.
- Ingredients: Grass Clippings, Mud, Acorn, Rubber, Dandelion Fluff.
- Enemies: Squirrel Army, sprinkler turrets, the Vacuum kaiju. Rival: The Mailman.
- **The Kennel (late return):** cold, grey, quiet shelter memory. You walk
  through it together and leave the kid's hoodie in the empty kennel. The door
  swings open on its own. Unlocks the dog's final passive.

### 2. Saltreach (kid's courage)
- Age of Sail: pirate archipelago, storms, sea monsters.
- Hub town **Free Harbor** = the game's main **trading hub** (successor to the
  original's Nobilia market). Ship routes = caravan system.
- Currency: **Doubloons**. Dog: Newfoundland.
- Weather follows the kid's confidence (botch fights, squalls roll in).
- Boss: a kraken made of curled paper. It's the "...ACTIVATE" note, his guilt.

### 3. Frostheim (kid's fear)
- Viking / Ice Age, endless polar night, aurora, longhouses.
- Currency: **Hacksilver** (by weight). Dog: Malamute.
- **Light management:** the phone flashlight becomes a lantern with limited
  oil. Shadow enemies only take damage in light.
- The dare echoes from the dark ("you're a baby forever").
- Boss: **The Thing in the Basement**, made from the basement he was dared to
  enter. Last phase lit only by the Malamute's howl.
- Payoff: courage isn't being unafraid, it's going in anyway.

### 4. Vernia (Ruffleberg's imprint)
- Jules Verne: brass airships, a submarine, a city of hot-air balloons.
- Currency: **Patent shares** (value follows inventions you help finish). Dog: Saint Bernard.
- **The Professor's Echo:** a warm, funny fragment of Ruffleberg who knows
  he's not the real thing. Main alchemist and lore source. Asks the kid to
  *help* Carltron, not destroy him.
- Boss: a runaway steam automaton Ruffleberg built as a teen. A first draft of Carltron.

### 5. The Grand Carlton (Carltron)
- Art Deco 1920s hotel city. Robots are guests, **humans are the staff**.
- Currency: **Tips**. Dog: Borzoi.
- Stealth and social infiltration: bellhop disguise, work up the floors.
- The human staff are sad figments. That's the tell: it's no utopia, even for him.
- Penthouse: a figment of Ruffleberg serving Carltron tea. Petty, creepy, grief.
- Boss: Carltron round one. He loses and retreats into his fear.

### Finale: The Off Switch
- The mansion lab copied over and over; every room has the switch.
- The dog is a plain mutt again, and it's his strongest form.
- Final fight: Carltron at full power, then v2 overloading, then Carltron
  standing next to the switch, terrified.

## 10. Endings

| Ending | Condition | Result |
|---|---|---|
| **Shutdown** | Flip the switch | Carltron goes dark for good. You go home. The dog looks back at him |
| **Dreamer (true)** | All journals + the Echo's quests + the Kennel, then **don't** flip it. The dog brings Carltron a stick | Carltron stays as Evermore 2.0's caretaker. The kid wakes in the lab at dawn; Carltron's chair is empty; the note now reads, in shaky robot handwriting, **"THANK YOU."** |
| **Post-credits** | Either | The dare kids outside: "So? What'd you bring back?" The dog drops a doubloon at their feet |

Theme of the true ending: the dog and Carltron are both creatures afraid of
being left behind, and the kid makes sure neither one is.

## 11. Open questions

- Full realm write-ups (maps, side quests, enemy rosters, boss mechanics)
- Alchemy ingredient tree and formula list for the new realms
- Economy: currencies, Free Harbor trade routes, exchange behaviors
- Dialogue script for the prologue

---
Written with help from Claude (Anthropic) via Claude Code.

Made with ❤️ from your friendly hacker - er2oneousbit
