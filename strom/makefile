#!make

# makefile for SML-Stromzaehler
# 2020-09-10: auf strawpi.local per WLAN; *CH
# 2020-08-09, Georg Fischer; VF=39

all: setty 
	# wird mit @reboot in der crontab von root aufgerufen:
	mkdir /run/sensor/
	perl /home/pi/sensor/strom/sml_read.pl 2> /run/sensor/sml_read.log &
#----
setdate:
	sudo timedatectl set-timezone Europe/Berlin
setty:
	stty -F /dev/ttyUSB0 9600 -parenb cs8 -cstopb -ixoff -crtscts -hupcl -ixon -opost -onlcr -isig -icanon -iexten -echo -echoe -echoctl -echoke
iskdump:
	cat /dev/ttyUSB0 | hexdump  -e ' 16/1 "%02x" "\n"' | tee isk2.dmp
smlalign:
	hexdump -e ' 16/1 "%02x" "\n"' cat /dev/ttyUSB0 | perl sml_align.pl | tee isk.align.dmp
smldecode:
	hexdump  -e ' 16/1 "%02x" "\n"' /dev/ttyUSB0 \
	| perl sml_align.pl | perl decode_sml_tty.pl \
	| tee isk.decode.txt
smlcomp: # compressed
	hexdump  -e ' 16/1 "%02x" "\n"' /dev/ttyUSB0  \
	| perl sml_align.pl | perl decode_sml_tty.pl -c 1 \
	| tee isk.comp.txt
smldaten: # compressed
	hexdump  -e ' 16/1 "%02x" "\n"' /dev/ttyUSB0  \
	| perl sml_align.pl | perl decode_sml_tty.pl -c 0
testd:
	perl decode_sml_tty.pl -d 1 -c 1 decode_sml_tty.pl | tee $@.tmp
test:
	perl decode_sml_tty.pl -d 0 -c 1 decode_sml_tty.pl | tee $@.tmp
backup:
	zip sensor.`date +%Y-%m-%d.%H.%M`.zip makefile *.pl *.conf* *.txt
