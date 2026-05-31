import Foundation

enum NodeDateFormat {
    static func monthDay(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).day())
    }

    static func yearMonthDay(_ date: Date) -> String {
        date.formatted(.dateTime.year().month(.wide).day())
    }

    /// 観測日ラベル用の固定形式 (例: 2026.05.31)。暦は `Calendar.current` に従う。
    static func dotYearMonthDay(_ date: Date) -> String {
        var calendar = Calendar.current
        calendar.locale = .current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        return String(format: "%04d.%02d.%02d", year, month, day)
    }

    static func yearMonth(_ date: Date) -> String {
        date.formatted(.dateTime.year().month(.wide))
    }

    /// 月チップ用のコンパクト形式 (例: 2026/05)。
    static func compactYearMonth(_ date: Date) -> String {
        var calendar = Calendar.current
        calendar.locale = .current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        return String(format: "%04d/%02d", year, month)
    }

    static func yearMonthDayWeekday(_ date: Date) -> String {
        date.formatted(.dateTime.year().month(.wide).day().weekday(.abbreviated))
    }

    static func monthDayWeekday(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).day().weekday(.abbreviated))
    }

    static func time(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened))
    }

    static func monthDayTime(_ date: Date) -> String {
        "\(monthDay(date)) · \(time(date))"
    }

    static func yearMonthDayTime(_ date: Date) -> String {
        "\(yearMonthDay(date)) · \(time(date))"
    }
}

extension Date {
    func nodeMonthDay() -> String { NodeDateFormat.monthDay(self) }
    func nodeYearMonthDay() -> String { NodeDateFormat.yearMonthDay(self) }
    func nodeDotYearMonthDay() -> String { NodeDateFormat.dotYearMonthDay(self) }
    func nodeYearMonth() -> String { NodeDateFormat.yearMonth(self) }
    func nodeCompactYearMonth() -> String { NodeDateFormat.compactYearMonth(self) }
    func nodeYearMonthDayWeekday() -> String { NodeDateFormat.yearMonthDayWeekday(self) }
    func nodeMonthDayWeekday() -> String { NodeDateFormat.monthDayWeekday(self) }
    func nodeTime() -> String { NodeDateFormat.time(self) }
    func nodeMonthDayTime() -> String { NodeDateFormat.monthDayTime(self) }
    func nodeYearMonthDayTime() -> String { NodeDateFormat.yearMonthDayTime(self) }
}
