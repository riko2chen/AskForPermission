import Foundation

public enum PermissionRequestResult: Sendable, Equatable {
    case alreadyAuthorized
    case authorized
    case cancelled
    case timedOut
}
