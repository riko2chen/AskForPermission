import Foundation

public struct PermissionRequestError: Error, Sendable, Equatable {
    public enum Code: String, Sendable {
        case missingHostApplicationBundle
        case settingsWindowNotFound
        case openSystemSettingsFailed
    }

    public let code: Code
    public let message: String

    public init(code: Code, message: String) {
        self.code = code
        self.message = message
    }
}

extension PermissionRequestError: LocalizedError {
    public var errorDescription: String? { message }
}
