import OSLog

/// Shared logger for tracing the dictation pipeline.
/// View with: log stream --predicate 'subsystem == "com.watervoice.app"'
enum Log {
    static let pipeline = Logger(subsystem: "com.watervoice.app", category: "pipeline")
}
