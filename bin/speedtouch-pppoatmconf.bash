#!/bin/bash
if [ $UID != 0 ]; then
 echo Error: become root before starting $0 >&2
 exit 100
fi
lsmod|egrep -q 'speedtch|speedtouch' || exit 1
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
 # menu text width [ tag "item" ] ...
 # only single word tags
 title="$1"
 text="$2"
 width="$3"
 shift 3
 $DIALOG --stdout --title "$title" --menu "$text" $((8+($#-1)/2)) $width $((($#-1)/2+1)) "$@"
}
function msgbox {
 # infobox title text width
 $DIALOG --title "$1" --msgbox "\n$2\n" 7 $3
}
function yesno {
 # yesno title text width
 $DIALOG --title "$1" --yesno "\n$2\n" 7 $3
 echo $?
}
TITLE="SpeedTouch DSL PPPoATM Configuration"
PROVIDER="$(inputbox "$TITLE" "PPPoE provider" 50 speedtouch)"
[ $? != 0 ] && exit 1
if [ "$PROVIDER" == "" ]; then
 msgbox "$TITLE" "Error: bad provider name" 50
 exit 10
fi
USERNAME="$(inputbox "$TITLE" "PPPoE username" 50)"
[ $? != 0 ] && exit 2
if [ "$USERNAME" == "" ]; then
 msgbox "$TITLE" "Error: bad username" 50
 exit 20
fi
PASSWORD="$(inputbox "$TITLE" "PPPoE password" 50)"
[ $? != 0 ] && exit 3
if [ "$PASSWORD" == "" ]; then
 msgbox "$TITLE" "Error: bad password" 50
 exit 30
fi
TYPE="$(simplemenu "$TITLE" "Country (Provider)" 55 standard Standard de_aol "Germany (AOL)" de_arcor "Germany (Arcor)" de_t-online "Germany (T-Online)" at "Austra" be "Belgium" fr "France" fr_bis "France (bis)" it "Italy"  nl "Netherlands" uk "UK" manual "Enter VPI/VCI" )"
[ $? != 0 ] && exit 4
VPI=""
VCI=""
case $TYPE in
 standard|de_arcor|be|fr|it) VPI=8;VCI=35;;
 de_aol|de_t-online) VPI=1;VCI=32;;
 fr_bis) VPI=8;VCI=67;;
 at|nl) VPI=8;VCI=48;;
 uk) VPI=0;VCI=38;;
esac
if [ "$VPI" == "" ]; then
 VPI="$(inputbox "$TITLE" "Virtual Path ID" 50)"
 [ $? != 0 ] && exit 5
fi
if [ "$VPI" == "" ]; then
 msgbox "$TITLE" "Error: bad VPI" 50
 exit 50
fi
if [ "$VCI" == "" ]; then
 VCI="$(inputbox "$TITLE" "Virtual Circuit ID" 50)"
 [ $? != 0 ] && exit 6
fi
if [ "$VCI" == "" ]; then
 msgbox "$TITLE" "Error: bad VCI" 60
 exit 60
fi
START=$(yesno "$TITLE" "Start DSL on boot?" 50)
PPOATM="$(find /usr/lib/pppd -name pppoatm.so)"
rm -rf "/etc/ppp/peers/$PROVIDER"
cat <<EOF >"/etc/ppp/peers/$PROVIDER"
# To connect to using this configuration file, do
# pppd call speedtouch

lock
defaultroute
noipdefault
usepeerdns
noauth
holdoff 4
maxfail 25
persist
asyncmap 0
lcp-echo-interval  2
lcp-echo-failure   7
user "$USERNAME"
name "$USERNAME"

plugin $PPOATM
$VPI.$VCI
EOF
for AUTH in chap pap; do
 [ -w /etc/ppp/$AUTH-secrets ] && perl -pi -e "s|^[\s]*\"$USERNAME\".*[\n]?$||" /etc/ppp/$AUTH-secrets
 cat <<EOF >>/etc/ppp/$AUTH-secrets
"$USERNAME" * "$PASSWORD"
EOF
 chmod 600 /etc/ppp/$AUTH-secrets
 chown root.root /etc/ppp/$AUTH-secrets
done
PPPD=/usr/sbin/pppd
if [ $START == 0 ]; then
 cat <<EOF >/etc/ppp/ppp_on_boot
#!/bin/bash
modprobe pppoatm
PPPD=$PPPD
\$PPPD call "$PROVIDER"
EOF
 chmod 700 /etc/ppp/ppp_on_boot
 chown root.root /etc/ppp/ppp_on_boot
else
 rm -f /etc/ppp/ppp_on_boot
fi
if [ ! -e /etc/debian_version ]; then
 [ -f /etc/resolv.conf ] && cp /etc/resolv.conf /etc/resolv.conf.1st
 rm -f /etc/resolv.conf
 ln -s ppp/resolv.conf /etc/resolv.conf
fi
killall pppd 2>/dev/null
modprobe pppoatm

CONNECT=$(yesno "$TITLE" "Connect now?" 50)
[ "$CONNECT" == "1" ] && exit 50

$PPPD call "$PROVIDER"
