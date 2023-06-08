import Foundation

typealias ReleaseDate = String
typealias Symbol = String
typealias Symbols = [Symbol:ReleaseDate]
typealias Release = [String:String]
typealias Releases = [ReleaseDate:Release]
typealias SymbolTuple = (symbol:Symbol,released:ReleaseDate)

extension Release {
    var availabilty:String {
        "available(" +
        self.map{ (os,version) in os + " " + version }.sorted().joined(separator: ",") +
        ",*)"
    }
}

extension Symbol {
    var replacementName:String {
        guard !Set(["return","case","repeat"]).contains(self) else { return "`"+self+"`" }
        let parts = components(separatedBy:".")
        let firstElement = parts.first!
        let camelCase = firstElement + parts.dropFirst().map{ $0.prefix(1).uppercased() + $0.dropFirst()}.joined(separator: "")
        return camelCase.first?.isNumber == true ? "number" + camelCase : camelCase
    }
}


let (sortedSymbolTuple,releaseYears) = readSymbolsAndYears(from:URL(fileURLWithPath:"/Applications/SF Symbols.app/Contents/Resources/Metadata-Public/name_availability.plist"))

print("""
// this file has been generated
// you can recreate it using generateSFSymbolEnum.swift script
import SwiftUI

public enum SFSymbol:String
{
""")

for symbolTuple in sortedSymbolTuple
{
    print("    @" + releaseYears[symbolTuple.released]!.availabilty + " case " + symbolTuple.symbol.replacementName + " = \"" + symbolTuple.symbol + "\"" )
}
print("""
}
extension SFSymbol:CaseIterable
{
    public static var allCases:[SFSymbol] {
                var allCases:[SFSymbol] = []
""")
for symbolTuple in sortedSymbolTuple
{
    print("        if #" + releaseYears[symbolTuple.released]!.availabilty + "{ allCases.append(SFSymbol." + symbolTuple.symbol.replacementName + ") }")
}
print("""
    return allCases
    }
}
""")

exit(1)



func readSymbolsAndYears(from fileURL:URL) -> ( [SymbolTuple],Releases)
{
    let data = try! Data.init(contentsOf: fileURL, options: .mappedIfSafe)
    let propertyList = try! PropertyListSerialization.propertyList(from:data,options:[],format:nil) as! Dictionary<String,Any>

    let symbols     = propertyList["symbols"] as! Symbols
    let releases    = propertyList["year_to_release"] as! Releases

    let releaseDatesFromSymbols     = Set<ReleaseDate>(symbols.values)
    let releaseDatesFromReleases    = Set<ReleaseDate>(releases.keys)

    assert(releaseDatesFromReleases.isSubset(of:releaseDatesFromSymbols),"There are symbols with relasedates that have no release versions \(releaseDatesFromReleases) < \(releaseDatesFromSymbols)")

    let sortedSymbolTuple = symbols
                            .sorted{ $0.value == $1.value ? $0.key < $1.key : $0.value < $1.value}
                            .map{ SymbolTuple(symbol:$0.key,released:$0.value) }

    return (sortedSymbolTuple,releases)
}
