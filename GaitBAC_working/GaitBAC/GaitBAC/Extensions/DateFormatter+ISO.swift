// GaitBAC/GaitBAC/Extensions/DateFormatter+ISO.swift
import Foundation

extension DateFormatter {

    /// 2025-10-27T16:42:31-04:00
    static func iso8601Full() -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
        return f
    }

    /// 20251027_164231Z (UTC-stamped, if you need it)
    static func iso8601BasicZ() -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd_HHmmss'Z'"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }

    /// 20251027_164231 (local, compact)
    static func compactTS() -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd_HHmmss"
        return f
    }

    /// 20251027-164231 (if your CSV names expect a hyphen)
    static func yyyyMMdd_HHmmss() -> DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd-HHmmss"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df
    }
}
