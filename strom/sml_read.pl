#!perl

# Lies Einzelzeichen aus dem SML-Bytestrom und finde die Anfaenge der Nachrichten
# @(#) $Id$
# 2020-09-10, Georg Fischer
#
#:# Usage:
#:#   perl sml_read.pl [-d mode] [-f logfile] # liest von /dev/ttyUSB0
#:#       -d mode: 0 nur Nutzdaten, 1 Gruppen, 2 Komplettdump
#:#       -f logfile (default: /run/sensor/sml_read.log)
#--------------------------------------------------------
use strict;
use integer;
use warnings;

# $| = 1; # autoflush on

if (scalar(@ARGV) < 0) {
    print `grep -E "^#:#" $0 | cut -b3-`;
    exit;
}
my $old_time  = time();
my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime ($old_time);
my $old_stamp = sprintf ("%04d-%02d-%02d %02d:%02d:%02d", $year + 1900, $mon + 1, $mday, $hour, $min, $sec);
my $new_stamp = $old_stamp;
# yyyy-mm-dd HH:MM:SS
# 0123456789012345678
my $old_day   = substr($old_stamp, 0, 10); 
my $old_m10   = substr($old_stamp, 14, 1); 
my $new_day   = $old_day;
my $new_m10   = $old_m10;
my $new_time  = $old_time; # aktuelle Zeit der Messung in Sekunden seit 1970-01-01
my $dwh       = 0; # dezi-Watt-Stunden

my $tty = "/dev/ttyUSB0";
# Terminaleinstellungen fuer Weidmann USB-Lesekopf: Baudrate, Einzelzeichen etc.
# system("stty -F $tty 9600 -parenb cs8 -cstopb -ixoff -crtscts -hupcl -ixon -opost -onlcr -isig -icanon -iexten -echo -echoe -echoctl -echoke");
open(TTY, "<", $tty) || die "Kann nicht von $tty lesen";

my $debug = 0;
my $compressed = 0;
my $log_file = "/run/sensor/sml_read.log";
while (scalar(@ARGV) > 0 and ($ARGV[0] =~ m{\A[\-\+]})) {
    my $opt = shift(@ARGV);
    if (0) {
    } elsif ($opt   =~ m{c}) {
        $compressed = shift(@ARGV);
    } elsif ($opt   =~ m{d}) {
        $debug      = shift(@ARGV);
    } elsif ($opt   =~ m{f}) {
        $log_file   = shift(@ARGV);
    } else {
        die "invalid option \"$opt\"\n";
    }
} # while $opt

my $log_path = "/run/sensor";
if ($log_file =~ m{\A(\/(\w+\/)*)}) { # fremdes Verzeichnis
    $log_path = substr($1, 0, length($1) - 1); # ausser dem letzten Schraegstrich
    mkdir($log_path);
} # fremdes Verzeichnis
open(OBI, ">", $log_file) or die "Kann $log_file nicht schreiben";
# binmode OBI;
print "Log in $log_file\n";
print OBI "# Log Start $old_stamp\n";

my %obis_codes = # von http://blog.bubux.de/raspberry-pi-ehz-auslesen/
    (   '0100000000FF', 'Seriennummer'
    ,   '0100100700FF', 'Momentane Wirkleistung Bezug'
    ,   '0100200700FF', 'Momentane Wirkleistung Lieferung'
    ,   '0100010801FF', 'Wirk-Energie Tarif 1 Bezug'
    ,   '0100020801FF', 'Wirk-Energie Tarif 1 Lieferung'
    ,   '0100010802FF', 'Wirk-Energie Tarif 2 Bezug'
    ,   '0100020802FF', 'Wirk-Energie Tarif 2 Lieferung'
    ,   '0100010803FF', 'Wirk-Energie Tarif 3 Bezug'
    ,   '0100020803FF', 'Wirk-Energie Tarif 3 Lieferung'
    ,   '8181C78203FF', 'Hersteller-ID '
    ,   '8181C78205FF', 'Public-Key'
    ,   '01000F0700FF', 'Active Power'
    ,   '0100010800FF', 'Wirkarbeit Zaehlerstand' # Bezug Total
    ,   '0100000009FF', 'Geraeteeinzelidentifikation'
    ,   '00006001FFFF', 'Fabriknummer'
    ,   '0100240700FF', 'Current Power L1'
    ,   '0100380700FF', 'Current Power L2'
    ,   '01004C0700FF', 'Current Power L3'
    );
my $sml_start = "1b1b1b1b01010101";
my $msg_state = "su1b"; # Suche nach $sml_start
my $imark = 0; # Position in $sml_start
my $sync  = 0; # solange kein $sml_start erkannt wurde
my @stack = (0);
my $indent = "  ";
my $ind = 0;
my $level = 0;
my $asn_state = "sust"; # suche Simple Type
my $astbuf = "";
my $astlen;
my $astind;
my $asttyp;
my @obis = (); # Puffer fuer OBIS-Felder
my $obix = -1; # Index fuer OBIS-Felder
my $outbuf = "";

