#!/usr/bin/perl

use strict;
use open qw/ :std :encoding(utf8) /;
use JSON::PP;

my $availabilityJSON = `plutil -convert json -o - "/Applications/SF Symbols.app/Contents/Resources/name_availability.plist"`;

my $sfSymbols = JSON::PP->new->utf8->decode($availabilityJSON);

my $year_to_release = $$sfSymbols{year_to_release};
my $symbols = $$sfSymbols{symbols};

printHeader();
printCases();
printFooter();

printCaseIterableExtension();

exit;

sub symbolsSortedByYearAndName
{
    my @symbolnames;

    for my $availableyear (sort keys %{$year_to_release})
    {
        for my $symbol (sort keys %{$symbols})
        {
            next if $availableyear ne $$symbols{$symbol};

            push(@symbolnames,\[$symbol,availabilityString($availableyear),replacementSymbolName($symbol)]);
        }
    }
    return @symbolnames;
}

sub availabilityString
{
    my($availableyear) = @_;

    my $available = $$year_to_release{$availableyear};
    return '('. join(',',(map { $_.' '.$$available{$_} } sort keys %{$available})) .',*)';
}

sub replacementSymbolName
{
    my($symbolname) = @_;

    my  $replacementname = $symbolname;
        $replacementname =~ s/^(\d)/number$1/;
        $replacementname =~ s{\.(\w)}{ uc($1) }gex;
        $replacementname = '`'.$replacementname.'`' if $replacementname =~ m/^(?:return|repeat|case|if)$/;
    return $replacementname;
}


sub printCases
{
    for my $sortedsymbol (symbolsSortedByYearAndName())
    {
        my($symbolname,$availability,$replacement) = @{$$sortedsymbol};

        print '    @available'.$availability.' case '.$replacement.' = "'.$symbolname.'"'."\n";
    }
}

sub printHeader
{
print <<EOF;
// this file has been generated
// you can recreate it using generateSFSymbolEnum.perl script
//
import SwiftUI

public enum SFSymbol:String  // this enum will be generated
{
EOF
}

sub printFooter
{
print <<EOF;
}
EOF
}


sub printCaseIterableExtension
{

print <<EOF;
extension SFSymbol:CaseIterable
{
    public static var allCases:[SFSymbol] {
                var allCases:[SFSymbol] = []
EOF

    for my $sortedsymbol (symbolsSortedByYearAndName())
    {
        my($symbolname,$availability,$replacement) = @{$$sortedsymbol};

        print '        if #available'.$availability.'{ allCases.append(SFSymbol.'.$replacement.') }'."\n";
    }

    print "    return allCases\n    }\n}\n";
}
