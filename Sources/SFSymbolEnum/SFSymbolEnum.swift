import SwiftUI

public extension SFSymbol
{
    var name:String { return self.rawValue }

    @available(iOS 13.4, macOS 11.0, tvOS 13.0, watchOS 6.0, *)
    var image:Image { return Image(systemName:self.rawValue) }
}

@available(iOS 13.0, macOS 11.0, tvOS 13.0, watchOS 6.0, *)
public func Image(systemName symbol:SFSymbol) -> Image
{
    return Image(systemName:symbol.name)
}

@available(iOS 13.0, macOS 11.0, tvOS 13.0, watchOS 6.0, *)
public func Image(symbol:SFSymbol) -> Image
{
    return Image(systemName:symbol.name)
}


@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public func Label(_ title:String, systemImage symbol:SFSymbol) -> Label<Text, Image>
{
    return Label(title,systemImage:symbol.name)
}


