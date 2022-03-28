#!perl

# Decode Stromzaehler Smart Meter Language (SML)
# @(#) $Id$
# 2022-03-28: detaillierter; WK=75
# 2020-09-10: ASN.1-Fehler
# 2020-08-09: seriell lesen von /dev/ttyUSB auf dem Raspi
# 2020-08-01, Georg Fischer: copied from prep_dex.pl 
#
#:# Usage:
#:#   perl decode_sml_tty.pl [-d debug] [-c {0|1}]  > outfile
#:#        -c 1  compressed format
#
# Cf.
# https://www.schatenseite.de/?s=SML&submit=Suchen
#--------------------------------------------------------
use strict;
use integer;
use warnings;
$| = 1; # flush output always

my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime (time);
my $timestamp = sprintf ("%04d-%02d-%02d %02d:%02d:%02d", $year + 1900, $mon + 1, $mday, $hour, $min, $sec);
$timestamp = sprintf ("%04d-%02d-%02d", $year + 1900, $mon + 1, $mday);
my %obis = # from http://blog.bubux.de/raspberry-pi-ehz-auslesen/
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
    ,   '0100010800FF', 'Wirkarbeit Bezug Total Zaehlerstand'
    ,   '0100000009FF', 'Geraeteeinzelidentifikation'
    ,   '00006001FFFF', 'Fabriknummer'
    ,   '0100240700FF', 'Current Power L1'
    ,   '0100380700FF', 'Current Power L2'
    ,   '01004C0700FF', 'Current Power L3'
    );
#  private $obis_arr = array(
#         '0100000000FF' => array('1-0:0.0.0*255','Seriennummer'),
#         '0100010700FF' => array('1-0:1.7.0*255','Momentane Wirkleistung Bezug'),
#         '0100020700FF' => array('1-0:2.7.0*255','Momentane Wirkleistung Lieferung'),
#         '0100010801FF' => array('1-0:1.8.1*255','Wirk-Energie Tarif 1 Bezug'),
#         '0100020801FF' => array('1-0:2.8.1*255','Wirk-Energie Tarif 1 Lieferung'),
#         '0100010802FF' => array('1-0:1.8.2*255','Wirk-Energie Tarif 2 Bezug'),
#         '0100020802FF' => array('1-0:2.8.2*255','Wirk-Energie Tarif 2 Lieferung'),
#         '0100010803FF' => array('1-0:1.8.3*255','Wirk-Energie Tarif 3 Bezug'),
#         '0100020803FF' => array('1-0:2.8.3*255','Wirk-Energie Tarif 3 Lieferung'),
#         '8181C78203FF' => array('129-129:199.130.3*255','Hersteller-ID '),
#         '8181C78205FF' => array('129-129:199.130.5*255','Public-Key'),
#         '01000F0700FF' => array('1-0:15.7.0*255','Active Power'),
#         '0100010800FF' => array('1-0:1.8.0*255','Wirkarbeit Bezug Total: Zaehlerstand'),
#         '0100000009FF' => array('1-0:0.0.9*255',' Geraeteeinzelidentifikation'),
#         '00006001FFFF' => array('0-0:60.1.255*255','Fabriknummer'),
#     );

my $debug = 0;
if (scalar(@ARGV) < 0) {
    print `grep -E "^#:#" $0 | cut -b3-`;
    exit;
}
my $compressed = 0;
while (scalar(@ARGV) > 0 and ($ARGV[0] =~ m{\A[\-\+]})) {
    my $opt = shift(@ARGV);
    if (0) {
    } elsif ($opt   =~ m{c}) {
        $compressed = shift(@ARGV);
    } elsif ($opt   =~ m{d}) {
        $debug      = shift(@ARGV);
    } else {
        die "invalid option \"$opt\"\n";
    }
} # while $opt

my $line;
my @stack = ();
my $indent = "  ";
my $ind = 0;
my $level = 0;
my ($byte, $nib, $len);
my $postfix;
my $buffer;
my $state = 0;

