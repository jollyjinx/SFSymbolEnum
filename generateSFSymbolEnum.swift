import Foundation

private typealias ReleaseDate = String
private typealias SymbolName = String
private typealias ReleaseVersions = [String: String]

private struct SymbolEntry {
    let name: SymbolName
    let releaseDate: ReleaseDate

    var swiftIdentifier: String {
        let parts = name.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        let firstPart = parts.first ?? ""
        var camelCase = firstPart + parts.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()

        if camelCase.first?.isNumber == true {
            camelCase = "number" + camelCase
        }

        if swiftKeywords.contains(camelCase) {
            camelCase = "`\(camelCase)`"
        }

        return camelCase
    }

    var objcEnumName: String {
        let parts = name.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        let pascalCase = parts.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
        return "SFSymbol" + pascalCase
    }
}

private enum MetadataError: Error, LocalizedError {
    case metadataNotFound
    case malformedMetadata
    case missingReleaseDefinitions([ReleaseDate])

    var errorDescription: String? {
        switch self {
        case .metadataNotFound:
            return "Unable to locate SF Symbols metadata. Set SF_SYMBOLS_METADATA_PLIST to override the default app bundle path."
        case .malformedMetadata:
            return "The SF Symbols metadata plist is missing required keys."
        case .missingReleaseDefinitions(let missingReleaseDates):
            return "Missing release definitions for symbol release dates: \(missingReleaseDates.joined(separator: ", "))"
        }
    }
}

private enum OutputMode {
    case swift
    case objectiveCHeader
    case objectiveCImplementation
}

private let preferredPlatformOrder = ["iOS", "macOS", "tvOS", "visionOS", "watchOS"]
private let swiftKeywords: Set<String> = [
    "Any", "Self", "actor", "as", "associatedtype", "async", "await", "borrowing",
    "break", "case", "catch", "class", "consume", "consuming", "continue", "copy",
    "default", "defer", "deinit", "distributed", "do", "each", "else", "enum",
    "extension", "false", "fileprivate", "for", "func", "guard", "if", "import", "in",
    "init", "inout", "internal", "is", "isolated", "let", "macro", "nil",
    "nonisolated", "open", "operator", "package", "precedencegroup", "private",
    "protocol", "public", "repeat", "rethrows", "return", "self", "sending", "some",
    "static", "struct", "subscript", "super", "switch", "throw", "throws", "true",
    "try", "typealias", "var", "where", "while"
]

private func parseOutputMode(arguments: [String]) -> OutputMode {
    if arguments.contains("--objc-impl") {
        return .objectiveCImplementation
    }

    if arguments.contains("--objc") {
        return .objectiveCHeader
    }

    return .swift
}

private func metadataURL() throws -> URL {
    let environment = ProcessInfo.processInfo.environment
    let candidates = [
        environment["SF_SYMBOLS_METADATA_PLIST"].map(URL.init(fileURLWithPath:)),
        URL(fileURLWithPath: "/Applications/SF Symbols beta.app/Contents/Resources/Metadata/name_availability.plist"),
        URL(fileURLWithPath: "/Applications/SF Symbols.app/Contents/Resources/Metadata/name_availability.plist"),
        URL(fileURLWithPath: "/Applications/SF Symbols.app/Contents/Resources/Metadata-Public/name_availability.plist")
    ].compactMap { $0 }

    guard let url = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
        throw MetadataError.metadataNotFound
    }

    return url
}

private func releaseAvailability(from versions: ReleaseVersions) -> String {
    let orderedPlatforms = preferredPlatformOrder.filter { versions[$0] != nil }
    let remainingPlatforms = versions.keys
        .filter { !preferredPlatformOrder.contains($0) }
        .sorted()
    let allPlatforms = orderedPlatforms + remainingPlatforms

    let requirements = allPlatforms.compactMap { platform in
        versions[platform].map { "\(platform) \($0)" }
    }

    return "available(" + requirements.joined(separator: ", ") + ", *)"
}

