import Foundation

/// Namespace for logging API used to propagate internal Workflow-related logging to external consumers
public enum ExternalLogging {}

extension ExternalLogging {
    /// Log level indicating 'severity' of the corresponding `LogEvent`
    public enum LogLevel {
        case info
        case error
    }

    /// A log event
    public struct LogEvent {
        public let message: String
        public let level: LogLevel
    }

    /// Wrapper that allows for propagating log events to outside consumers.
    internal struct ExternalLogger {
        private let implementation: (LogEvent) -> Void

        internal init(_ implementation: @escaping (LogEvent) -> Void) {
            self.implementation = implementation
        }

        internal func log(_ payload: LogEvent) { implementation(payload) }
    }

    /// Shared external logger variable
    internal static var logger: ExternalLogger?

    /// External logging bootstrapping method.
    /// Call once with the desired log handler.
    /// - Parameter logHandler: Callback to handle logging events.
    public static func configure(
        _ logHandler: @escaping (LogEvent) -> Void
    ) {
        assert(
            logger == nil,
            "Workflow external logger already configured."
        )

        logger = ExternalLogger(logHandler)
    }
}

extension ExternalLogging.LogEvent {
    /// Convenience to create an info-level `LogEvent`
    static func info(_ message: String) -> Self {
        .init(message: message, level: .info)
    }

    /// Convenience to create an error-level `LogEvent`
    static func error(_ message: String) -> Self {
        .init(message: message, level: .error)
    }
}

extension ExternalLogging {
    // Logs an info message via the global logger (if set)
    static func logInfo(_ message: @autoclosure () -> String) {
        logger?.log(.info(message()))
    }

    // Logs an error message via the global logger (if set)
    static func logError(_ message: @autoclosure () -> String) {
        logger?.log(.error(message()))
    }
}