while (<>) {
    s/\s+\Z//; # chompr
    $line = $_;
    if ($line =~ m{\A1b1b1b1b}i) {
        $line = uc(substr($line, 16));
        $line =~ s{1b1b1b1b.*}{}i; # remove transfer protocol headers
        if ($debug >= 2) { print "decoding " . substr($line, 0, 32) . " ...\n"; }
        &decode();
    } # 1B1B1B1B
} # while <>
#----------------
sub decode {
    if ($compressed == 0 or $debug >= 1) {
        print "#----------------\n";
    }
    $buffer = "";
    $level = 0;
    $stack[0] = 0;
    $ind = 0;
    $state = 0;
    while ($ind < length($line)) {
        $byte = substr($line, $ind, 2); 
        $nib  = hex(substr($line, $ind    , 1));
        $len  = hex(substr($line, $ind + 1, 1));
        if ($debug >= 2) { 
            print "{$nib,$len}"; 
        }
        if (0) {
        } elsif ($nib == 0) { # octet string
            if ($len == 0) {
                $level = 0;
                &dump($byte, $len, "end of message");
                $len = 1;
            } else {
                $postfix = "";
                if ($level == 5) {
                    if (0) {
                    } elsif ($len == 7) {
                        $postfix = &interprete($byte, $len);
                    } elsif ($len == 4) {
                        $postfix = &ascii($byte, $len);
                    }
                }
                &dump($byte, $len, $postfix);
            }
        } elsif ($nib == 5) { # signed value
            &dump($byte, $len, hex(substr($line, $ind + 2, 2 * $len - 2)));
        } elsif ($nib == 6) { # unsigned integer
            &dump($byte, $len, hex(substr($line, $ind + 2, 2 * $len - 2)));
        } elsif ($nib == 7) { # list
            &dump($byte, $len, " group"); # of $count";
            my $count = $len;
            $stack[$level] = $count + 1; # save count
            if ($debug >= 2) { 
                print "# stack[$level] = $len, push\n"; 
            }
            $level ++; # push
            $len = 1;
        } elsif ($nib == 8) { # long octet string, next byte is added to length
            $len = ($len << 4) + hex(substr($line, $ind + 2, 2)); 
            &dump($byte, $len, "");
        } else {
            print "# ** unknown ASN.1 nibble $nib before position $ind\n";
        }
        if ($level >= 1) {
            $stack[$level - 1] --; # decrease count
            if ($stack[$level - 1] == 0) { # pop
                $level --;
                if ($debug >= 2) { 
                    print "# pop to stack[$level] = $stack[$level]\n"; 
                }
            }
        } # level >= 1
        $ind += 2 * $len;
    } # while $ind
    if ($compressed == 0 or $debug >= 1) {
        print "\n";
    }
} # decode
#----
sub dump {
    my ($byte, $flen, $postfix) = @_;
    my $code  = uc(substr($line, $ind, 2));
    my $field = uc(substr($line, $ind + 2, 2 * $flen - 2));
    if ($debug >= 1) {
        print "# dump level=$level, code=\"$code\", field=\"$field\"\n";
    }
    if ($compressed > 0) {
        if (0) {
        } elsif ($level == 5 and $code eq "07" and $field eq "0100010800FF" and $state == 0) {
            #           07 0100010800ff
            $buffer  = "Zaehlerstand";
            $state = 1;
            if ($debug >= 1) { print "# hit: $state $code $field $buffer\n"; }
        } elsif ($level == 5 and $code eq "59" and $state == 1) {
            #           59 0000000000f51dfb = 16063995
            $buffer .= "=$postfix; ";
            $state = 2;
            if ($debug >= 1) { print "# hit: $state $code $field $buffer\n"; }
        } elsif ($level == 5 and $code eq "07" and $field eq "0100100700FF" and $state == 2) {
            #           07 0100100700ff
            $buffer .= "akt.Leistung";
            $state = 3;
            if ($debug >= 1) { print "# hit: $state $code $field $buffer\n"; }
        } elsif ($level == 5 and $code eq "55" and $state == 3) {
            #           55 000000cc = 204
            print "$buffer=$postfix;\n";
            if ($debug >= 1) { print "# hit: $state $code $field $buffer\n"; }
            $buffer = "";
            $state = 0;
        } else {
        }
    } else {
    }
    if ($compressed == 0 or $debug >= 1) {
        print "" . ($indent x $level) . "$code $field = $postfix\n";
    }
} # dump
#----
sub ascii {
    my ($byte, $flen) = @_;
    my $result = " = \"";
    for (my $ias = 1; $ias < $flen; $ias ++) {
        $result .= chr(hex(substr($line, $ind + $ias * 2, 2)));
    }
    $result .= "\"";
    return $result;
} # ascii
#----
sub interprete {
    my ($byte, $flen) = @_;
    my $entry = substr($line, $ind + 2, 2 * $flen - 2);
    my $result = "";
    if (defined($obis{$entry})) {
        $result .= " : $obis{$entry}";
    }
    return $result;
} # interprete
#----------------
__DATA__
# 1B1B1B1B Start Escape
# 01010101 Start Übertragung Version 1
# 76
#   05 01 D5 6A C8 
#   62 00 
#   62 00 
#   72
#      63 01 01 
#      76 
#         01 
#         01 
#         05 00 9C 78 EE 0B
#         09 01 49 53 nn 00 mm pp qq rr = MAC, Server-Id, steht auf dem Zähler
#         01
#         01
#   63 11 D8 = CRC
# 00 = End of SML
# ----
# 76
#   05 01 D5 6A C9 = transactionId
#   62 00
#   62 00
#   72 
#      63 07 01 = getOpenResponse
#      77 
#         01 
#         0B 09 01 49 53 nn 00 mm pp qq rr = Server Id
#         07 01 00 62 0A FF FF 
#         72 
#            62 01 
#            65 01 E2 86 5F 
#            7A 
#            77 
#               07 81 81 C7 82 03 FF 
#               01
#               01
#               01
#               01
#               04 49 53 4B = HerstellerId, "ISK"
#               01
#            77 
#               07 01 00 00 00 09 FF
#               01
#               01
#               01
#               01
#               0B 09 01 49 53 nn 00 mm pp qq rr = serverId 
#               01 
#            77 
#               07 01 00 01 08 00 FF 
#               65 00 00 01 82 
#               01
#               62 1E 
#               52 FF 
#               59 00 00000000F3C3E401 = Gesamtverbrauch 4089701377
#            77
#               07 01 00 01 08 01 FF
#               01
#               01
#               62 1E
#               52 FF590000000000F3C3E401
#            77
#               07 01 00 01 08 02 FF 
#               01 
#               01
#               62 1E
#               52 FF
#               59 000000000000000001
#            77
#               07 01 00 10 07 00 FF
#               01
#               01
#               62 1B 
#               52 00 
#               55 0000006001 = 24577
#            77
#               07 01 00 24 07 00 FF
#               01
#               01
#               62 1B
#               52 00
#               55 0000001A01 = 6657
#            77
#               07 01 00 38 07 00 FF 
#               01
#               01
#               62 1B
#               52 00
#               55 0000001101 = 4353
#            77
#               07 01 00 4C 07 00 FF 
#               01
#               01
#               62 1B
#               52 00
#               55 0000003401
#            77
#               07 81 81 C7 82 05 FF
#               01
#               01
#               01
#               01 
#               83public...key1F62
#               01
#               01
#               01
#   63 43 67 = CRC
# 00
# ----
# 76
#    0501D56ACA
#    6200
#    6200
#    72
#       6302
#       01
#    71 01 
#    63 DA B6 
# 00 

Zaehlerstand=16068617; akt.Leistung=1949;
Zaehlerstand=16068623; akt.Leistung=1948;
Zaehlerstand=16068629; akt.Leistung=1961;
Zaehlerstand=16068635; akt.Leistung=1957;
