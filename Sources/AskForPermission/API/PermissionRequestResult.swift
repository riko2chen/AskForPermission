import Foundation

public enum PermissionRequestResult: Sendable, Equatable {
    case alreadyAuthorized
    case authorized
    case cancelled
    case timedOut
    /// The request could not run because of a runtime environment issue
    /// (missing .app bundle, System Settings failed to open, etc.). Callers
    /// that previously caught `PermissionRequestError` should branch on this
    /// case instead.
    case unavailable(PermissionRequestError)
}
