#!/bin/bash
if [ $UID != 0 ]; then
 echo Error: become root before starting $0 >&2
 exit 100
fi
XDIALOG_HIGH_DIALOG_COMPAT=1
export XDIALOG_HIGH_DIALOG_COMPAT
LANG=C
export LANG
DIALOG=dialog
[ -n "$DISPLAY" ] && [ -x /usr/bin/Xdialog ] && DIALOG="Xdialog"
function inputbox {
 # inputbox title text width [init]
 $DIALOG --stdout --title "$1" --inputbox "\n$2\n\n" 10 $3 "$4"
}
function simplemenu {
 # menu text width [ tag item ] ...
 # only single word tags and items
 title="$1"
 text="$2"
 width="$3"
 shift 3
 $DIALOG --stdout --title "$title" --menu "$text" $((8+($#-1)/2)) $width $((($#-1)/2+1)) $*
}
function msgbox {
 # msgbox title text width
 $DIALOG --title "$1" --msgbox "\n$2\n" $((${#2}/($3-4)+7)) $3
}
function yesno {
 # yesno title text width
 $DIALOG --title "$1" --yesno "\n$2\n" $((${#2}/($3-4)+7)) $3
 echo $?
}
TITLE="PPP Configuration for Modem"
PROVIDER="$(inputbox "$TITLE" "Provider" 55 provider)"
[ $? != 0 ] && exit 1
if [ "$PROVIDER" == "" ]; then
 msgbox "$TITLE" "Error: bad provider name" 55
 exit 10
fi
NUMBER="$(inputbox "$TITLE" "Number" 55)"
[ $? != 0 ] && exit 2
if [ "$NUMBER" == "" ]; then
 msgbox "$TITLE" "Error: bad number" 55
 exit 20
fi
USERNAME="$(inputbox "$TITLE" "Username" 55)"
[ $? != 0 ] && exit 3
if [ "$USERNAME" == "" ]; then
 msgbox "$TITLE" "Error: bad username" 55
 exit 30
fi
PASSWORD="$(inputbox "$TITLE" "Password" 55)"
[ $? != 0 ] && exit 4
if [ "$PASSWORD" == "" ]; then
 msgbox "$TITLE" "Error: bad password" 55
 exit 40
fi
DEVICE="$(inputbox "$TITLE" "Device" 55 "/dev/ttyS0")"
[ $? != 0 ] && exit 5
if [ "$DEVICE" == "" ]; then
 msgbox "$TITLE" "Error: bad device" 55
 exit 50
fi
rm -rf "/etc/ppp/peers/$PROVIDER"
cat <<EOF >"/etc/ppp/peers/$PROVIDER"
# This optionfile was generated by pppconfig 2.1.
#
#
hide-password
noauth
connect "/usr/sbin/chat -v -f /etc/chatscripts/$PROVIDER"
debug
$DEVICE
115200
defaultroute
noipdefault
user "$USERNAME"
remotename "$PROVIDER"
ipparam "$PROVIDER"

usepeerdns
EOF
chmod 640 "/etc/ppp/peers/$PROVIDER"
chown root.dip "/etc/ppp/peers/$PROVIDER"
rm -rf "/etc/chatscripts/$PROVIDER"
mkdir -p /etc/chatscripts
cat <<EOF >"/etc/chatscripts/$PROVIDER"
# This chatfile was generated by pppconfig 2.1.
# Please do not delete any of the comments.  Pppconfig needs them.
#
# ispauth PAP
# abortstring
ABORT BUSY ABORT 'NO CARRIER' ABORT VOICE ABORT 'NO DIALTONE' ABORT 'NO DIAL TONE' ABORT 'NO ANSWER' ABORT DELAYED
# modeminit
'' ATZ
# ispnumber
OK-AT-OK ATDT$NUMBER
# ispconnect
CONNECT \d\c
# prelogin

# ispname
# isppassword
# postlogin

# end of pppconfig stuff
EOF
chmod 640 "/etc/chatscripts/$PROVIDER"
chown root.dip "/etc/chatscripts/$PROVIDER"
for AUTH in chap pap; do
 [ -w /etc/ppp/$AUTH-secrets ] && perl -pi -e "s|^[\s]*\"$USERNAME\".*[\n]?$||" /etc/ppp/$AUTH-secrets
 cat <<EOF >>/etc/ppp/$AUTH-secrets
"$USERNAME" * "$PASSWORD"
EOF
 chmod 600 /etc/ppp/$AUTH-secrets
 chown root.root /etc/ppp/$AUTH-secrets
done
PPPD=/usr/sbin/pppd
if [ ! -e /etc/debian_version ]; then
 [ -f /etc/resolv.conf ] && cp /etc/resolv.conf /etc/resolv.conf.1st
 rm -f /etc/resolv.conf
 ln -s ppp/resolv.conf /etc/resolv.conf
fi
killall pppd 2>/dev/null
$PPPD call "$PROVIDER"
