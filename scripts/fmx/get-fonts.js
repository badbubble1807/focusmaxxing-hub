/* ------------------------------------------------------------------
   Manrope for the phone.

   Run:  node scripts/fmx/get-fonts.js

   focusmaxxing is set in Manrope everywhere - the extension popup and the
   windows app both load it as woff2 out of the fonts/ folder at the top of
   the desktop repository. an iPhone cannot read woff2, and the only file
   Google publishes on GitHub is the variable one, whose default instance is
   ExtraLight - load that and every screen comes out thin.

   So the weights are fetched the way an old phone would have asked for them:
   the Google Fonts stylesheet endpoint, with a user agent old enough that it
   answers in TrueType, hands back one real static face per weight (checked:
   their usWeightClass really is 400, 500, 600, 700, 800).

   They go straight into AltStore/Resources, not a folder of their own, because
   everything in there is copied flat into the app - AltIcons.plist sits at the
   root of the built app, not under Resources/. Info.plist names them under
   UIAppFonts, and FMXFont registers any the system did not pick up.

   What each face is called inside itself is not what you would guess: Google
   builds these out of the variable font, whose family is "Manrope ExtraLight",
   so the names are ManropeExtraLight-Regular, -Medium, -SemiBold, -Bold and
   -ExtraBold. Those are the names UIFont wants. They are listed in FMXFont.

   Manrope is under the SIL Open Font License; the licence is fetched next to
   the fonts as Manrope-OFL.txt so it travels with them.
   ------------------------------------------------------------------ */

"use strict";

const fs = require("fs");
const path = require("path");

const HUB = path.join(__dirname, "..", "..");
const OUT = path.join(HUB, "AltStore", "Resources");

// old enough that Google Fonts answers in TrueType rather than woff2 or eot
const OLD_PHONE = "Mozilla/5.0 (Linux; U; Android 2.2; en-us; Nexus One Build/FRF91) " +
  "AppleWebKit/533.1 (KHTML, like Gecko) Version/4.0 Mobile Safari/533.1";

// the weights the screens actually use
const WEIGHTS = [400, 500, 600, 700, 800];

async function get(url, headers) {
  const r = await fetch(url, { headers });
  if (!r.ok) throw new Error(url + " answered " + r.status);
  return r;
}

async function main() {
  fs.mkdirSync(OUT, { recursive: true });
  const written = [];

  for (const weight of WEIGHTS) {
    const css = await (await get("https://fonts.googleapis.com/css?family=Manrope:" + weight,
      { "User-Agent": OLD_PHONE })).text();
    const match = css.match(/url\((https:\/\/[^)]+\.ttf)\)/);
    if (!match) throw new Error("no TrueType in the stylesheet for weight " + weight + ": " + css.slice(0, 200));

    const bytes = Buffer.from(await (await get(match[1])).arrayBuffer());
    // a TrueType file starts with the version 1.0 sfnt tag; anything else is
    // the wrong format arriving quietly
    if (bytes.readUInt32BE(0) !== 0x00010000) {
      throw new Error("weight " + weight + " came back in some other format (" + bytes.subarray(0, 4).toString("hex") + ")");
    }

    const name = "Manrope-" + weight + ".ttf";
    fs.writeFileSync(path.join(OUT, name), bytes);
    written.push(name);
    console.log("wrote " + name + " (" + bytes.length + " bytes)");
  }

  const licence = await (await get("https://raw.githubusercontent.com/google/fonts/main/ofl/manrope/OFL.txt")).text();
  fs.writeFileSync(path.join(OUT, "Manrope-OFL.txt"), licence);
  console.log("wrote Manrope-OFL.txt");

  console.log("\nInfo.plist UIAppFonts should list, in this order:");
  for (const name of written) console.log("  " + name);
}

main().catch(error => { console.error(String(error)); process.exit(1); });
