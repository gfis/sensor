#!perl

# Lies Einzelzeichen aus dem SML-Bytestrom und finde die Anfaenge der Nachrichten
# @(#) $Id$
# 2020-09-10, Georg Fischer
#
#:# Usage:
#:#   cat /dev/ttyUSB0 | hexdump -e ' 16/1 "%02x" "\n"' \
#:#   | perl sml_align > outfile
#--------------------------------------------------------
use strict;
use integer;
use warnings;

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
        die "Ungueltige Option \"$opt\"\n";
    }
} # while $opt

my $tty = "/dev/ttyUSB0";
my $sml_start = "1b1b1b1b01010101";
print `stty -F $tty -icanon`;
open(TTY, "<", $tty) || die "Kann nicht von $tty lesen";
my $state = "su1b"; # Suche nach $sml_start
my $imark = 0; # Position in $sml_start

while (1) { # unendliche Schleife
	my $hex2 = sprintf("%02x", ord(getc(TTY)));
	if (0) {
	} elsif ($state eq "su1b") { # Beginn des $sml_start?
	    if ($hex2 eq "1b") {
	    	$state = "in1b";
	    	$imark = 2;
	    } else {
	    	print $hex2;
        }
	} elsif ($state eq "in1b") {
		if ($imark >= length($sml_start)) { # vollstaendiger $sml_start wurde erkannt
			print "\n\n$sml_start\n";
	    	print $hex2;
			$state = "su1b";
		} elsif ($hex2 eq substr($sml_start, $imark, 2)) { # stimmt mit naechstem Byte in $sml_start ueberein
			$imark += 2;
		} else {
			print substr($sml_start, 0, $imark);
	    	print $hex2;
			$state = "su1b"; # kein vollstaendiger $sml_start - suche weiter danach
		}
    } else {
    	die "Ungueltiger Zustand $state";
	}
} # while 1
__DATA__
 