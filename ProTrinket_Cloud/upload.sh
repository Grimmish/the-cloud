#!/bin/bash
###########################################################
##
##  Ben's all-singing, all-dancing Arduino build robot
##
###########################################################

###########################################
# Config (see below for more explanation)

PROJECTNAME=ProTrinket_Cloud
DEVPATH=/dev/ttyACM0
BOARDNAME=adafruit:avr:protrinket5

SKETCHBOOKPATH=/home/u00670/Arduino
ARDUINO_IDE_PATH=/home/u00670/funstuff/arduino-1.6.8
# End config (don't modify anything below)
###########################################

##
## HOW TO USE
##

##
## PREREQUISITES
##
# * An Arduino IDE installed somewhere (specify ARDUINO_IDE_PATH, above)
#
# * Hardware support for your MCU. Fire up the GUI and use
#   Tools>>Boards>>Boards Manager to download drivers for more hardware.
#     Run this to get a list of boards that the ./arduino CLI will accept (note
#     the usage of ARDUINO_IDE_PATH in this script):
#       perl -pe 'if (/packages/) { s/^.*\/packages\/(\w+)\/hardware\/(\w+)\/.*boards\.txt:(\w+)\.name=/$1.$2.$3: /} else { s/^.*\/hardware\/(\w+)\/(\w+)\/boards\.txt:(\w+)\.name=/$1.$2.$3: /}' <(fgrep '.name=' `find $ARDUINO_IDE_PATH ~/.arduino15 -name boards.txt`)
#
# * Read/write access to the device file that appears in /dev when the
#   MCU enters flash mode
#
# * Folder structure for your projects as follows:
#         $SKETCHBOOKPATH/
#                libraries/
#                   libX/
#                   libY/
#                $PROJECTNAME/
#                   $PROJECTNAME.ino
#                   build.sh (this file)
#

# Bash color modifiers (NC=="no color")
C_CY="\033[0;36m"
C_RE="\033[1;31m"
C_GR="\033[1;32m"
C_YE="\033[1;33m"
C_BL="\033[1;36m"
C_NC="\033[0m"

WIDE=40

function setupenv() {
  printf "Validating options and env ..."

  CACHEDIR=/tmp/arduino-build/$PROJECTNAME
  mkdir -p $CACHEDIR

  BOARDDEF=`find $ARDUINO_IDE_PATH ~/.arduino15 -name boards.txt -exec egrep -l "^${BOARDNAME##*:}\." {} \;`
  if [[ $BOARDDEF == "" ]]; then
    printf "[ ${C_RE}FAILED${C_NC} ]\n"
    printf "\nERROR: No local hardware definition for your board specification\n"
    printf "       ($BOARDNAME). Double-check your \$BOARDNAME or use the\n"
    printf "       Arduino IDE to download more drivers.\n"
    exit 1
  fi

  # Throw the "-o" option to grep so it only grabs the pattern match
  # and not the DOS-style CR at the end of the line
  AVRDUDE_CONF=$ARDUINO_IDE_PATH/hardware/tools/avr/etc/avrdude.conf
  AVRDUDE_PARTNO=`egrep -o "^${BOARDNAME##*:}.build.mcu=\S+" $BOARDDEF | cut -d= -f2`
  AVRDUDE_PROGRAMMER=`egrep -o "^${BOARDNAME##*:}.upload.protocol=\S+" $BOARDDEF | cut -d= -f2`
  AVRDUDE_SPEED=`egrep -o "^${BOARDNAME##*:}.upload.speed=\S+" $BOARDDEF | cut -d= -f2`
  AUTO_BOOTLOADER_RESET=`egrep -o "^${BOARDNAME##*:}.upload.use_1200bps_touch=\S+" $BOARDDEF | cut -d= -f2`

  printf "[   ${C_GR}OK${C_NC}   ]\n"
}

function build() {
  printf "Compiling ${C_CY}${PROJECTNAME}${C_NC} ..."
  $ARDUINO_IDE_PATH/arduino \
      --verify \
      --board $BOARDNAME \
      --port $DEVPATH \
      --preserve-temp-files \
      --pref build.path=$CACHEDIR \
      --pref sketchbook.path=$SKETCHBOOKPATH \
      --pref preproc.save_build_files=false \
      $SKETCHBOOKPATH/$PROJECTNAME/$PROJECTNAME.ino \
      1>$CACHEDIR/build.stdout 2>$CACHEDIR/build.stderr
  RESULT=$?

  if [ $RESULT -eq 0 ]; then
    printf "[   ${C_GR}OK${C_NC}   ]\n"
  else
    printf "[ ${C_RE}FAILED${C_NC} ]\n"
    printf "\nLog:\n"
    cat $CACHEDIR/build.stderr
    exit $RESULT
  fi
}

function activate_bootloader() {
  if [[ $AUTO_BOOTLOADER_RESET == "true" ]]; then
    printf "Activating bootloader ... "
    stty -F $DEVPATH speed 1200 hupcl 1>/dev/null
    sleep 2
    if [ -w $DEVPATH ]; then
      printf "[   ${C_GR}OK${C_NC}   ]\n"
    else
      printf "[ ${C_RE}FAILED${C_NC} ]\n"
      printf "\nERROR: Device $DEVPATH is not writeable (present?)\n"
      exit 1
    fi
  else
    printf "${C_YE}Activate bootloader now!${C_NC} ... "
    sleep 4
    #if [ -w $DEVPATH ]; then
    #  printf "[   ${C_GR}OK${C_NC}   ]\n"
    #else
    #  printf "[ ${C_RE}FAILED${C_NC} ]\n"
    #  printf "\nERROR: Device $DEVPATH is not ready\n"
    #  exit 1
    #fi
  fi
}

function avrdude_write() {
  printf "Flashing chip ... "

  $ARDUINO_IDE_PATH/hardware/tools/avr/bin/avrdude \
    -C $AVRDUDE_CONF \
    -v \
    -p $AVRDUDE_PARTNO \
    -b $AVRDUDE_SPEED \
    -cusbtiny \
    -D \
    -U flash:w:${CACHEDIR}/${PROJECTNAME}.ino.hex:i \
    -l ${CACHEDIR}/avrdude.log
  RESULT=$?

  if [ $RESULT -eq 0 ]; then
    printf "[   ${C_GR}OK${C_NC}   ]\n"
  else
    printf "[ ${C_RE}FAILED${C_NC} ]\n"
    printf "\nLog:\n"
    cat $CACHEDIR/avrdude.log
    exit $RESULT
  fi
}

#FIXME: Things this script should do:
# > Run ./arduino CLI with "--verify" option to compile
# > Parse all options in boards.txt into env vars (including whether to bump the device into upload mode)
# > Run 'stty hupcl' to initialize bootloader (if needed)
# > Run avrdude with proper board options

setupenv
build
activate_bootloader
avrdude_write

printf "\n  ===> ${C_BL}All good!${C_NC} <===\n"
