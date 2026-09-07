// focusmaxxing hub - print why a cloud build failed, without opening a browser.
//
// usage: node scripts/fmx/build-errors.js            the newest "build hub" run
//        node scripts/fmx/build-errors.js setup      the newest "build setup" run
//        node scripts/fmx/build-errors.js <run id>   one run by number
//
// it downloads the run's log archive, keeps only the lines a compiler or a script complains
// on, and prints those. the github token comes from the git credential helper, the same one
// git push uses, and is never printed.

const { execSync } = require("child_process");
const zlib = require("zlib");

const REPO = "badbubble1807/focusmaxxing-hub";
const WORKFLOWS = { hub: "build-hub.yml", setup: "build-setup.yml" };

const args = process.argv.slice(2);
const which = WORKFLOWS[args[0]] ? args.shift() : "hub";
const runId = args[0] && /^[0-9]+$/.test(args[0]) ? args[0] : null;

const cred = execSync("git credential fill", { input: "protocol=https\nhost=github.com\n", encoding: "utf8" });
const token = cred.split("\n").find(l => l.startsWith("password=")).slice("password=".length);
const headers = { Authorization: "Bearer " + token, "User-Agent": "focusmaxxing", Accept: "application/vnd.github+json" };

// what is worth printing out of tens of thousands of lines of build noise
const INTERESTING = /(error:|error MSB|fatal error|\*\* BUILD FAILED|The following build commands failed|warning: no rule|Command .* failed|Process completed with exit code)/;

async function api(path) {
  const r = await fetch("https://api.github.com/repos/" + REPO + path, { headers });
  const text = await r.text();
  let json = null; try { json = JSON.parse(text); } catch {}
  return { status: r.status, json, text };
}

// the logs come back as a zip; node has no unzip, so this walks the central directory itself
// and inflates each entry. every file in it is plain text.
function entriesOf(zip) {
  const out = [];
  const end = zip.lastIndexOf(Buffer.from([0x50, 0x4b, 0x05, 0x06]));
  if (end < 0) return out;
  const count = zip.readUInt16LE(end + 10);
  let at = zip.readUInt32LE(end + 16);
  for (let i = 0; i < count; i++) {
    const nameLength = zip.readUInt16LE(at + 28);
    const extraLength = zip.readUInt16LE(at + 30);
    const commentLength = zip.readUInt16LE(at + 32);
    const name = zip.toString("utf8", at + 46, at + 46 + nameLength);
    const localAt = zip.readUInt32LE(at + 42);
    const method = zip.readUInt16LE(at + 10);
    const compressed = zip.readUInt32LE(at + 20);
    const localNameLength = zip.readUInt16LE(localAt + 26);
    const localExtraLength = zip.readUInt16LE(localAt + 28);
    const dataAt = localAt + 30 + localNameLength + localExtraLength;
    const data = zip.subarray(dataAt, dataAt + compressed);
    let text = "";
    try {
      text = method === 0 ? data.toString("utf8") : zlib.inflateRawSync(data).toString("utf8");
    } catch (error) {
      text = "";
    }
    out.push({ name, text });
    at += 46 + nameLength + extraLength + commentLength;
  }
  return out;
}

(async () => {
  let id = runId;
  if (!id) {
    const runs = await api("/actions/workflows/" + WORKFLOWS[which] + "/runs?per_page=1");
    const run = runs.json && runs.json.workflow_runs && runs.json.workflow_runs[0];
    if (!run) { console.log("no runs found"); return; }
    id = String(run.id);
    console.log("run #" + run.run_number, run.status, run.conclusion);
  }

  const r = await fetch("https://api.github.com/repos/" + REPO + "/actions/runs/" + id + "/logs", { headers });
  if (!r.ok) { console.log("could not fetch the log:", r.status); return; }
  const zip = Buffer.from(await r.arrayBuffer());

  let printed = 0;
  for (const entry of entriesOf(zip)) {
    const lines = entry.text.split(/\r?\n/).filter(l => INTERESTING.test(l));
    if (!lines.length) continue;
    console.log("---- " + entry.name);
    for (const line of lines.slice(0, 60)) {
      // the runner stamps every line with a timestamp; drop it, it is noise here
      console.log(line.replace(/^\S+Z\s/, "").slice(0, 400));
      printed++;
    }
  }
  if (!printed) console.log("nothing in the log matched the error patterns");
})().catch(error => { console.error(String(error).slice(0, 500)); process.exit(1); });
