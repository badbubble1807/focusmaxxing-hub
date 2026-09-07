/* ------------------------------------------------------------------
   The focusmaxxing mark, as an image the Hub can draw.

   Run:  node scripts/fmx/make-mark.js

   The mark - the F whose top arm turns and flies off as an arrow - is
   geometry, not a picture: tools/make-logo.js in the desktop repository
   computes every corner and writes the bare path to
   app/build/logo-glyph.txt. That one line is what the extension popup
   and the desktop window draw. This script turns the same line into the
   three sizes an iPhone wants and drops them into the Hub's asset
   catalogue as a template image, so the phone cannot drift away from
   the other two screens.

   Written white on nothing: a template image is drawn in whatever
   colour the view asks for, which is how the mark comes out volt on one
   screen and plain white on another.

   sharp does the drawing; it is already in the desktop app's
   node_modules, which is the only place on this PC it lives.
   ------------------------------------------------------------------ */

"use strict";

const fs = require("fs");
const path = require("path");

// hub/scripts/fmx -> hub -> mobile -> the desktop repository
const HUB = path.join(__dirname, "..", "..");
const DESKTOP = path.join(HUB, "..", "..");
const GLYPH = path.join(DESKTOP, "app", "build", "logo-glyph.txt");
const OUT = path.join(HUB, "AltStore", "Resources", "Assets.xcassets", "FMXMark.imageset");

let sharp;
try {
  sharp = require(path.join(DESKTOP, "app", "node_modules", "sharp"));
} catch (error) {
  console.error("sharp is not installed. It lives in the desktop app: run npm install in app/ first.");
  process.exit(1);
}

// the base size in points; the phone gets it at 1x, 2x and 3x
const BASE = 96;

function glyphPath() {
  if (!fs.existsSync(GLYPH)) {
    console.error("app/build/logo-glyph.txt is missing. Run node tools/make-logo.js in the desktop repository first.");
    process.exit(1);
  }
  const text = fs.readFileSync(GLYPH, "utf8");
  const box = text.match(/viewBox="([^"]+)"/);
  const d = text.match(/ d="([^"]+)"/);
  if (!box || !d) {
    console.error("logo-glyph.txt is not the shape this script expects (a viewBox and one path).");
    process.exit(1);
  }
  return { box: box[1], d: d[1] };
}

async function main() {
  const { box, d } = glyphPath();
  fs.mkdirSync(OUT, { recursive: true });

  const images = [];
  for (const scale of [1, 2, 3]) {
    const size = BASE * scale;
    const svg = '<svg xmlns="http://www.w3.org/2000/svg" width="' + size + '" height="' + size +
      '" viewBox="' + box + '"><path d="' + d + '" fill="#ffffff"/></svg>';
    const name = "mark@" + scale + "x.png";
    await sharp(Buffer.from(svg)).png().toFile(path.join(OUT, name));
    images.push({ idiom: "universal", filename: name, scale: scale + "x" });
    console.log("wrote " + name + " (" + size + "px)");
  }

  const contents = {
    images,
    info: { author: "xcode", version: 1 },
    properties: { "template-rendering-intent": "template" }
  };
  fs.writeFileSync(path.join(OUT, "Contents.json"), JSON.stringify(contents, null, 2) + "\n");
  console.log("wrote Contents.json");
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
