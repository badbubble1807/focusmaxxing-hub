//! every address and name the computer step relies on, in one place (the hub's FMXLinks.swift does
//! the same job on the phone). the web links the screen opens are in ../src/links.ts.

/// the hub itself, as published by the "build hub" workflow
pub const HUB_IPA_URL: &str =
    "https://github.com/badbubble1807/focusmaxxing-hub/releases/download/hub/focusmaxxing-hub.ipa";

/// the hub's identifier as built. the signing step appends the apple id's team id to it, and the
/// signing library recognises this exact value as a store app: that is what makes it bake the
/// signing certificate into the hub so the hub can renew itself later. if the hub's identifier
/// ever changes, the signing library has to learn the new one too.
pub const HUB_BUNDLE_ID: &str = "com.SideStore.SideStore";

/// the name the phone reports for the hub (CFBundleDisplayName in the hub's Info.plist)
pub const HUB_DISPLAY_NAME: &str = "Focusmaxxing";

/// where the hub expects its pairing file, inside its Documents folder
pub const HUB_PAIRING_FILE: &str = "ALTPairingFile.mobiledevicepairing";

/// where we leave the signing certificate for the hub, in the same folder. the hub reads it at
/// start-up and keeps it (SideStore/Focusmaxxing/FMXCertificateHandoff.swift holds the same name;
/// the two must match). without it the hub asks apple for a certificate of its own, and a free
/// apple id only keeps one, so apple revokes this one and everything signed here stops working.
pub const HUB_CERTIFICATE_FILE: &str = "FocusmaxxingCertificate.plist";

/// the name this computer shows up under in the apple id's certificate list and in the pairing
pub const MACHINE_NAME: &str = "Focusmaxxing Setup";

/// the entry everything is filed under in the windows credential store
pub const KEYRING_SERVICE: &str = "focusmaxxing-setup";
