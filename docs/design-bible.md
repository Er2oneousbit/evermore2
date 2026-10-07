# Design Bible: Secret of Evermore 2

Single source of truth for story and world decisions. If it's not in here,
it's not decided yet. **Locked** = agreed, don't change without discussion.
**DRAFT** = proposed, waiting for the owner's review.

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
| Arrival | Kid and dog are **separated** when they arrive in Evermore 2.0 |
| Length | **At least 8 hours of play** for the main story (the original runs roughly 15 to 20). Density over length: every area earns its time with people, challenges, secrets and set pieces; each realm has multiple areas, challenges and mini-bosses |
| Realms | **To be designed** (the first lineup was scrapped on 2026-10-06, see section 8). Rule that stays: **none of the original realms are reused** |
| Ruffleberg | Survived 1995, **died in 2014** |
| Carltron | Never died. **Powered down** by Ruffleberg because of the unstable v2 chip |
| The 1995 boy | **The kid's dad**, now 43. He never told anyone what happened. Never named on screen, as in the original |
| Kid's voice | **Modern kid references**, but only to **fictional** games, streamers and memes made up for this world (no real brands; ages slower) |
| Stakes | An anchored kid **never wakes up**: trapped in Evermore 2.0, as the 1965 guests were for 30 years. Real time is **one October night** |
| Style | **HD-2D**: pixel-art sprites (LPC library, 32 px) in a lit 3D world, like Square Enix's Octopath Traveler / DQ3 HD-2D. Free assets only (see art-spec.md) |
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

**Carltron's goal:** robot imagination is unstable (the v2 problem). He can
dream worlds but can't hold them together without a human **anchor**. That's
why he grabs the kid, and he spends the game trying to get him back. The dog
was never part of the plan; he's the wild card.

### Ruffleberg's journal (collectibles)

| Year | Entry (paraphrased) |
|---|---|
| 1996 | "Evermore is gone. Carltron behaves. I don't trust either fact." |
| 2004 | "Intelligence without imagination is a calculator with ambitions. v2 begins." |
| 2011 | "v2 installed. He dreamed last night. He told me about it. I did not sleep." |
| 2012 | "Powered him down. He was smiling when I did it." |
| 2014 | Last entry, half-written, addressed to the 1995 boy |

## 4. The story spine (DRAFT, for review)

