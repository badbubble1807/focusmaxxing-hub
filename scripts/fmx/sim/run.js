// focusmaxxing hub simulator harness - watch a harness run from the PC and fetch its screenshots.
// plain node, no packages. the github token comes from the git credential helper (the same one
// git push uses) and is never printed.
//
// the harness starts by itself when a branch named ci/<anything> is pushed to the hub repository
// (.github/workflows/sim-harness.yml). this script only watches and downloads.
//
// usage (from inside the hub repository, or anywhere - it does not read the working copy):
//   node scripts/fmx/sim/run.js watch <branch> [--sha <commit>] [--minutes 9] [--download <dir>]
//        waits for the newest harness run of <branch> (or the one for <commit>) to finish, for at
//        most --minutes (default 9, under the 10-minute limit of one tool call; run it again to
//        keep waiting). exit 0 = green, 2 = finished but not green, 3 = still running, 1 = error.
//        with --download the sim-screens artifact is unzipped into <dir> when the run finishes,
//        green or not.
//   node scripts/fmx/sim/run.js status <branch>          the newest run of <branch>, one line
//   node scripts/fmx/sim/run.js download <run id> <dir>  unzip that run's sim-screens into <dir>
//   node scripts/fmx/sim/run.js steps <run id>           each step of the run and how it ended
//
// for the compiler's own error lines of a failed run: node scripts/fmx/build-errors.js <run id>
const { execSync } = require("child_process");
const fs = require("fs");
const path = require("path");
const zlib = require("zlib");

const REPO = "badbubble1807/focusmaxxing-hub";
const WORKFLOW = "sim-harness.yml";
const ARTIFACT = "sim-screens";

const cred = execSync("git credential fill", { input: "protocol=https\nhost=github.com\n\n", encoding: "utf8" });
const token = cred.split("\n").find(l => l.startsWith("password=")).slice("password=".length);
const headers = { Authorization: "Bearer " + token, "User-Agent": "focusmaxxing", Accept: "application/vnd.github+json" };

async function api(p) {
  const r = await fetch("https://api.github.com/repos/" + REPO + p, { headers });
  const text = await r.text();
  let json = null; try { json = JSON.parse(text); } catch {}
  return { status: r.status, json, text };
}
const sleep = ms => new Promise(r => setTimeout(r, ms));
const stamp = () => new Date().toTimeString().slice(0, 8);
const option = (args, name) => { const i = args.indexOf(name); return i >= 0 ? args[i + 1] : null; };

async function newestRun(branch, sha) {
  const q = "/actions/workflows/" + WORKFLOW + "/runs?per_page=20&branch=" + encodeURIComponent(branch);
  const runs = ((await api(q)).json || {}).workflow_runs || [];
  return sha ? runs.find(r => r.head_sha.startsWith(sha)) : runs[0];
}

function line(run) {
  const took = run.run_started_at ? Math.round((new Date(run.updated_at) - new Date(run.run_started_at)) / 60000) + " min" : "";
  return "run " + run.id + " #" + run.run_number + " " + run.head_sha.slice(0, 8) + " " + run.status +
    (run.conclusion ? "/" + run.conclusion : "") + " " + took + " " + run.html_url;
}

async function steps(runId) {
  const jobs = ((await api("/actions/runs/" + runId + "/jobs")).json || {}).jobs || [];
  for (const job of jobs) {
    console.log("job:", job.name, job.status, job.conclusion || "");
    for (const s of job.steps || []) {
      const mins = s.started_at && s.completed_at ? " (" + Math.round((new Date(s.completed_at) - new Date(s.started_at)) / 1000) + " s)" : "";
      console.log("  " + (s.conclusion || s.status).padEnd(11) + s.name + mins);
    }
  }
}

