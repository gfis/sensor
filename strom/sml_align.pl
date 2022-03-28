#!perl

# Synchronisiere den SML-Bytestrom und finde die Anfaenge der Nachrichten
# @(#) $Id$
# 2020-08-09, Georg Fischer
#
#:# Usage:
#:#   cat /dev/ttyUSB0 | hexdump -e ' 16/1 "%02x" "\n"' \
#:#   | perl sml_align > outfile
#--------------------------------------------------------
use strict;
use integer;
use warnings;
$| = 1; # flush output always
my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime (time);
my $timestamp = sprintf ("%04d-%02d-%02d %02d:%02d:%02d", $year + 1900, $mon + 1, $mday, $hour, $min, $sec);
$timestamp = sprintf ("%04d-%02d-%02d", $year + 1900, $mon + 1, $mday);
my $debug = 0;
if (scalar(@ARGV) < 0) {
    print `grep -E "^#:#" $0 | cut -b3-`;
    exit;
}
while (scalar(@ARGV) > 0 and ($ARGV[0] =~ m{\A[\-\+]})) {
    my $opt = shift(@ARGV);
    if (0) {
    } elsif ($opt  =~ m{d}) {
        $debug     = shift(@ARGV);
    } else {
        die "invalid option \"$opt\"\n";
    }
} # while $opt

my $line;
my $sml_start = "1b1b1b1b01010101";
my $buffer = "";
while (<>) {
    s/\s//g; # remove all whitespace
    $line = $_;
    $buffer .= $line;
    if ($debug > 0) {
    	print "line read: $line, buffer length =" . length($buffer) . "\n";
    }
    my $start =   index($buffer, $sml_start);
    if ($start >= 0) {
    	print     substr($buffer, 0, $start) . "\n" . $sml_start;
    	$buffer = substr($buffer, $start + length($sml_start));
    }
} # while <>
__DATA__
 