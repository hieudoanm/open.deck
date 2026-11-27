import Foundation

/// Read-side model for a scanned tag — mirrors Android's `NfcTagInfo`
/// (technologies + decoded records).
struct TagInfo: Equatable {
    var uid: String
    var techList: [String]
    var isWritable: Bool
    var isNdefFormattable: Bool
    var maxSize: Int
    var usedSize: Int
    var ndefRecords: [NdefRecord]
}
