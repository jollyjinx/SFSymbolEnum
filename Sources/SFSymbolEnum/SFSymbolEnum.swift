import Foundation
import SwiftUI

public struct SFSymbol: RawRepresentable, Hashable, Sendable {
    public let rawValue: String

    init(uncheckedRawValue rawValue: String) {
        self.rawValue = rawValue
    }

    public init?(rawValue: String) {
        guard Self.knownRawValues.contains(rawValue) else { return nil }
        self.rawValue = rawValue
    }
}

public extension SFSymbol {
    var name: String { rawValue }

    @available(iOS 13.0, macOS 11.0, tvOS 13.0, visionOS 1.0, watchOS 6.0, *)
    var image: Image { Image(systemName: rawValue) }
}

@available(iOS 13.0, macOS 11.0, tvOS 13.0, watchOS 6.0, *)
public extension Image {
    @available(iOS 13.0, macOS 11.0, tvOS 13.0, visionOS 1.0, watchOS 6.0, *)
    init(systemName symbol: SFSymbol) {
        self = Image(systemName: symbol.name)
    }

    @available(iOS 13.0, macOS 11.0, tvOS 13.0, visionOS 1.0, watchOS 6.0, *)
    init(symbol: SFSymbol) {
        self = Image(systemName: symbol.name)
    }
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, visionOS 1.0, watchOS 7.0, *)
public extension Label {
    init(_ title: LocalizedStringKey, systemImage symbol: SFSymbol) where Title == Text, Icon == Image {
        self = Label(title, systemImage: symbol.name)
    }

    init(_ title: LocalizedStringKey, symbol: SFSymbol) where Title == Text, Icon == Image {
        self = Label(title, systemImage: symbol.name)
    }
}

public extension Button {
    @available(iOS 14.0, macOS 11.0, tvOS 14.0, visionOS 1.0, watchOS 7.0, *)
    init(_ titleKey: LocalizedStringKey, symbol: SFSymbol, action: @escaping () -> Void) where Label == SwiftUI.Label<Text,Image> {
        self = Button(action: action) {
            SwiftUI.Label(titleKey, symbol: symbol)
        }
    }

    @available(iOS 15.0, macOS 12.0, tvOS 15.0, visionOS 1.0, watchOS 8.0, *)
    init(_ titleKey: LocalizedStringKey, symbol: SFSymbol, role: ButtonRole?, action: @escaping () -> Void) where Label == SwiftUI.Label<Text,Image> {
        self = Button(titleKey, systemImage: symbol.name, role: role, action: action)
    }
}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, watchOS 10.0, *)
public extension ContentUnavailableView where Label == SwiftUI.Label<Text, Image>, Description == Text?, Actions == EmptyView {
    init(_ titleKey: LocalizedStringKey, systemImage symbol: SFSymbol, description: Text? = nil) {
        self.init(titleKey, systemImage: symbol.name, description: description)
    }
}

extension SFSymbol: CaseIterable {
    public static var allCases: [SFSymbol] {
        availableSymbols
    }

    fileprivate static let knownRawValues: Set<String> = Set(symbolRecords.map(\.rawValue))

    private static let availableSymbols: [SFSymbol] = symbolRecords.compactMap { record in
        guard record.isAvailableOnCurrentPlatform else { return nil }
        return SFSymbol(uncheckedRawValue: record.rawValue)
    }

    private static let symbolRecords: [SFSymbolRecord] = loadSymbolRecords()
}

private struct SFSymbolRecord {
    let rawValue: String
    let requiredVersion: OperatingSystemVersion?

    var isAvailableOnCurrentPlatform: Bool {
        guard let requiredVersion else { return false }
        return isVersion(ProcessInfo.processInfo.operatingSystemVersion, atLeast: requiredVersion)
    }
}

private func loadSymbolRecords() -> [SFSymbolRecord] {
    guard let url = Bundle.module.url(forResource: "SFSymbols", withExtension: "tsv"),
          let contents = try? String(contentsOf: url, encoding: .utf8) else {
        return []
    }

    return contents.split(separator: "\n", omittingEmptySubsequences: true).compactMap { line in
        let parts = line.split(separator: "\t", omittingEmptySubsequences: false)
        guard let rawValue = parts.first else { return nil }
        return SFSymbolRecord(
            rawValue: String(rawValue),
            requiredVersion: parts.dropFirst().requiredVersionForCurrentPlatform
        )
    }
}

private extension ArraySlice where Element == Substring {
    var requiredVersionForCurrentPlatform: OperatingSystemVersion? {
        for requirement in self {
            let parts = requirement.split(separator: "=", maxSplits: 1)
            guard parts.count == 2, String(parts[0]) == currentPlatformName else { continue }
            return OperatingSystemVersion(sfsymbolVersion: parts[1])
        }

        return nil
    }
}

private let currentPlatformName: String = {
    #if targetEnvironment(macCatalyst)
    return "iOS"
    #elseif os(iOS)
    return "iOS"
    #elseif os(macOS)
    return "macOS"
    #elseif os(tvOS)
    return "tvOS"
    #elseif os(visionOS)
    return "visionOS"
    #elseif os(watchOS)
    return "watchOS"
    #else
    return ""
    #endif
}()

private extension OperatingSystemVersion {
    init(sfsymbolVersion version: Substring) {
        let components = version.split(separator: ".").map { Int($0) ?? 0 }
        self.init(
            majorVersion: components.count > 0 ? components[0] : 0,
            minorVersion: components.count > 1 ? components[1] : 0,
            patchVersion: components.count > 2 ? components[2] : 0
        )
    }
}

private func isVersion(_ currentVersion: OperatingSystemVersion, atLeast requiredVersion: OperatingSystemVersion) -> Bool {
    if currentVersion.majorVersion != requiredVersion.majorVersion {
        return currentVersion.majorVersion > requiredVersion.majorVersion
    }

    if currentVersion.minorVersion != requiredVersion.minorVersion {
        return currentVersion.minorVersion > requiredVersion.minorVersion
    }

    return currentVersion.patchVersion >= requiredVersion.patchVersion
}
