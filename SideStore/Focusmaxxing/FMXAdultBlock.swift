//
//  FMXAdultBlock.swift
//  Focusmaxxing Hub
//
//  the adult-site block. focusmaxxing hub cannot block a website by itself: an app on a
//  normal iphone has no way to filter what safari loads (the api that could, family
//  controls, needs a paid apple account and apple's permission). so this is two real
//  blocks that live outside the hub, and the hub's job is to walk the customer through
//  them and to make undoing them cost the same wait as every other switch:
//
//   1. apple's own screen time restriction, "Limit Adult Websites", locked behind a
//      screen time passcode. this is the only block on an iphone that survives the hub
//      being deleted, the phone being restored from a backup, and everything else.
//   2. a dns profile pointing the phone at cloudflare's family resolver, which refuses
//      adult and malware domains. it also survives the hub being deleted. it can be
//      switched off in Settings, so it is friction, not a wall, and the screen says so.
//
//  this file holds the profile itself and the two "i have done this" notes. the notes are
//  the customer's own: the hub has no way to read screen time or the installed profiles.
//

import Foundation

enum FMXAdultBlock {
    // the switch key. the same word the desktop extension and the desktop app use for this
    // block ("nsfw" in the repo's sites.js), so the three stay one product.
    static let switchKey = "nsfw"

    // the file the phone installs. the name must keep the .mobileconfig ending or ios will
    // not recognise it as a profile.
    static let profileFileName = "focusmaxxing-family-dns.mobileconfig"

    // MARK: the profile
    //
    // apple's dns settings payload (com.apple.dnsSettings.managed, iphone 14 and up),
    // written by hand from apple's device management schema. dns-over-https to cloudflare's
    // family resolver: the addresses come from cloudflare's own setup page (1.1.1.3 and
    // 1.0.0.3 are the "malware and adult content" pair; 1.1.1.1 is the plain one).
    //
    // ProhibitDisablement and PayloadRemovalDisallowed are false on purpose. apple only
    // honours them on a phone handed out by a company, and pretending otherwise would be
    // a promise the phone does not keep.
    //
    // THE COPY IN source/focusmaxxing-family-dns.mobileconfig IS GENERATED FROM THIS TEXT.
    // an "and" sign inside the text below has to be written "&amp;", the way xml spells it, or
    // the phone refuses the whole profile.
    // change it here and run "node scripts/fmx/dns-profile.js" in the hub folder; never
    // edit that file by hand. the two uuids must stay as they are once customers have the
    // profile: ios replaces a profile with the same identifier and adds a second one for a
    // different identifier.
    static let profileText = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
    \t<key>PayloadType</key>
    \t<string>Configuration</string>
    \t<key>PayloadVersion</key>
    \t<integer>1</integer>
    \t<key>PayloadIdentifier</key>
    \t<string>com.focusmaxxing.dns.family</string>
    \t<key>PayloadUUID</key>
    \t<string>79F21305-0BA7-4FD4-BF92-22F1DBFEAA2E</string>
    \t<key>PayloadDisplayName</key>
    \t<string>Focusmaxxing family DNS</string>
    \t<key>PayloadDescription</key>
    \t<string>Sends this phone's website lookups to Cloudflare's family server, which refuses adult and malware sites. You can switch it off in Settings, under General, then VPN, DNS &amp; Device Management.</string>
    \t<key>PayloadOrganization</key>
    \t<string>Focusmaxxing</string>
    \t<key>PayloadRemovalDisallowed</key>
    \t<false/>
    \t<key>TargetDeviceType</key>
    \t<integer>1</integer>
    \t<key>PayloadContent</key>
    \t<array>
    \t\t<dict>
    \t\t\t<key>PayloadType</key>
    \t\t\t<string>com.apple.dnsSettings.managed</string>
    \t\t\t<key>PayloadVersion</key>
    \t\t\t<integer>1</integer>
    \t\t\t<key>PayloadIdentifier</key>
    \t\t\t<string>com.focusmaxxing.dns.family.dnssettings</string>
    \t\t\t<key>PayloadUUID</key>
    \t\t\t<string>399C04A5-3424-4B78-82CA-9D51E140C399</string>
    \t\t\t<key>PayloadDisplayName</key>
    \t\t\t<string>Encrypted DNS</string>
    \t\t\t<key>PayloadDescription</key>
    \t\t\t<string>Encrypted lookups through https://family.cloudflare-dns.com/dns-query</string>
    \t\t\t<key>PayloadOrganization</key>
    \t\t\t<string>Focusmaxxing</string>
    \t\t\t<key>DNSSettings</key>
    \t\t\t<dict>
    \t\t\t\t<key>DNSProtocol</key>
    \t\t\t\t<string>HTTPS</string>
    \t\t\t\t<key>ServerURL</key>
    \t\t\t\t<string>https://family.cloudflare-dns.com/dns-query</string>
    \t\t\t\t<key>ServerAddresses</key>
    \t\t\t\t<array>
    \t\t\t\t\t<string>1.1.1.3</string>
    \t\t\t\t\t<string>1.0.0.3</string>
    \t\t\t\t\t<string>2606:4700:4700::1113</string>
    \t\t\t\t\t<string>2606:4700:4700::1003</string>
    \t\t\t\t</array>
    \t\t\t</dict>
    \t\t\t<key>ProhibitDisablement</key>
    \t\t\t<false/>
    \t\t</dict>
    \t</array>
    </dict>
    </plist>

    """

    // a copy of the profile in the phone's temporary folder, for the "save the file" route.
    // ios only offers to install a profile the customer can see: from safari, or by tapping
    // the file in Files. the temporary folder is emptied by ios itself later.
    static func writeProfileToTemporaryFile() -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(FMXAdultBlock.profileFileName)
        do {
            try FMXAdultBlock.profileText.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            debugLog("[FMXAdultBlock] could not write the profile: \(error)")
            return nil
        }
    }
}

extension UserDefaults {
    // the customer's own note that they walked through the screen time steps. the hub cannot
    // read screen time, so this is a tick on a list, not a reading of the phone.
    var fmxAdultScreenTimeDone: Bool {
        get { self.bool(forKey: "fmxAdultScreenTimeDone") }
        set { self.set(newValue, forKey: "fmxAdultScreenTimeDone") }
    }

    // the same for the dns profile. the hub cannot read the installed profiles either.
    var fmxAdultDNSDone: Bool {
        get { self.bool(forKey: "fmxAdultDNSDone") }
        set { self.set(newValue, forKey: "fmxAdultDNSDone") }
    }
}