private func objcAvailability(from versions: ReleaseVersions) -> String {
    let orderedPlatforms = preferredPlatformOrder.filter { versions[$0] != nil }
    let remainingPlatforms = versions.keys
        .filter { !preferredPlatformOrder.contains($0) }
        .sorted()
    let allPlatforms = orderedPlatforms + remainingPlatforms

    let requirements = allPlatforms.compactMap { platform in
        versions[platform].map { "\(platform.lowercased())(\($0))" }
    }

    return "API_AVAILABLE(" + requirements.joined(separator: ", ") + ")"
}

private func readMetadata(from fileURL: URL) throws -> ([SymbolEntry], [ReleaseDate: ReleaseVersions]) {
    let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
    let propertyList = try PropertyListSerialization.propertyList(from: data, format: nil)

    guard
        let metadata = propertyList as? [String: Any],
        let symbols = metadata["symbols"] as? [SymbolName: ReleaseDate],
        let releases = metadata["year_to_release"] as? [ReleaseDate: ReleaseVersions]
    else {
        throw MetadataError.malformedMetadata
    }

    let missingReleaseDates = Array(Set(symbols.values).subtracting(releases.keys)).sorted()
    guard missingReleaseDates.isEmpty else {
        throw MetadataError.missingReleaseDefinitions(missingReleaseDates)
    }

    let unsortedEntries: [SymbolEntry] = symbols.map { key, value in
        SymbolEntry(name: key, releaseDate: value)
    }
    let entries = unsortedEntries.sorted { lhs, rhs in
        lhs.releaseDate == rhs.releaseDate ? lhs.name < rhs.name : lhs.releaseDate < rhs.releaseDate
    }

    return (entries, releases)
}

private func generateSwiftSource(entries: [SymbolEntry], releases: [ReleaseDate: ReleaseVersions]) -> String {
    var lines = [
        "// this file has been generated",
        "// you can recreate it using generateSFSymbolEnum.swift script",
        "",
        "public extension SFSymbol {"
    ]

    for entry in entries {
        let availability = releaseAvailability(from: releases[entry.releaseDate]!)
        lines.append("    @\(availability) static let \(entry.swiftIdentifier) = SFSymbol(uncheckedRawValue: \"\(entry.name)\")")
    }

    lines.append("}")
    lines.append("")
    lines.append("extension SFSymbol: CaseIterable {")
    lines.append("    public static var allCases: [SFSymbol] { availableSymbols }")
    lines.append("")
    lines.append("    private static let availableSymbols: [SFSymbol] = makeAllCases()")
    lines.append("")
    lines.append("    @inline(never)")
    lines.append("    @_optimize(none)")
    lines.append("    private static func makeAllCases() -> [SFSymbol] {")
    lines.append("        var allCases: [SFSymbol] = []")
    lines.append("        allCases.reserveCapacity(\(entries.count))")
    lines.append("")

    var currentReleaseDate: ReleaseDate?
    for entry in entries {
        if entry.releaseDate != currentReleaseDate {
            if currentReleaseDate != nil {
                lines.append("        }")
                lines.append("")
            }

            let availability = releaseAvailability(from: releases[entry.releaseDate]!)
            lines.append("        if #\(availability) {")
            currentReleaseDate = entry.releaseDate
        }

        lines.append("            allCases.append(.\(entry.swiftIdentifier))")
    }

    if currentReleaseDate != nil {
        lines.append("        }")
    }

    lines.append("")
    lines.append("        return allCases")
    lines.append("    }")
    lines.append("}")

    return lines.joined(separator: "\n")
}

