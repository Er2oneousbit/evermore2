# tools/lpc: LPC character export

Builds character sprite sheets with the
[Universal LPC Spritesheet Character Generator](https://liberatedpixelcup.github.io/Universal-LPC-Spritesheet-Character-Generator/)
without clicking through it by hand.

## Files

| File | What |
|---|---|
| `characters.json` | One "recipe" per character: the generator's URL hash, where the sheet goes, notes |
| `build_character.js` | Opens the generator in a headless browser, applies a recipe, saves the sheet + credits |

## Make or change a character

1. Build the character in the web generator. Pick **Teen** for kids, **Male/Female** for adults.
2. Copy everything from `#` onward in the address bar.
3. Add or edit an entry in `characters.json` (`hash` = what you copied).
4. Run it:

   ```bash
   npm i -g playwright && npx playwright install chromium   # once
   node tools/lpc/build_character.js kid /tmp/kid_build
   ```

   On Windows: `node tools\lpc\build_character.js kid C:\temp\kid_build`

5. Copy `sheet.png` to the recipe's `output` path, and `credits.txt` + `credits.csv`
   to its `credits` folder. Update `CREDITS.md` if the layers changed.
6. Check the license column in `credits.csv`. Layers without OGA-BY / CC-BY
   (CC-BY-SA or GPL only) make the whole sheet share-alike; see the note in `CREDITS.md`.

The output is a standard 832x3456 Universal LPC sheet (13 x 54 frames of
64x64). `systems/animation/lpc_sprite.gd` plays it with zero setup.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `Cannot find module 'playwright'` | `npm i -g playwright` (the script also looks in the global npm folder) |
| `browserType.launch: Executable doesn't exist` | `npx playwright install chromium` |
| Timeout on page load behind a proxy | Set `HTTPS_PROXY`; the script passes it to Chromium |
| Sheet is missing a layer | The generator didn't recognize a hash part. Paste the hash into the web generator and check every item shows in "Current Selections" |

Written with help from Claude (Anthropic) via Claude Code.

Made with ❤️ from your friendly hacker - er2oneousbit
