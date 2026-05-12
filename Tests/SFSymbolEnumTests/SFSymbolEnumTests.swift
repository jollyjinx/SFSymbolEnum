import XCTest
import SFSymbolEnum
import SwiftUI

final class SFSymbolEnumTests: XCTestCase {
    func testSymbolNameMatchesRawValue() {
        XCTAssertEqual(SFSymbol.person.name, "person")
    }

    func testRawValueInitializerValidatesKnownSymbols() {
        XCTAssertEqual(SFSymbol(rawValue: "person"), .person)
        XCTAssertNil(SFSymbol(rawValue: "not.a.real.symbol"))
    }

    func testAllCasesContainsAvailableSymbols() {
        XCTAssertFalse(SFSymbol.allCases.isEmpty)
        XCTAssertTrue(SFSymbol.allCases.contains(.person))
    }

    @available(iOS 13.0, macOS 11.0, tvOS 13.0, visionOS 1.0, watchOS 6.0, *)
    func testImageConvenienceInitializersCompile() {
        let imageFromSystemName = Image(systemName: .person)
        let imageFromSymbol = Image(symbol: .person)

        _ = imageFromSystemName
        _ = imageFromSymbol
    }

    @available(iOS 14.0, macOS 11.0, tvOS 14.0, visionOS 1.0, watchOS 7.0, *)
    func testLabelConvenienceInitializersCompile() {
        let labelFromSystemImage = Label("Person", systemImage: .person)
        let labelFromSymbol = Label("Person", symbol: .person)

        _ = labelFromSystemImage
        _ = labelFromSymbol
    }

    @available(iOS 15.0, macOS 12.0, tvOS 15.0, visionOS 1.0, watchOS 8.0, *)
    func testButtonConvenienceInitializersCompile() {
        let button = Button("Person", symbol: .person) {}
        let roleButton = Button("Cancel", symbol: .person, role: .cancel) {}

        _ = button
        _ = roleButton
    }

    @available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, watchOS 10.0, *)
    func testContentUnavailableViewAcceptsStaticStringSymbolMembers() {
        let view = ContentUnavailableView(
            "No People",
            systemImage: .person,
            description: Text("No people are available.")
        )

        _ = view
    }
}