private func generateObjectiveCHeader(entries: [SymbolEntry], releases: [ReleaseDate: ReleaseVersions]) -> String {
    var lines = [
        "// This file has been generated",
        "// You can recreate it using generateSFSymbolEnum.swift script with --objc flag",
        "//",
        "// DO NOT EDIT - This file is automatically generated",
        "",
        "#import <Availability.h>",
        "#import <Foundation/Foundation.h>",
        "",
        "NS_ASSUME_NONNULL_BEGIN",
        "",
        "typedef NS_ENUM(NSInteger, SFSymbol) {"
    ]

    let grouped = Dictionary(grouping: entries, by: \.releaseDate)
    let releaseDates = grouped.keys.sorted()

    var enumValue = 0
    for (releaseIndex, releaseDate) in releaseDates.enumerated() {
        guard let release = releases[releaseDate], let symbols = grouped[releaseDate] else { continue }

        if releaseIndex > 0 {
            lines.append("")
        }

        lines.append("    // Symbols introduced in \(releaseDate)")
        for (symbolIndex, entry) in symbols.enumerated() {
            let isLast = releaseIndex == releaseDates.count - 1 && symbolIndex == symbols.count - 1
            let comma = isLast ? "" : ","
            lines.append("    \(entry.objcEnumName) \(objcAvailability(from: release)) = \(enumValue)\(comma)")
            enumValue += 1
        }
    }

    lines.append("};")
    lines.append("")
    lines.append("NSString * _Nullable SFSymbolGetString(SFSymbol symbol);")
    lines.append("BOOL SFSymbolIsAvailable(SFSymbol symbol);")
    lines.append("")
    lines.append("NS_ASSUME_NONNULL_END")

    return lines.joined(separator: "\n")
}

private func availableString(from versions: ReleaseVersions) -> String {
    let orderedPlatforms = preferredPlatformOrder.filter { versions[$0] != nil }
    let remainingPlatforms = versions.keys
        .filter { !preferredPlatformOrder.contains($0) }
        .sorted()
    let allPlatforms = orderedPlatforms + remainingPlatforms

    return allPlatforms.compactMap { platform in
        versions[platform].map { "\(platform) \($0)" }
    }.joined(separator: ", ")
}

private func generateObjectiveCImplementation(entries: [SymbolEntry], releases: [ReleaseDate: ReleaseVersions]) -> String {
    var lines = [
        "// This file has been generated",
        "// You can recreate it using generateSFSymbolEnum.swift script with --objc-impl flag",
        "//",
        "// DO NOT EDIT - This file is automatically generated",
        "",
        "#import \"SFSymbolEnum.h\"",
        "",
        "NSString * _Nullable SFSymbolGetString(SFSymbol symbol) {",
        "    switch (symbol) {"
    ]

    for entry in entries {
        lines.append("        case \(entry.objcEnumName): return @\"\(entry.name)\";")
    }

    lines.append("        default: return nil;")
    lines.append("    }")
    lines.append("}")
    lines.append("")
    lines.append("BOOL SFSymbolIsAvailable(SFSymbol symbol) {")

    let grouped = Dictionary(grouping: entries, by: \.releaseDate)
    let ascendingReleaseDates = grouped.keys.sorted()
    var rangesByReleaseDate = [ReleaseDate: ClosedRange<Int>]()
    var nextEnumValue = 0
    for releaseDate in ascendingReleaseDates {
        guard let symbols = grouped[releaseDate] else { continue }
        let firstValue = nextEnumValue
        let lastValue = nextEnumValue + symbols.count - 1
        rangesByReleaseDate[releaseDate] = firstValue...lastValue
        nextEnumValue += symbols.count
    }

    let descendingReleaseDates = ascendingReleaseDates.sorted(by: >)
    for (index, releaseDate) in descendingReleaseDates.enumerated() {
        guard let release = releases[releaseDate] else { continue }
        guard let range = rangesByReleaseDate[releaseDate] else { continue }
        let clause = index == 0 ? "if" : "} else if"
        lines.append("    \(clause) (@available(\(availableString(from: release)), *)) {")
        lines.append("        return (symbol >= \(range.lowerBound) && symbol <= \(range.upperBound));")
    }

    lines.append("    } else {")
    lines.append("        return NO;")
    lines.append("    }")
    lines.append("}")

    return lines.joined(separator: "\n")
}

do {
    let mode = parseOutputMode(arguments: CommandLine.arguments)
    let url = try metadataURL()
    let (entries, releases) = try readMetadata(from: url)

    switch mode {
    case .swift:
        print(generateSwiftSource(entries: entries, releases: releases))
    case .objectiveCHeader:
        print(generateObjectiveCHeader(entries: entries, releases: releases))
    case .objectiveCImplementation:
        print(generateObjectiveCImplementation(entries: entries, releases: releases))
    }
} catch {
    fputs("error: \(error.localizedDescription)\n", stderr)
    exit(1)
}
