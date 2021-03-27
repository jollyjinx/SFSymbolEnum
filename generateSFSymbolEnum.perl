#!/usr/bin/perl

use strict;
use open qw/ :std :encoding(utf8) /;
use JSON::PP;

my $availabilityJSON = `plutil -convert json -o - "/Applications/SF Symbols.app/Contents/Resources/name_availability.plist"`;

my $sfSymbols = JSON::PP->new->utf8->decode($availabilityJSON);

my $year_to_release = $$sfSymbols{year_to_release};
my $symbols = $$sfSymbols{symbols};

printHeader();
printSymbols();
printFooter();

printCaseIterableExtension();

exit;

sub printSymbols
{
    for my $availableyear (sort keys %{$year_to_release})
    {
        for my $symbol (sort keys %{$symbols})
        {
            next if $availableyear ne $$symbols{$symbol};

            my $replacementname = $symbol;
            $replacementname =~ s/\./_/g;
            $replacementname =~ s/^(\d)/_\1/;
            $replacementname = '`'.$replacementname.'`';
            print '    @available'.availabilityString($availableyear).' case '.$replacementname.' = "'.$symbol.'"'."\n";
        }
    }
}

sub availabilityString
{
    my($availableyear) = @_;

    my $available = $$year_to_release{$availableyear};
    return '('. join(',',(map { $_.' '.$$available{$_} } sort keys %{$available})) .',*)';
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

    for my $availableyear (sort keys %{$year_to_release})
    {
        for my $symbol (sort keys %{$symbols})
        {
            next if $availableyear ne $$symbols{$symbol};

            my $replacementname = $symbol;
            $replacementname =~ s/\./_/g;
            $replacementname =~ s/^(\d)/_\1/;
            $replacementname = '`'.$replacementname.'`';
            print '    if #available'.availabilityString($availableyear).'{ allCases.append(SFSymbol.'.$replacementname.') }'."\n";
        }
    }
    print "    return allCases\n\t}\n}\n";
}