while (1) { # unendliche Schleife
    my $hex2 = sprintf("%02x", ord(getc(TTY)));
    if (0) {
    } elsif ($msg_state eq "su1b") { # Beginn des $sml_start?
        if ($hex2 eq "1b") {
            $msg_state = "in1b";
            $imark = 2;
        } else {
        }
    } elsif ($msg_state eq "in1b") {
        if ($imark >= length($sml_start)) { # vollstaendiger $sml_start wurde erkannt
            &dump("\n#----------------\n# Start SML-Nachricht\n");
            $sync  = 1;
            $asn_state = "sust";
            $msg_state = "su1b";
        } elsif ($hex2 eq substr($sml_start, $imark, 2)) { # stimmt mit naechstem Byte in $sml_start ueberein
            $imark += 2;
        } else {
            $msg_state = "su1b"; # kein vollstaendiger $sml_start - suche weiter danach
        }
    } else {
        die "Ungueltiger Zustand $msg_state";
    }
    &proc($hex2);
} # while 1
#----
sub proc {
    my ($byte) = @_;
    # &dump($byte);
    if (0) {
    } elsif ($asn_state eq "sust") { # Suche Simple Type
        $asttyp = hex(substr($byte, 0, 1));
        $astlen = hex(substr($byte, 1, 1));
        $astbuf = $byte;
        if (0) {
        } elsif ($asttyp == 0 && $astlen == 0) {
            &dump(" # Ende SML-Nachricht\n");
        } elsif ($asttyp == 7) { # Gruppe
            &dump(" # Gruppe\n");
        } elsif ($asttyp == 8) { # long octet string, naechstes Byte wird auf Laenge addiert
            $astind = 1;
            $asn_state = "lon2";
        } else {            
            $astind = 1;
            if ($astind < $astlen) {
                $asn_state = "inst";
            } else {
                &dump(" # 1 Byte\n");
            }
        }
     } elsif ($asn_state eq "lon2") { 
        $astbuf .= $byte;
        $astlen = ($astlen << 4) + hex($byte);
        $astind ++;
        $asn_state = "inst";
     } elsif ($asn_state eq "inst") {
        $astbuf .= $byte;
        $astind ++;
        if ($astind >= $astlen) { # Ende des Felds
            if (0) {
            } elsif ($asttyp == 0) { # octet string
                &dump(" # Bytes\n");
            } elsif ($asttyp == 5) { # signed value
                &dump(" # nat. Zahl\n");
            } elsif ($asttyp == 6) { # unsigned integer
                &dump(" # Zahl\n");
            } elsif ($asttyp == 8) { # unsigned integer
                &dump(" # viele Bytes\n");
            } else {
                &dump(" # **** unbekannter Typ ****\n");
            }
            $asn_state = "sust";
        }
    } else {
        die "Ungueltiger Zustand $asn_state";
    }
} # proc
#----
sub dump {
    my ($text) = @_;
    if (0) {
    } elsif ($debug >= 2) {
        print $astbuf . $text;
    } else { # akkumuliere OBIS-Gruppe
        if (substr($astbuf, 0, 2) eq "77") { # Beginn einer Gruppe von 7
            if ($obix >= 0) {
                &eval_obis();
            }
            $obix = 0;
        } elsif ($obix >= 0 && $obix < 7) {
            $obis[$obix ++] = $astbuf;
            if ($obix == 7) {
                &eval_obis();
                $obix = -1;
            }
        }
    } # akkumuliere
} # dump
#----
sub eval_obis {
    my $code = uc(substr($obis[0], 2));
    if ($debug >= 1 && (substr($obis[0], 0, 4) eq "0701")) {
        print "# OBIS: " . join(", ", @obis) 
            . ": " . $obis_codes{$code}
            . "\n";
    }
    if (0) {
    } elsif ($code eq "0100010800FF") { # Zaehlerstand
        $dwh = hex(substr($obis[5], 2)); # deci-Watt-Stunden
        $new_time = time();
        my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime ($new_time);
        $new_stamp = sprintf ("%04d-%02d-%02d_%02d:%02d:%02d", $year + 1900, $mon + 1, $mday, $hour, $min, $sec);
        if ($old_day ne substr($new_stamp, 0, 10)) { # Tag hat gewechselt
            $old_day =  substr($new_stamp, 0, 10);
            $old_m10 =  substr($new_stamp, 14, 1);
            $new_day =  $old_day;
            $new_m10 =  $old_m10;
            close(OBI);
            open (OBI, ">", $log_file) or die "Kann $log_file am Tagesende nicht ueberschreiben";
        } # Tageswechsel
    } elsif ($code eq "0100100700FF") { # momentane Leistung
        my $watt = hex(substr($obis[5], 2));
        my $kwh  = ($dwh / 10000) . "." . ($dwh % 10000);
        if (1) { # Warum ???
            close(OBI);
            open (OBI, ">>", $log_file) or die "Kann $log_file am Tagesende nicht ueberschreiben";
        }
        if (! print OBI join(",", $new_time, $new_stamp, $kwh, $watt) . "\n") {
        	print STDERR "error: errno\n";
        }
        print           join(",", $new_time, $new_stamp, $kwh, $watt) . "\n";
    }   
} # eval_obis
__DATA__
-d 1:
# OBIS: 070100010800ff, 6500000180, 01, 621e, 52ff, 5900000000010f5a0a, 01: Wirkarbeit Zaehlerstand
# OBIS: 070100010801ff, 01, 01, 621e, 52ff, 5900000000010f5a0a, 01: Wirk-Energie Tarif 1 Bezug
# OBIS: 070100010802ff, 01, 01, 621e, 52ff, 590000000000000000, 01: Wirk-Energie Tarif 2 Bezug
# OBIS: 070100100700ff, 01, 01, 621b, 5200, 550000003b, 01: Momentane Wirkleistung Bezug
# OBIS: 070100240700ff, 01, 01, 621b, 5200, 5500000012, 01: Current Power L1
# OBIS: 070100380700ff, 01, 01, 621b, 5200, 5500000021, 01: Current Power L2
# OBIS: 0701004c0700ff, 01, 01, 621b, 5200, 5500000008, 01: Current Power L3

-d 0:
Unix-Zeit  Systemzeit          kWh       Watt
1599832641,2020-09-11_14:57:21,1778.4749,60
1599832645,2020-09-11_14:57:25,1778.4749,59
1599832647,2020-09-11_14:57:27,1778.4750,63
