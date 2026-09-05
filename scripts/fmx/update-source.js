// focusmaxxing hub - after a cloud build, write the new hub version into source/apps.json
// so the hub offers itself as an update. plain node, no packages.
//
// usage: node scripts/fmx/update-source.js <version> <path to focusmaxxing-hub.ipa> <download url>
const fs = require("fs"), path = require("path"), crypto = require("crypto");

const [, , version, ipaPath, downloadURL] = process.argv;
if (!version || !ipaPath || !downloadURL) {
  console.error("usage: update-source.js <version> <ipa> <download url>");
  process.exit(2);
}

const file = path.join(__dirname, "..", "..", "source", "apps.json");
const source = JSON.parse(fs.readFileSync(file, "utf8"));
const bytes = fs.readFileSync(ipaPath);
const sha256 = crypto.createHash("sha256").update(bytes).digest("hex");
const date = new Date().toISOString().replace(/\.\d{3}Z$/, "Z");

// the hub is the entry whose bundle id matches the app's own (see Build.xcconfig)
const hub = source.apps.find(app => app.bundleIdentifier === "com.SideStore.SideStore");
if (!hub) { console.error("no hub entry in apps.json"); process.exit(1); }

const entry = { version, date, localizedDescription: "Focusmaxxing Hub build " + version + ".", downloadURL, size: bytes.length, sha256, minOSVersion: "15.0" };
hub.versions = [entry].concat((hub.versions || []).filter(v => v.version !== version)).slice(0, 5);

fs.writeFileSync(file, JSON.stringify(source, null, 2) + "\n");
console.log("apps.json: hub is now " + version + " (" + bytes.length + " bytes, sha256 " + sha256.slice(0, 12) + "...)");
