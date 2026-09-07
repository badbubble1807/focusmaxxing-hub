/* ------------------------------------------------------------------
   The app icon on the home screen.

   Run:  node scripts/fmx/make-app-icon.js

   The mark - the F whose top arm turns and flies off as an arrow - is
   geometry, not a picture: tools/make-logo.js in the desktop repository
   computes it and writes the bare path to app/build/logo-glyph.txt. This
   builds the phone's icon from that same line, so the icon on the home
   screen, the badge in the popup and the picture on the taskbar cannot
   drift apart.

   Two differences from the desktop's own plate:
     - square corners. iOS rounds an icon itself, and a rounded picture
       inside that rounding shows as a smaller square with pale corners.
     - no transparency anywhere, for the same reason.

   The gradient, the padding and the optical nudge are copied from
   tools/make-logo.js plate() so the two really are the same drawing.

   sharp does the rendering; it lives in the desktop app's node_modules,
   the only place on this PC it is installed.
   ------------------------------------------------------------------ */

"use strict";

const fs = require("fs");
const path = require("path");

const HUB = path.join(__dirname, "..", "..");
const DESKTOP = path.join(HUB, "..", "..");
const GLYPH = path.join(DESKTOP, "app", "build", "logo-glyph.txt");
const MASTER = path.join(DESKTOP, "app", "build", "logo-master.png");

const APP_ICON = path.join(HUB, "AltStore", "Resources", "Icons.xcassets", "AppIcon.appiconset", "1024.png");
const IN_APP = path.join(HUB, "AltStore", "Resources", "Assets.xcassets", "SideStore.imageset", "1024.png");

let sharp;
try {
  sharp = require(path.join(DESKTOP, "app", "node_modules", "sharp"));
} catch (error) {
  console.error("sharp is not installed. It lives in the desktop app: run npm install in app/ first.");
  process.exit(1);
}

// the same values tools/make-logo.js draws its plate with
const AC1 = "#b8ff3c";
const AC2 = "#34f0c9";
const AC3 = "#22c7ff";
const INK = "#050a08";
const PAD = 0.155;      // how much of the square is margin, each side
const NUDGE = 0.012;    // the glyph leans up and right, so it is pushed back

function glyph() {
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
  if (!fs.existsSync(GLYPH)) {
    console.error("app/build/logo-glyph.txt is missing. Run node tools/make-logo.js in the desktop repository first.");
    process.exit(1);
  }

  const { box, d } = glyph();
  const size = 1024;
  const inner = size * (1 - PAD * 2);
  const at = size * PAD;

  const svg = '<svg xmlns="http://www.w3.org/2000/svg" width="' + size + '" height="' + size +
    '" viewBox="0 0 ' + size + ' ' + size + '">' +
    '<defs><linearGradient id="volt" x1="0" y1="0" x2="1" y2="1">' +
    '<stop offset="0" stop-color="' + AC1 + '"/>' +
    '<stop offset=".58" stop-color="' + AC2 + '"/>' +
    '<stop offset="1" stop-color="' + AC3 + '"/>' +
    '</linearGradient></defs>' +
    '<rect width="' + size + '" height="' + size + '" fill="url(#volt)"/>' +
    '<svg x="' + (at - size * NUDGE) + '" y="' + (at + size * NUDGE) + '" width="' + inner + '" height="' + inner +
    '" viewBox="' + box + '"><path d="' + d + '" fill="' + INK + '"/></svg>' +
    '</svg>';

  // flattened onto the gradient's own first colour so nothing is transparent
  await sharp(Buffer.from(svg)).flatten({ background: AC2 }).png().toFile(APP_ICON);
  console.log("wrote " + path.relative(HUB, APP_ICON) + " (square, no transparency - iOS rounds it itself)");

  // the picture the app shows of itself keeps the rounded plate the other two screens use
  if (fs.existsSync(MASTER)) {
    fs.copyFileSync(MASTER, IN_APP);
    console.log("wrote " + path.relative(HUB, IN_APP) + " (the rounded plate, as in the popup)");
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
