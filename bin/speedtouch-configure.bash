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
 # menu text width [ tag "item" ] ...
 # only single word tags
 title="$1"
 text="$2"
 width="$3"
 shift 3
 $DIALOG --stdout --title "$title" --menu "$text" $((8+($#-1)/2)) $width $((($#-1)/2+1)) "$@"
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
function fselect {
 # fselect title filepath width
 #$DIALOG --stdout --title "$1" --fselect "$2" $((${#2}/($3-4)+30)) $3
 if [ "$DIALOG" == "dialog" ]; then
  $DIALOG --stdout --title "$1" --fselect "$2" $((${#2}/($3-4)+9)) $3
 else
  $DIALOG --stdout --title "$1" --fselect "$2" $((${#2}/($3-4)+30)) $3
 fi
}
TITLE="SpeedTouch DSL Configuration"
msgbox "$TITLE" "To activate the device you need to specify the path to the firmware file. This is usually called \"alcaudsl.sys\" (Windows) or \"mgmt.o\" (Linux). You may find it in your Windows/System dir." 50
FIRMWARE=$(fselect "$TITLE" "/mnt" 50)
[ $? != 0 ] && exit 1
if ! [ -e "$FIRMWARE" ]; then
 msgbox "$TITLE" "Error: bad firmware file" 50
 exit 10
fi
if modem_run -m -f "$FIRMWARE"; then
 if [ -d /KNOPPIX ]; then
  echo KNOPPIX CD found. >&2
  umount /usr/local/lib 2>/dev/null
  SYS=/home/knoppix/system
  mkdir -p $SYS
  cp -a /KNOPPIX/usr/local/lib $SYS
  mount --bind $SYS/lib /usr/local/lib
 fi
 mkdir -p /usr/local/lib/speedtouch
 cp "$FIRMWARE" /usr/local/lib/speedtouch/firmware.bin && msgbox "$TITLE" "Firmware installed." 50
fi
