// focusmaxxing hub - write source/focusmaxxing-family-dns.mobileconfig from the profile text
// that lives in the app's own source, so the two can never drift apart.
//
// the hub carries the profile inside itself (for the "save the file" route) and the website
// links to the copy in this repository (for the "install it from a link" route). the app's
// copy is the original: this script only copies it out.
//
// usage: node scripts/fmx/dns-profile.js          writes the file
//        node scripts/fmx/dns-profile.js --check   says whether the file matches, changes nothing
// plain node, no packages.
const fs = require("fs"), path = require("path");

const root = path.resolve(__dirname, "..", "..");
const swiftFile = path.join(root, "SideStore", "Focusmaxxing", "FMXAdultBlock.swift");
const outFile = path.join(root, "source", "focusmaxxing-family-dns.mobileconfig");

// git hands this pc the file with windows line endings; the swift compiler turns those into
// plain ones inside a multi-line string, so do the same here or the two copies never match
const swift = fs.readFileSync(swiftFile, "utf8").replace(/\r\n/g, "\n");

// the profile is a swift multi-line string: static let profileText = """ ... """
const start = swift.indexOf('static let profileText = """');
if (start < 0) {
  console.error("could not find profileText in " + swiftFile);
  process.exit(1);
}
const bodyStart = swift.indexOf("\n", start) + 1;
const bodyEnd = swift.indexOf('"""', bodyStart);
if (bodyEnd < 0) {
  console.error("profileText is not closed in " + swiftFile);
  process.exit(1);
}

// swift strips the indentation of the closing quotes from every line, and turns \t into a tab
const closingLineStart = swift.lastIndexOf("\n", bodyEnd) + 1;
const indent = swift.slice(closingLineStart, bodyEnd);
if (indent.trim() !== "") {
  console.error("the closing quotes of profileText are not on their own line");
  process.exit(1);
}

const profile = swift
  .slice(bodyStart, closingLineStart)
  .split("\n")
  .map(line => (line.startsWith(indent) ? line.slice(indent.length) : line.replace(/^\s+/, "")))
  .join("\n")
  .replace(/\\t/g, "\t")
  // swift does not keep the line break that sits just before the closing quotes, so the blank
  // line at the end of the swift text is what makes the profile end with exactly one line break.
  // take one off here or this copy ends with two and the two copies are not the same file.
  .replace(/\n$/, "");

if (!profile.startsWith("<?xml") || !profile.includes("com.apple.dnsSettings.managed")) {
  console.error("that does not look like the dns profile; nothing written");
  process.exit(1);
}

const existing = fs.existsSync(outFile) ? fs.readFileSync(outFile, "utf8").replace(/\r\n/g, "\n") : null;

if (process.argv.includes("--check")) {
  if (existing === profile) {
    console.log("source/" + path.basename(outFile) + " matches the app");
    process.exit(0);
  }
  console.error("source/" + path.basename(outFile) + " does NOT match the app; run this script without --check");
  process.exit(1);
}

fs.writeFileSync(outFile, profile);
console.log("wrote " + outFile + " (" + profile.length + " bytes)" + (existing === profile ? ", unchanged" : ""));
