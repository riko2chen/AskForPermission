import CoreFoundation
import Foundation

// Uses private TCC SPI via dlopen/dlsym only, so the package never links TCC.framework at build time.

private let tccFrameworkPath = "/System/Library/PrivateFrameworks/TCC.framework/TCC"
private let tccAccessPreflightSymbol = "TCCAccessPreflight"
private let developerToolsServiceSymbol = "kTCCServiceDeveloperTool"
private let appManagementServiceSymbol = "kTCCServiceSystemPolicyAppBundles"

private typealias TCCAccessPreflightFn = @convention(c) (CFString, CFDictionary?) -> Int32
private enum TCCPrivateSPICache {
    static let frameworkHandle = dlopen(tccFrameworkPath, RTLD_LAZY | RTLD_LOCAL)
    static let accessPreflight: TCCAccessPreflightFn? = {
        guard let handle = frameworkHandle else { return nil }
        guard let symbol = dlsym(handle, tccAccessPreflightSymbol) else { return nil }
        return unsafeBitCast(symbol, to: TCCAccessPreflightFn.self)
    }()
    static let developerToolsService = loadTCCService(named: developerToolsServiceSymbol)
    static let appManagementService = loadTCCService(named: appManagementServiceSymbol)
}

func tccAccessPreflight(service: String) -> Bool {
    guard let fn = TCCPrivateSPICache.accessPreflight else { return false }
    let status = fn(service as CFString, nil)
    return status == 0
}

func developerToolsTCCService() -> String? {
    TCCPrivateSPICache.developerToolsService
}

func appManagementTCCService() -> String? {
    TCCPrivateSPICache.appManagementService
}

private func loadTCCService(named symbolName: String) -> String? {
    guard let handle = TCCPrivateSPICache.frameworkHandle else { return nil }
    guard let symbol = dlsym(handle, symbolName) else { return nil }
    let pointer = symbol.assumingMemoryBound(to: CFString?.self)
    guard let cfStr = pointer.pointee else { return nil }
    return cfStr as String
}