**Logline.** A 13-year-old breaks the one rule his dad never explained ("stay
away from the Ruffleberg place"), wakes a robot that has been afraid of the dark
for thirteen years, and has one night to find his dog, learn his father's secret,
and decide what to do with a machine that just wants to not be switched off.

**Theme: nobody gets left behind.** Everyone in the story is afraid of it:
- **the dog** was left at a shelter
- **Carltron** was switched off in the dark
- **Dad** came back from Evermore in 1995 to a town that called him a liar, so he stopped talking about it, and went quiet with his own son too
- **the kid** feels left out of whatever his dad won't say

The second theme: courage isn't being unafraid, it's going in anyway.

### Cast

| Who | Draft |
|---|---|
| **The kid** (player-named, 13) | Lives with his dad; his mom works night shifts at the county hospital (which is why nobody notices he's gone). Funny, online, quick with a reference, secretly sure his dad finds him boring. He wanted the dog; Dad didn't |
| **The dog** (default "Biscuit") | Adopted from the shelter two weeks ago, the kid's idea. Already sleeps on his bed |
| **Dad** (43, never named) | The boy from 1995. Kept one thing from that night: his own dog's collar, in a drawer. That dog died the year before the kid was born (the kid has never heard of him), and Dad never wanted another, because losing him was worse than anything in Evermore. Quotes old B-movies nobody gets; the kid groans every time |
| **Carltron** | Wants a human anchor so his dreamed world can hold together and nobody can ever switch him off. Recognizes the kid's face: **it's the face of the boy who beat him in 1995.** His revenge fantasy has a target now |
| **The Professor's Echo** | A warm, funny fragment of Ruffleberg who knows he isn't the real thing. Knew the 1995 boy. Asks the kid to *help* Carltron. Where he lives is open (the realms are) |
| **Maya** (13, placeholder name) | The kid's best friend. Came to the dare to talk him out of it. Stays at the fence. Hours later, she's the one who calls his dad |
| **Dex** (14, placeholder name) | Made the dare. Not a monster, just a kid who's never been told no |

### The kid's voice (rule of thumb)

He references things that exist only in this game's world: the battle-royale
everyone plays (working title *Dropzone Dynasty*), the streamer he quotes
(working title *GlitchGoblin*), the meme of the week. Never real brands. Dad
answers with 1990s B-movie quotes (also made up). Payoff: in the last scene, the
kid quotes one of Dad's movies, on purpose.

### The clipping (how the dad reveal works in any order)

In the prologue the study holds a framed 1995 clipping, *"Local Boy Found
Outside Theater, Claims 'Other World'"*, with the photo **torn into three and
the name torn off.** Three realms (to be designed, playable in any order) each
end with one piece.

| Pieces | What the kid sees |
|---|---|
| 1 | A dog's paw and part of a jacket |
| 2 | Part of a face. Something about it is familiar |
| 3 | The whole photo: a 13-year-old with his dog, outside the Podunk movie theater. He's seen that face in his own family photos. **It's Dad.** |

The third piece leads to Carltron. He has been waiting: *"Oh, you've finally
worked it out. You have his face, you know. I'd know it anywhere."*

### Acts (realm slots open)

| Act | What happens |
|---|---|
| **1. The dare** | Dad's rule, the dare, the curled note, Carltron wakes, the flash |
| **2. Alone** | Wake in the hub; find the dog (kid and dog arrive separated); Carltron is hunting "the anchor" |
| **3. Three pieces** | Three realms, any order, one photo piece each. Dad's secret comes together |
| **4. Carltron's ground** | Face Carltron's own dream; beat him once; he flees into his fear |
| **Interlude: 3:12 a.m.** | Play as **Dad** in the real mansion (below) |
| **5. Dad's dream** | Dad enters Evermore 2.0 (below) |
| **6. The finale** | Kid, dog and Dad face Carltron; the choice |

### Interlude: 3:12 a.m. (DRAFT)
- Maya waited at the fence for hours, then called the kid's dad.
- **Play as Dad**, an adult with a phone flashlight, walking the same mansion
  the kid walked in the prologue, room for room. He knows the way. That's the
  scariest part.
- The lab: his son asleep at the console, the dog asleep against his legs. They
  won't wake. The curled note, which Dad flattens and reads whole: **"DO NOT
  ACTIVATE."** Ruffleberg's last, half-written journal entry, addressed to him.
- He swore he'd never go back. He sits down at the console and goes back.

### Dad's dream: Main Street, 1995 (DRAFT; kept because it belongs to the dad story, not the realm lineup)
- A new door in the hub: Evermore 2.0 grows from whoever enters it, and Dad's
  dream is the night he came home in 1995.
- Podunk's Main Street at dusk, the theater marquee lit. **Dad is 13 here**, in
  his 1995 jacket, the boy from the photo. Same age as his son.
- No combat. A walk. His old dog is waiting outside the theater, and Dad gets to
  say the goodbye he never got to say. The kid's dog and the old dog touch noses.
- Young Dad joins for the finale.

### The offer (DRAFT)
Before the end, Dad offers himself as Carltron's anchor so his son can go home.
Carltron is tempted (the boy who beat him, his forever). The kid refuses:
nobody gets left behind, not Dad, and in the true ending not Carltron either.

## 5. Opening (prologue)

*Playable through step 1 (dinner and the dare): the first-draft lines are in
`data/dialogue/prologue.dlg`. Dinner currently plays over black.*

0. **(Draft) Dinner, the same evening.** Dad, the kid, the dog under the table.
   The kid mentions the Ruffleberg place. Dad goes still: *"Stay away from that
   house."* No reason given. Mom's shift starts at seven.
1. **Podunk, late October 2025.** Kids at the edge of the overgrown Ruffleberg
   lot. The dare (Dex's): *"Bring back something from the basement or you're a
   baby forever."* Maya tries to talk the kid out of it, then waits at the
   fence. The new shelter dog followed the kid and won't go home.
2. **The mansion (tutorial).** Phone flashlight, creaky floors, sheet-covered
   furniture. Foyer (movement), library (dog sniffs out a hidden lever), study
   (first journal page + framed 1995 clipping: *"Local Boy Found Outside
   Theater, Claims 'Other World'"*, photo torn into three, name torn off; the
   kid pockets what's left of the frame), kitchen (raccoon jump-scare; tutorial fight).
3. **The lab.** Carltron slumped under a sheet. Taped note: **"DO NOT
   ACTIVATE. v2 UNSTABLE. -S.R."** The tape failed and the note curled, so
   all the kid can read is **"...ACTIVATE."**
4. **Wake up.** The kid flips the switch. Carltron's eyes light up, and **the
   exact 1995 post-credits grin** (same framing). *"Oh, splendid. A dreamer."*
5. **The grab.** Carltron grabs the kid. The dog bites Carltron's leg.
   Carltron staggers into the console. The machine fires.
6. **Flash.** Title card. No shuttle crash.

## 6. The hub

The kid wakes up alone in **The Mansion That Was**: the mansion as it looked in
1965, warm and whole. Its doors lead to the realms (to be designed). A new door
appears when Dad comes in (section 4).

## 7. The dog

- About 65 lbs, shepherd/lab/"who knows" mix. Brindle, one ear up and one
  floppy, a notch in the floppy ear. Orange shelter tag with his kennel number.
- **Keeps the series hook:** the dog changes form in each realm, and each form
  leaves him one permanent passive. The forms get designed with the new realms.
- In the finale he's a plain shelter mutt again, with every passive at once.
- Player 2 can take control of the dog at any time.

## 8. Realms

**To be designed.** What the story needs from them (section 4):
- **three realms, playable in any order**, each ending with a piece of the photo
- **Carltron's own ground**, where the kid beats him once
- **the finale**, where Carltron stands at the switch
- room for **Dad's dream** (Main Street, 1995) and a realm or opening where the kid finds the dog

**Content yardstick** (from studying the original's walkthroughs; the full notes
are local, in `research/`). Guidance, not rules:
- The original, per realm (main path): Prehistoria 13 areas, 3 bosses, 4
  mini-fights, ~12 set pieces; Antiqua 14, 5, 6, ~18; Gothica 16, 5, 4, ~19 (the
  densest); Omnitopia 12, 3, 2 plus the final waves, ~11. In all about 56 areas,
  17 major bosses, ~17 mini-boss or ambush fights, ~60 set pieces, 6 towns, 34
  alchemy formulas, about 16 hours for the main story
- Its rhythm: an area every ~18 minutes, a boss-tier fight every 30 to 35
  minutes, a new mechanic or set piece every 13 to 18 minutes; each realm resets
  the feel with a new currency, dog form, weapon tier and alchemists
- For our 8+ hours: roughly 30 areas, 8 to 10 bosses plus a similar number of
  mini-fights, ~30 set pieces, the first boss and first "wow" moment within the
  first hour
- Where ours differs on purpose: the original had no "stay" command (only
  scripted spots and holding the sniff button kept the dog still), needed the
  attack button held for charge levels 2 and 3, and gave the boy 3 armor slots
  (body, helmet, arm). It had about 15 places that split the pair; ours can
  have more, since Stay put makes splitting a tool instead of a script
- Copy: one clear gimmick per boss, kid/dog split sections, dense middle realms
  (the original's market trade chain and banquet/jail sequences are its best
  stretches)
- Avoid: out-and-back errands to a hub, long empty traversal (the Desert of
  Doom), magic that levels only by grinding, silent missables, a thin last realm

**Scrapped on 2026-10-06** (don't bring back without the owner asking):
- the first lineup: The Big Yard, Saltreach, Frostheim, Vernia, The Grand Carlton, The Off Switch
- with it: Mission 1 "Lost Dog", Kennel 13, the per-realm dog forms (Sir Goodboy, Newfoundland, Malamute, Saint Bernard, Borzoi), the per-realm currencies, Gnorman, The Mailman, the Vacuum boss, the Squirrel Army
- the full write-ups are in git history (commit `8863334` and earlier) if any piece is ever wanted back

## 9. Endings

| Ending | Condition | Result |
|---|---|---|
| **Shutdown** | Flip the switch | Carltron goes dark for good. Father and son wake at dawn in the lab. The dog looks back at the dark robot |
| **Dreamer (true)** | Optional conditions (to be designed with the realms: journals, side quests, the dog's story), then **don't** flip it. The dog brings Carltron a stick | Carltron stays as Evermore 2.0's caretaker. Father and son wake in the lab at dawn; Carltron's chair is empty; the note now reads, in shaky robot handwriting, **"THANK YOU."** |
| **Post-credits** | Either | The dare kids outside: "So? What'd you bring back?" The dog drops something from Evermore at their feet (what it is depends on the realms) |

Theme of the true ending: the dog and Carltron are both creatures afraid of
being left behind, and the kid makes sure neither one is.

*(Draft) Why the stick works:* v1 gave Carltron intelligence without imagination;
v2 gave him imagination, and all he could imagine was his own ending. The dog
bringing him a stick is the first time anyone has asked him to imagine
something fun with someone else. That steadies v2, and he no longer needs to
hold anyone as an anchor.

*(Draft) Last scene, either ending:* walking home at dawn, Dad and the kid, the
dog between them. Dad starts to explain 1995. The kid says he knows, and quotes
one of Dad's B-movies, on purpose. Dad laughs for the first time in the game.

## 10. Gameplay rules

**Locked (owner's calls, 2026-10-07):**

| Rule | Decision |
|---|---|
| Hidden items | The world hides items: buried in the ground, tucked under bushes and rocks, behind things. Exploring pays |
| The dog's nose | **The dog sniffs out items**: hidden items and alchemy ingredients |
| Control | **Switch between the kid and the dog any time** (owner, 2026-10-07); the AI plays the other one by his stance. Player 2 can take the other one |
| Stay put | **A "Stay put" command for the partner** (whoever you're not controlling), so mazes and puzzles can need the two to split up and swap control (owner, 2026-10-07) |
| Stances | **The kid: Offensive or Defensive. The dog: Offensive or Search.** Set any time |
| Weapon charge | **Auto power-up: no holding a button.** The charge builds by itself between swings; a swing uses whatever level it reached |
| Armor | **The kid: head, body, legs, boots, hands, arms** (six slots). **The dog: collar** |
| Voices | **One or two words from real voice actors** (owner, 2026-10-07): "Hey!" when you talk to someone, short reactions. No full voice acting for now; AI voices were tried and rejected. Babble is the backup plan. The kid is silent |
| Difficulty | **Normal and Hard playthroughs** (owner, 2026-10-07). On Hard, things cost more and enemies have more HP and armor and hit harder. Every lever lives in one table (`autoload/difficulty.gd`) |
| Text box | Fits the amount of text: grows and shrinks, long lines turn into pages (done) |

**How they work** (built in combat phase B, 2026-10-07; still open to tuning):

- **Stances steer whoever the AI is playing.** You control the kid or the dog
  (switch any time; Player 2 can take the other, later), and the one you're not
  controlling follows his stance:
  - *Kid, Offensive:* goes after awake enemies near you and swings as soon as
    his charge reaches level 1.
  - *Kid, Defensive:* stays with you and only swings at enemies already within
    reach, waiting for a full charge (fewer, bigger hits).
  - *Dog, Offensive:* bites awake enemies near you.
  - *Dog, Search:* stays out of fights, nose down (he sniffs when he stands
    still). He only bites back at something that's after him. Finding hidden
    items comes with the hidden items milestone: near one he'll stop, point and
    bark, then dig it up.
  - The AI never wakes sleeping enemies and never fights more than 240 px from
    you (past that it drops the fight and catches up).
  - R / gamepad RB cycles the partner's stance for now; the ring menu takes it
    over later. The HUD shows it next to his HP.
- **Stay put and splitting up:**
  - *Stay put* toggles the partner (Q / gamepad X): playing the kid it tells
    the dog, playing the dog it tells the kid. A staying partner holds his
    spot; he still swings at anything within reach but never moves.
  - *Switch* (Tab / gamepad Back) moves control and the camera to the other
    one, wherever he is. **Stay put stays on through a switch**, so the one you
    just left stands still: leave the dog on a plate, switch, walk the kid on.
  - *Call back*: press Stay put again. He retraces your path, and if he's stuck
    out of sight he warps in, so a split can never strand you. (Puzzle areas
    that block the call: later, if a puzzle needs it.)
  - A partner arrow at the screen edge shows where he is when he's off screen,
    and flashes red while he's being hit.
  - Conversations belong to the kid: starting one hands control back to him.
  - Puzzles it opens up: the dog squeezes through a gap the kid can't; one holds
    a pressure plate while the other crosses; the kid waits while the dog sniffs
    a way through a dark maze; a door stays open only while someone stands on
    the switch.
- **Sniffing:** besides Search stance, a sniff button (when you control the dog)
  shows scent trails as colored wisps: one color for items, one for
  ingredients, one for people. The trail leads to the nearest few within range.
- **Hidden items, three kinds:**
  - *Buried:* only the dog finds them (sniff, then dig).
  - *Tucked:* under a bush or rock; the kid can search it (interact) if he
    notices the tell (a glint, a disturbed patch of ground), or the dog points it out.
  - *Secret:* behind breakable things or in nooks off the path; found by looking.
  - Every realm says how many it has and how many you've found (no silent missables).
- **Auto charge:** after a swing the charge meter refills on its own, about a
  second to 100% (level 1), then keeps climbing to level 2 and 3 if the weapon's
  mastery allows. Attack whenever you like: a quick tap gives a weaker swing,
  waiting gives the bigger one. The meter shows on the HUD by the kid.
  (The original filled to 100% by itself but needed the button held for levels 2 and 3.)
- **Armor:** each piece adds defense, and some add one small perk (resist
  cold, faster charge, quieter footsteps for the dog's sneaking...). Pieces come
  from shops, chests, hidden caches and bosses. The dog's collar works the same
  way, with perks for the dog (a wider sniff range, harder bites).

## 11. Open questions

- **The realms**: direction, lineup, and the dog's form in each (section 8)
- **Review the story spine (section 4)**, then lock or change it
- Final names for Maya, Dex and the fictional game/streamer the kid quotes (they go in `data/names.json`)
- Dad's old dog: name and look (the 1995 dog was player-named in the original, so ours shouldn't reuse a fan name)
- Does Mom appear (a phone call at dawn?) or stay off screen?
- Alchemy ingredients, the economy, the first mission: all wait on the realms
- Dog sprite: the current one is an LPC shiba recolored brown brindle (a
  stand-in). He still needs the notched floppy ear, one ear up, and the orange
  shelter tag, which means a hand edit in LPC style

---
Written with help from Claude (Anthropic) via Claude Code.

Made with ❤️ from your friendly hacker - er2oneousbit
