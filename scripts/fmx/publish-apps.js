// focusmaxxing hub - copy the two custom apps from the private focusmaxxing-mobile releases
// onto this repository's public "apps" release, where the hub's app list points.
// plain node, no packages. the github token comes from the git credential helper and is never printed.
//
// usage: node scripts/fmx/publish-apps.js
// safe to run again: files already downloaded are kept, assets already uploaded with the same size are skipped.
const { execSync } = require("child_process");
const fs = require("fs"), path = require("path"), os = require("os"), crypto = require("crypto");

const SOURCE_REPO = "badbubble1807/focusmaxxing-mobile";
const HUB_REPO = "badbubble1807/focusmaxxing-hub";
const FILES = [
  { tag: "instagram", name: "focusmaxxing-instagram.ipa" },
  { tag: "youtube-app", name: "focusmaxxing-youtube-app.ipa" },
];

const cred = execSync("git credential fill", { input: "protocol=https\nhost=github.com\n", encoding: "utf8" });
const token = cred.split("\n").find(l => l.startsWith("password=")).slice("password=".length);
const auth = { Authorization: "Bearer " + token, "User-Agent": "focusmaxxing", Accept: "application/vnd.github+json" };
const api = async (method, url, body, extra) => {
  const r = await fetch(url.startsWith("http") ? url : "https://api.github.com" + url, { method, headers: { ...auth, ...(extra || {}) }, body });
  const text = await r.text();
  let json = null; try { json = JSON.parse(text); } catch {}
  return { status: r.status, json, text };
};
const work = path.join(os.tmpdir(), "focusmaxxing-apps");
fs.mkdirSync(work, { recursive: true });
const stamp = () => new Date().toTimeString().slice(0, 8);

(async () => {
  // the public release the hub reads from
  let release = await api("GET", `/repos/${HUB_REPO}/releases/tags/apps`);
  if (release.status === 404) {
    release = await api("POST", `/repos/${HUB_REPO}/releases`, JSON.stringify({
      tag_name: "apps", name: "Custom blocked apps",
      body: "Custom blocked Instagram and Custom blocked YouTube, installed by Focusmaxxing Hub. Built from the focusmaxxing-mobile repository.",
      draft: false, prerelease: false, make_latest: "false",
    }), { "Content-Type": "application/json" });
    console.log(stamp(), "created the apps release:", release.status);
  }
  if (!release.json || !release.json.id) { console.error("no apps release:", release.text.slice(0, 200)); process.exit(1); }
  const releaseId = release.json.id;
  const existing = release.json.assets || [];

  const results = [];
  for (const file of FILES) {
    // 1. download from the private repository (or reuse the copy from last time)
    const local = path.join(work, file.name);
    const src = await api("GET", `/repos/${SOURCE_REPO}/releases/tags/${file.tag}`);
    const asset = ((src.json && src.json.assets) || []).find(a => a.name === file.name);
    if (!asset) { console.error("no", file.name, "on the", file.tag, "release"); process.exit(1); }
    // the build number: the cloud build writes "build number N" into the release notes. the hub compares it
    // (as buildVersion) against the build it installed, which is how a tile knows to say Update; the apps'
    // own version numbers are instagram's and youtube's and never change with a rebuild.
    const build = (((src.json && src.json.body) || "").match(/build number (\d+)/) || [])[1];
    if (!build) { console.error("no 'build number N' in the notes of the", file.tag, "release"); process.exit(1); }
    console.log(stamp(), file.name, "is build", build, "from", asset.updated_at);
    if (!fs.existsSync(local) || fs.statSync(local).size !== asset.size) {
      console.log(stamp(), "downloading", file.name, Math.round(asset.size / 1e6), "MB");
      const r = await fetch(asset.url, { headers: { ...auth, Accept: "application/octet-stream" } });
      if (!r.ok) { console.error("download failed:", r.status); process.exit(1); }
      fs.writeFileSync(local, Buffer.from(await r.arrayBuffer()));
    } else {
      console.log(stamp(), "already downloaded", file.name);
    }
    const bytes = fs.readFileSync(local);
    const sha256 = crypto.createHash("sha256").update(bytes).digest("hex");

    // 2. upload to the public release (replace an old copy of a different size)
    const old = existing.find(a => a.name === file.name);
    if (old && old.size === bytes.length) {
      console.log(stamp(), "already on the apps release:", file.name);
    } else {
      if (old) { await api("DELETE", `/repos/${HUB_REPO}/releases/assets/${old.id}`); console.log(stamp(), "removed the old", file.name); }
      console.log(stamp(), "uploading", file.name, Math.round(bytes.length / 1e6), "MB");
      const up = await api("POST", `https://uploads.github.com/repos/${HUB_REPO}/releases/${releaseId}/assets?name=${encodeURIComponent(file.name)}`, bytes,
        { "Content-Type": "application/octet-stream", "Content-Length": String(bytes.length) });
      if (up.status !== 201) { console.error("upload failed:", up.status, up.text.slice(0, 300)); process.exit(1); }
      console.log(stamp(), "uploaded", file.name, "->", up.json.browser_download_url);
    }
    results.push({ name: file.name, size: bytes.length, sha256, build, date: asset.updated_at });
  }

  // 3. write the build number, date, real size and checksum into the app list
  const listFile = path.join(__dirname, "..", "..", "source", "apps.json");
  const list = JSON.parse(fs.readFileSync(listFile, "utf8"));
  for (const app of list.apps) {
    for (const version of app.versions || []) {
      const hit = results.find(r => version.downloadURL.endsWith("/" + r.name));
      if (!hit) continue;
      version.buildVersion = String(hit.build);
      version.date = hit.date.replace(/\.\d{3}Z$/, "Z");
      version.size = hit.size;
      version.sha256 = hit.sha256;
      // the notes start "Instagram build 8." / "YouTube app build 5."; keep the wording, move the number
      version.localizedDescription = (version.localizedDescription || "").replace(/\bbuild \d+\b/, "build " + hit.build);
      if (!/\bbuild \d+\b/.test(version.localizedDescription)) version.localizedDescription = app.name + " build " + hit.build + ".";
      console.log(stamp(), app.name, "->", version.version, "build", version.buildVersion);
    }
  }
  fs.writeFileSync(listFile, JSON.stringify(list, null, 2) + "\n");
  console.log(stamp(), "apps.json updated with build numbers, sizes and checksums");
})().catch(e => { console.error("error:", e.message); process.exit(1); });
