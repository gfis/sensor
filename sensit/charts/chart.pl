#!perl

# Extract data from https://www.sensit.io/app/sensit/5f79637c0b343eb2cb39df3c?mode=temperature&view=logs
# 2021-05-07, Georg Fischer

#:# Usage:
#:#   perl chart.pl [-d debug] [-s sel] input > output
#:#     -d debugging level (0=none (default), 1=some, 2=more)
#:#     -s selection: 0 = all, 1 = some, 2 = specific ...
#--------------------------------------------------------
use strict;
use integer;
use warnings;

my $sel = 0;
my $line = "";
my ($tlet, $aseqno, $callcode, $name, $form);
my $debug   = 0;
while (scalar(@ARGV) > 0 && ($ARGV[0] =~ m{\A[\-\+]})) {
    my $opt = shift(@ARGV);
    if (0) {
    } elsif ($opt   =~ m{\-d}  ) {
        $debug      = shift(@ARGV);
    } elsif ($opt   =~ m{\-s}  ) {
        $sel        = shift(@ARGV);
    } else {
        die "invalid option \"$opt\"\n";
    }
} # while $opt

my %months = qw(Jan 01 Feb 02 Mar 03 Apr 04 May 05 Jun 06 Jul 07 Aug 08 Sep 09 Oct 10 Nov 11 Dec 12);

while (<>) { #
    s/\s+\Z//; # chompr
    my $line = $_;
    $line =~ s{\<\w+[^\>]*\>}{}g;
    $line =~ s{\<\/div\>}{\n}g;
    $line =~ s{\<\/\w+\>}{}g;
    my ($month3, $mon, $day, $year) = ("", "", "", "");
    my ($hour, $min, $ampm)         = ("", "", "");
    my ($temperat, $humid)          = ("", "");
    foreach my $field (split(/\n/, $line)) {
        if ($field =~ m{\A\s*\Z}) {
            # ignore empty field
        } elsif ($field =~ m{\A([A-Z][a-z]+) +(\d+)\, +(\d+)}) {
            ($month3, $day, $year) = ($1, $2, $3);
            $mon = $months{$month3} || "??";
        } elsif ($field =~ m{\A(\d+)\:(\d+) +([AP]M)}) {
            ($hour, $min, $ampm) = ($1, $2, $3);
            if (0) {
            } elsif ($hour eq "12" and $ampm eq "AM") {
                $hour = "00";
            } elsif ($hour eq "12" and $ampm eq "PM") {
                $hour = "12";
            } elsif (                  $ampm eq "PM") {
                $hour += 12;
            # else AM - leave it
            }
        } elsif ($field =~ m{\A(\d+(\.\d+)?) +\°C}) {
            ($temperat) = sprintf ("%5.2f", $1);
        } elsif ($field =~ m{\A(\d+(\.\d+)?) +\%}) {
            ($humid)    = sprintf ("%6.1f", $1);
            print join("\t", "$year-$mon-$day", "$hour:$min", "$temperat \°C", "$humid \%") . "\n";
        } else {
            # print "\n??? ungueltiges Feld: $field";
        }
    } # foreach $field
} # while <>
__DATA__
May 06, 2021
07:02 PM

13.75 °C


May 06, 2021
07:02 PM

55.5 %


May 06, 2021
06:02 PM

13.75 °C


May 06, 2021
06:02 PM

55.5 %
