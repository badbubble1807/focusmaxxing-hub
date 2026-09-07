//
//  FMXCertificateHandoff.swift
//  Focusmaxxing Hub
//
//  the signing certificate, handed from the computer step to the hub.
//
//  what goes wrong without this: Focusmaxxing Setup asks apple for a signing certificate, signs
//  the hub with it and installs it. the hub then opens, cannot get at that certificate, and asks
//  apple for one of its own. a free apple id is only allowed one, so apple takes the first one
//  away - the very certificate the hub itself is signed with. from that moment the phone says the
//  two custom apps were signed with a revoked certificate, and the hub greets its owner with
//  "signing certificate mismatch detected" and a resign it usually cannot finish. every customer
//  would hit this on the first evening.
//
//  the old handover was the signing library's own: it writes ALTCertificate.p12 inside the hub's
//  own bundle, locked with the "machine id" apple made up for the certificate, and the hub is
//  meant to work that password out again from apple's certificate list. on the owner's phone
//  (2026-09-07) it did not: "No signable certificate found for serial 2E30F41A...". the file
//  reading itself is fine (the format was tried here against a certificate written the same way),
//  so either the password never matched or the file never arrived, and neither can be told apart
//  from a phone. so the computer step now also leaves the certificate where nothing can go wrong:
//  its two raw pieces, in the hub's own Documents folder, next to the pairing file it already
//  writes there. no password, no archive format, nothing to guess.
//
//  the hub picks it up at launch and whenever it comes back to the front, checks it really is the
//  certificate this copy of the hub was signed with, keeps it in the keychain the way the hub
//  keeps its own, and deletes the file. after that every sign, renewal and update uses it, apple
//  is never asked for another one, and nothing is revoked.
//

import Foundation
import SideSign

enum FMXCertificateHandoff {
    // written by Focusmaxxing Setup into the hub's Documents folder (setup/src-tauri/src/links.rs
    // holds the same name; the two must match)
    static let fileName = "FocusmaxxingCertificate.plist"

    private static let certificateKey = "certificate"
    private static let privateKeyKey = "privateKey"
    private static let machineNameKey = "machineName"
    private static let machineIdKey = "machineId"

    static var fileURL: URL {
        FileManager.default.documentsDirectory.appendingPathComponent(FMXCertificateHandoff.fileName)
    }

    // apple's serial numbers reach us in two spellings: the phone reads them off the certificate
    // itself, the computer writes them as plain text with the leading zeros dropped. compare them
    // the same way or a perfectly good certificate looks like somebody else's.
    static func sameSerial(_ one: String?, _ other: String?) -> Bool {
        guard let one = one, let other = other else { return false }
        return normalised(one) == normalised(other)
    }

    static func normalised(_ serial: String) -> String {
        let trimmed = serial.uppercased().drop { $0 == "0" }
        return trimmed.isEmpty ? "0" : String(trimmed)
    }

    /// Reads the certificate the computer step left behind, if there is one, and makes it the
    /// hub's signing certificate. Safe to call as often as you like: it does nothing when the
    /// file is not there, and removes the file once it has been taken in.
    @discardableResult
    static func adoptIfPresent() -> Bool {
        let url = FMXCertificateHandoff.fileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return false }

        debugLog("[FMXCertificateHandoff] the computer step left a certificate; reading it")

        guard let data = try? Data(contentsOf: url) else {
            debugLog("[FMXCertificateHandoff] could not read the file; leaving it alone")
            return false
        }

        let contents = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        guard let plist = contents as? [String: Any],
              let certificateData = plist[FMXCertificateHandoff.certificateKey] as? Data,
              let privateKeyData = plist[FMXCertificateHandoff.privateKeyKey] as? Data,
              !certificateData.isEmpty, !privateKeyData.isEmpty
        else {
            debugLog("[FMXCertificateHandoff] the file is not a certificate we understand; deleting it")
            FMXCertificateHandoff.deleteFile()
            return false
        }

        guard var x509 = ALTX509Certificate(data: certificateData) else {
            debugLog("[FMXCertificateHandoff] the certificate in the file could not be read; deleting it")
            FMXCertificateHandoff.deleteFile()
            return false
        }

        if let machineName = plist[FMXCertificateHandoff.machineNameKey] as? String, !machineName.isEmpty {
            x509.machineName = machineName
        }
        if let machineID = plist[FMXCertificateHandoff.machineIdKey] as? String, !machineID.isEmpty {
            x509.machineIdentifier = machineID
        }

        let certificate = ALTCertificate(x509: x509, privateKey: privateKeyData)

        // it has to be the certificate this copy of the hub was signed with. anything else would
        // make the hub sign apps with one certificate while wearing another, which is exactly the
        // state that puts the resign screen up.
        let runningSerial = CertificateManager.shared.getSigningCertificate(at: Bundle.Info.activeBundleURL)?.serialNumber
        if let runningSerial = runningSerial, !FMXCertificateHandoff.sameSerial(runningSerial, certificate.serialNumber) {
            debugLog("[FMXCertificateHandoff] the file holds \(certificate.serialNumber) but this hub is signed with \(runningSerial); deleting it unused")
            FMXCertificateHandoff.deleteFile()
            return false
        }
        if runningSerial == nil {
            debugLog("[FMXCertificateHandoff] could not read this hub's own certificate to compare; taking the file at its word")
        }

        do {
            try CertificateManager.shared.setActiveCertificate(certificate)
            debugLog("[FMXCertificateHandoff] took in the certificate from the computer step (serial \(certificate.serialNumber), machine '\(certificate.machineName ?? "unnamed")')")
            FMXCertificateHandoff.deleteFile()
            return true
        } catch {
            // the file stays, so the next launch tries again
            debugLog("[FMXCertificateHandoff] could not store the certificate: \(error)")
            return false
        }
    }

    private static func deleteFile() {
        do {
            try FileManager.default.removeItem(at: FMXCertificateHandoff.fileURL)
        } catch {
            debugLog("[FMXCertificateHandoff] could not delete the file: \(error)")
        }
    }
}
