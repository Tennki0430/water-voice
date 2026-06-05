import Foundation

/// 使用統計を UserDefaults に記録・集計するクラス。
/// タイピング速度を平均 300文字/分 と仮定して節約時間を算出します。
@MainActor
final class StatsTracker: ObservableObject {
    @Published private(set) var totalChars: Int = 0
    @Published private(set) var totalSessions: Int = 0
    @Published private(set) var todayChars: Int = 0

    private let defaults = UserDefaults.standard
    private let typingCharsPerMinute: Double = 300

    private enum Key {
        static let totalChars    = "watervoice.stats.totalChars"
        static let totalSessions = "watervoice.stats.totalSessions"
        static let todayChars    = "watervoice.stats.todayChars"
        static let lastDate      = "watervoice.stats.lastDate"
    }

    init() { load() }

    // MARK: - Public

    /// テキストが貼り付けられたときに呼ぶ。
    func record(text: String) {
        resetIfNewDay()
        let count = text.count
        totalChars    += count
        todayChars    += count
        totalSessions += 1
        save()
    }

    /// 節約できた分数（タイピングとの比較）
    var savedMinutesTotal: Double { Double(totalChars) / typingCharsPerMinute }
    var savedMinutesToday: Double { Double(todayChars) / typingCharsPerMinute }

    // MARK: - Private

    private func load() {
        resetIfNewDay()
        totalChars    = defaults.integer(forKey: Key.totalChars)
        totalSessions = defaults.integer(forKey: Key.totalSessions)
        todayChars    = defaults.integer(forKey: Key.todayChars)
    }

    private func save() {
        defaults.set(totalChars,    forKey: Key.totalChars)
        defaults.set(totalSessions, forKey: Key.totalSessions)
        defaults.set(todayChars,    forKey: Key.todayChars)
    }

    private func resetIfNewDay() {
        let today = Calendar.current.startOfDay(for: Date())
        let last  = defaults.object(forKey: Key.lastDate) as? Date ?? .distantPast
        if today > Calendar.current.startOfDay(for: last) {
            defaults.set(0,     forKey: Key.todayChars)
            defaults.set(today, forKey: Key.lastDate)
        }
    }
}