// a github artifact is a zip; node has no unzip, so walk the central directory by hand
function unzip(zip, dir) {
  const end = zip.lastIndexOf(Buffer.from([0x50, 0x4b, 0x05, 0x06]));
  if (end < 0) throw new Error("not a zip");
  const count = zip.readUInt16LE(end + 10);
  let at = zip.readUInt32LE(end + 16);
  let written = 0;
  for (let i = 0; i < count; i++) {
    const method = zip.readUInt16LE(at + 10);
    const compressed = zip.readUInt32LE(at + 20);
    const nameLength = zip.readUInt16LE(at + 28);
    const extraLength = zip.readUInt16LE(at + 30);
    const commentLength = zip.readUInt16LE(at + 32);
    const localAt = zip.readUInt32LE(at + 42);
    const name = zip.toString("utf8", at + 46, at + 46 + nameLength);
    at += 46 + nameLength + extraLength + commentLength;
    if (name.endsWith("/")) continue;
    const dataAt = localAt + 30 + zip.readUInt16LE(localAt + 26) + zip.readUInt16LE(localAt + 28);
    const data = zip.subarray(dataAt, dataAt + compressed);
    const target = path.join(dir, ...name.split("/"));
    if (!path.resolve(target).startsWith(path.resolve(dir))) continue;
    fs.mkdirSync(path.dirname(target), { recursive: true });
    fs.writeFileSync(target, method === 0 ? data : zlib.inflateRawSync(data));
    written++;
  }
  return written;
}

async function download(runId, dir) {
  const list = ((await api("/actions/runs/" + runId + "/artifacts")).json || {}).artifacts || [];
  const artifact = list.find(a => a.name === ARTIFACT);
  if (!artifact) { console.log("run " + runId + " has no " + ARTIFACT + " artifact"); return false; }
  if (artifact.expired) { console.log("the artifact has expired (they are kept 7 days)"); return false; }
  const r = await fetch("https://api.github.com/repos/" + REPO + "/actions/artifacts/" + artifact.id + "/zip", { headers });
  if (!r.ok) { console.log("download failed:", r.status); return false; }
  const zip = Buffer.from(await r.arrayBuffer());
  fs.mkdirSync(dir, { recursive: true });
  const n = unzip(zip, dir);
  console.log("unzipped " + n + " files (" + Math.round(zip.length / 1e6 * 10) / 10 + " MB) into " + dir);
  return true;
}

(async () => {
  const args = process.argv.slice(2);
  const command = args[0];

  if (command === "status") {
    const run = await newestRun(args[1]);
    console.log(run ? line(run) : "no harness run for " + args[1]);
    return;
  }
  if (command === "download") {
    process.exit((await download(args[1], args[2])) ? 0 : 1);
  }
  if (command === "steps") {
    await steps(args[1]);
    return;
  }
  if (command === "watch") {
    const branch = args[1];
    const sha = option(args, "--sha");
    const minutes = Number(option(args, "--minutes") || 9);
    const dir = option(args, "--download");
    const until = Date.now() + minutes * 60000;
    let run = null;
    while (!run && Date.now() < until) {
      run = await newestRun(branch, sha);
      if (!run) await sleep(10000);
    }
    if (!run) { console.log("no harness run appeared for " + branch + (sha ? " at " + sha : "")); process.exit(1); }
    console.log(stamp(), line(run));
    let last = "";
    while (Date.now() < until) {
      const current = (await api("/actions/runs/" + run.id)).json || run;
      const now = current.status + (current.conclusion ? "/" + current.conclusion : "");
      if (now !== last) { console.log(stamp(), now); last = now; }
      if (current.status === "completed") {
        await steps(run.id);
        if (dir) await download(run.id, dir);
        process.exit(current.conclusion === "success" ? 0 : 2);
      }
      await sleep(30000);
    }
    console.log(stamp(), "still running; run the same command again to keep waiting");
    process.exit(3);
  }
  console.log("usage: run.js watch <branch> [--sha <commit>] [--minutes 9] [--download <dir>] | status <branch> | download <run id> <dir> | steps <run id>");
  process.exit(1);
})().catch(e => { console.error("error:", e.message); process.exit(1); });
