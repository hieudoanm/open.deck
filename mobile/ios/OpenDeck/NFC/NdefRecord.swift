import Foundation

/// Parsed NDEF record model — mirrors Android's record decoding in `Nfc.kt`
/// (URI / text / MIME / absolute-URI / external / unknown).
enum NdefRecord: Equatable {
    case text(String, languageCode: String)
    case uri(String)
    case mime(String, payload: Data)
    case aar(String)
    case unknown(tnf: Int, type: Data, payload: Data)
}
