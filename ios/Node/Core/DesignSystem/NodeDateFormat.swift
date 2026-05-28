import Foundation

enum NodeDateFormat {
    static func monthDay(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).day())
    }

    static func yearMonthDay(_ date: Date) -> String {
        date.formatted(.dateTime.year().month(.wide).day())
    }

    static func yearMonth(_ date: Date) -> String {
        date.formatted(.dateTime.year().month(.wide))
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
    func nodeYearMonth() -> String { NodeDateFormat.yearMonth(self) }
    func nodeYearMonthDayWeekday() -> String { NodeDateFormat.yearMonthDayWeekday(self) }
    func nodeMonthDayWeekday() -> String { NodeDateFormat.monthDayWeekday(self) }
    func nodeTime() -> String { NodeDateFormat.time(self) }
    func nodeMonthDayTime() -> String { NodeDateFormat.monthDayTime(self) }
    func nodeYearMonthDayTime() -> String { NodeDateFormat.yearMonthDayTime(self) }
}
