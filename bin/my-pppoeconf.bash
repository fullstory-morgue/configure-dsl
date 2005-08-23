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
 $DIALOG --title "$1" --yesno "\n$2\n" $((${#2}/($3-4)+7)) $3
 echo $?
}
TITLE="ADSL Configuration"
INTERFACE=""
list=$(ifconfig -a|grep Ethernet|awk '{print $1}')
for iface in $list; do
 ifconfig $iface up
 AC=$(pppoe -A -I $iface 2>/dev/null|grep Access-Concentrator)
 if [ $? == 0 ]; then
  AC=$(echo $AC|awk '{print $2}')
  INTERFACE=$iface
  break
fi
done
if [ -n "$INTERFACE" ]; then
 msgbox "$TITLE" "Access-Concentrator $AC found at $INTERFACE" 50
else
 msgbox "$TITLE" "Error: no Access-Concentrator found" 50
 exit 5
fi 
PROVIDER="$(inputbox "$TITLE" "PPPoE provider" 50 dsl-provider)"
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
pty "/usr/sbin/pppoe -I $INTERFACE -T 80 -m 1452"
noipdefault
defaultroute
hide-password
lcp-echo-interval 60
lcp-echo-failure 3
persist
#demand
connect /bin/true
noauth 
mtu 1492
user "$USERNAME"
usepeerdns
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
INTERFACE=$INTERFACE
/sbin/ifconfig \$INTERFACE up
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
$PPPD call "$PROVIDER"
