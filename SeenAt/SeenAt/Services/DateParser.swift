import Foundation

func parseISODate(_ dateString: String) -> Date? {
    let withFractional = ISO8601DateFormatter()
    withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = withFractional.date(from: dateString) { return date }

    let standard = ISO8601DateFormatter()
    standard.formatOptions = [.withInternetDateTime]
    if let date = standard.date(from: dateString) { return date }

    let noSeconds = DateFormatter()
    noSeconds.locale = Locale(identifier: "en_US_POSIX")
    noSeconds.timeZone = TimeZone(secondsFromGMT: 0)
    noSeconds.dateFormat = "yyyy-MM-dd'T'HH:mmZZZZZ"
    if let date = noSeconds.date(from: dateString) { return date }

    let dateOnly = DateFormatter()
    dateOnly.locale = Locale(identifier: "en_US_POSIX")
    dateOnly.timeZone = TimeZone(secondsFromGMT: 0)
    dateOnly.dateFormat = "yyyy-MM-dd"
    return dateOnly.date(from: dateString)
}
