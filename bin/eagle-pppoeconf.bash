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
function msgbox {
 # msgbox title text width
 $DIALOG --title "$1" --msgbox "\n$2\n" $((${#2}/($3-4)+7)) $3
}
function yesno {
 # yesno title text width
 $DIALOG --stdout --title "$1" --yesno "\n$2\n" $((${#2}/($3-4)+7)) $3
 echo $?
}
TITLE="Eagle ADSL Configuration"
if [ ! -d /proc/driver/eagle-usb ]; then
 msgbox "$TITLE" "Error: modem driver 'eagle-usb' not loaded" 50
 exit 4
fi
/usr/sbin/eaglectrl -s
INTERFACE=$(/usr/sbin/eaglectrl -i)
if [ -z "$INTERFACE" ]; then
 msgbox "$TITLE" "Error: no interface found" 50
 exit 5
fi
PROVIDER="$(inputbox "$TITLE" "PPPoE provider" 50 eagle)"
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
START=$(yesno "$TITLE" "Start DSL on boot?" 50)
rm -rf "/etc/ppp/peers/$PROVIDER"
cat <<EOF >"/etc/ppp/peers/$PROVIDER"
user "$USERNAME"
pty "/usr/sbin/pppoe -I $INTERFACE"
mru 1492
mtu 1492
noipdefault
defaultroute
usepeerdns
noauth
ipcp-accept-remote
ipcp-accept-local
hide-password
nobsdcomp
nodeflate
nopcomp
novj
novjccomp
noaccomp
noccp
nocrtscts
connect /bin/true
persist
EOF
chmod 640 "/etc/ppp/peers/$PROVIDER"
chown root.dip "/etc/ppp/peers/$PROVIDER"
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
#!/bin/sh
PPPD=$PPPD
/usr/sbin/eaglectrl -d
/usr/sbin/eaglectrl -s
INTERFACE=$(/usr/sbin/eaglectrl -i)
/sbin/ifconfig \$INTERFACE up
\$PPPD call "$PROVIDER"
EOF
 chmod 750 /etc/ppp/ppp_on_boot
 chown root.dip /etc/ppp/ppp_on_boot
else
 rm -f /etc/ppp/ppp_on_boot
fi
if [ ! -e /etc/debian_version ]; then
 [ -f /etc/resolv.conf ] && cp /etc/resolv.conf /etc/resolv.conf.1st
 rm -f /etc/resolv.conf
 ln -s ppp/resolv.conf /etc/resolv.conf
fi
killall pppd 2>/dev/null
/sbin/ifconfig $INTERFACE up
$PPPD call "$PROVIDER"
