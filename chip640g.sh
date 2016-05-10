#! /bin/bash
# Initialising Carelink Automation
# Proof of concept ONLY - 640g csv to NightScout
#
echo '*****************************'
echo '***       CHIP640G       ***'
echo '*** FOR TEST PURPOSES ONLY***'
echo '*Only Use If You Accept This*'
echo '* Started 5th May 2016      *'
echo '*** Thanks - @LittleDMatt ***'
echo '*****************************'
VERSION='V0.12 10th May 2016'
echo $VERSION
echo
echo "Indebted to Lennart Goerdhart for https://github.com/pazaan/decoding-contour-next-link"
echo "Please use with caution. There'll be bugs here..."
echo "You run this at your own risk."
echo "Thank you."

echo '*****************************'
echo ' Known Issues TO (TRY TO) FIX'
echo '*****************************'
echo 'Tons - this is thrown together...'
echo '*****************************'
echo Setting Varables...
source chip_config.sh

# Capture empty JSON files later ie "[]"
EMPTYSIZE=3 #bytes
# ****************************************************************************************
# Let's go...
# ****************************************************************************************

# Uploader setup
START_TIME=0	#last time we ran the uploader (if at all)

# Check if we're probably running as cron job
uptime1=$(</proc/uptime)
uptime1=${uptime%%.*}

# Allow to run for ~240 hours (roughly), ~5 min intervals
# This thing is bound to need some TLC and don't want it running indefinitely...
COUNT=0
MAXCNT=2880
until [ $COUNT -gt $MAXCNT ]; do

python read_minimed_next24.py
sleep 10
python read_minimed_next24.py
	
# Time to extract and upload entries (SG only)
filesize=0
if [ -s latest_sg.json ] 
then 
	filesize=$(stat -c%s latest_sg.json)
fi
if [ $filesize -gt $EMPTYSIZE ]
then
	sed -i '1s/^/[{/' latest_sg.json
	echo '}]' >> latest_sg.json
	more latest_sg.json
	curl -s -X POST --header "Content-Type: application/json" --header "Accept: application/json" --header "api-secret:"$api_secret_hash --data-binary @latest_sg.json "$your_nightscout"$"/api/v1/entries"
fi
echo
# And now basal info
# filesize=$(wc -c <latest_basal.json)
filesize=0
if [ -s latest_basal.json ]
then
	filesize=$(stat -c%s latest_basal.json)
fi
if [ $filesize -gt $EMPTYSIZE ]
then
	sed -i '1s/^/[{/' latest_basal.json
	echo '}]' >> latest_basal.json
	more latest_basal.json
	curl -s -X POST --header "Content-Type: application/json" --header "Accept: application/json" --header "api-secret:"$api_secret_hash --data-binary @latest_basal.json "$your_nightscout"$"/api/v1/treatments"
fi

echo
echo "Checking for Bayer..."
lsusb > /home/chip/decoding_contour/lsusb.log
grep 'Bayer' /home/chip/decoding_contour/lsusb.log > /home/chip/decoding_contour/usb.log
# Bayer will be listed -  "Bayer Health Care LLC"
# Action (if required): reboot (ffs, got to be a better way :o )
if [ ! -s /home/chip/decoding_contour/usb.log  ] 
then 
	echo 'Announcement - USB Loss'
	echo '{"enteredBy": "Uploader", "eventType": "Announcement", "reason": "", "notes": "Cycle Bayer Power", "created_at": "'$(date +"%Y-%m-%dT%H:%M:%S.000%z")$'", " isAnnouncement": true }' > announcement.json
	curl -s -X POST --header "Content-Type: application/json" --header "Accept: application/json" --header "api-secret:"$api_secret_hash --data-binary @announcement.json "$your_nightscout"$"/api/v1/treatments"
#/sbin/shutdown -r +1
fi

################################
# Check Power status of CHIP
# Adapted from battery.sh by RzBo, Bellesserre, France
# force ADC enable for battery voltage and current
/usr/sbin/i2cset -y -f 0 0x34 0x82 0xC3

################################
#read Power status register @00h
POWER_STATUS=$(i2cget -y -f 0 0x34 0x00)
#echo $POWER_STATUS

BAT_STATUS=$(($(($POWER_STATUS&0x02))/2))  # divide by 2 is like shifting rigth 1 times
# echo $(($POWER_STATUS&0x02))
##echo "BAT_STATUS="$BAT_STATUS
# echo $BAT_STATUS

################################
#read Power OPERATING MODE register @01h
POWER_OP_MODE=$(i2cget -y -f 0 0x34 0x01)
#echo $POWER_OP_MODE

CHARG_IND=$(($(($POWER_OP_MODE&0x40))/64))  # divide by 64 is like shifting rigth 6 times
#echo $(($POWER_OP_MODE&0x40))
## echo "CHARG_IND="$CHARG_IND
# echo $CHARG_IND

BAT_EXIST=$(($(($POWER_OP_MODE&0x20))/32))  # divide by 32 is like shifting rigth 5 times
#echo $(($POWER_OP_MODE&0x20))
## echo "BAT_EXIST="$BAT_EXIST
# echo $BAT_EXIST

################################
#read Charge control register @33h
CHARGE_CTL=$(i2cget -y -f 0 0x34 0x33)
## echo "CHARGE_CTL="$CHARGE_CTL
# echo $CHARGE_CTL


################################
#read Charge control register @34h
CHARGE_CTL2=$(i2cget -y -f 0 0x34 0x34)
## echo "CHARGE_CTL2="$CHARGE_CTL2
# echo $CHARGE_CTL2


################################
#read battery voltage	79h, 78h	0 mV -> 000h,	1.1 mV/bit	FFFh -> 4.5045 V
BAT_VOLT_MSB=$(i2cget -y -f 0 0x34 0x78)
BAT_VOLT_LSB=$(i2cget -y -f 0 0x34 0x79)

#echo $BAT_VOLT_MSB $BAT_VOLT_LSB
# bash math -- converts hex to decimal so `bc` won't complain later...
# MSB is 8 bits, LSB is lower 4 bits
BAT_BIN=$(( $(($BAT_VOLT_MSB << 4)) | $(($(($BAT_VOLT_LSB & 0x0F)) )) ))

BAT_VOLT=$(echo "($BAT_BIN*1.1)"|bc)
## echo "Battery voltage = "$BAT_VOLT"mV"

###################
#read Battery Discharge Current	7Ch, 7Dh	0 mV -> 000h,	0.5 mA/bit	1FFFh -> 1800 mA
#AXP209 datasheet is wrong, discharge current is in registers 7Ch 7Dh
#13 bits
BAT_IDISCHG_MSB=$(i2cget -y -f 0 0x34 0x7C)
BAT_IDISCHG_LSB=$(i2cget -y -f 0 0x34 0x7D)

#echo $BAT_IDISCHG_MSB $BAT_IDISCHG_LSB

BAT_IDISCHG_BIN=$(( $(($BAT_IDISCHG_MSB << 5)) | $(($(($BAT_IDISCHG_LSB & 0x1F)) )) ))

BAT_IDISCHG=$(echo "($BAT_IDISCHG_BIN*0.5)"|bc)
## echo "Battery discharge current = "$BAT_IDISCHG"mA"

###################
#read Battery Charge Current	7Ah, 7Bh	0 mV -> 000h,	0.5 mA/bit	FFFh -> 1800 mA
#AXP209 datasheet is wrong, charge current is in registers 7Ah 7Bh
#(12 bits)
BAT_ICHG_MSB=$(i2cget -y -f 0 0x34 0x7A)
BAT_ICHG_LSB=$(i2cget -y -f 0 0x34 0x7B)

#echo $BAT_ICHG_MSB $BAT_ICHG_LSB

BAT_ICHG_BIN=$(( $(($BAT_ICHG_MSB << 4)) | $(($(($BAT_ICHG_LSB & 0x0F)) )) ))

BAT_ICHG=$(echo "($BAT_ICHG_BIN*0.5)"|bc)
## echo "Battery charge current = "$BAT_ICHG"mA"

###################
#read internal temperature 	5eh, 5fh	-144.7c -> 000h,	0.1c/bit	FFFh -> 264.8c
TEMP_MSB=$(i2cget -y -f 0 0x34 0x5e)
TEMP_LSB=$(i2cget -y -f 0 0x34 0x5f)

# bash math -- converts hex to decimal so `bc` won't complain later...
# MSB is 8 bits, LSB is lower 4 bits
TEMP_BIN=$(( $(($TEMP_MSB << 4)) | $(($(($TEMP_LSB & 0x0F)) )) ))

TEMP_C=$(echo "($TEMP_BIN*0.1-144.7)"|bc)
echo "Internal temperature = "$TEMP_C"c" > /home/chip/decoding_contour/temp.log

###################
#read fuel gauge B9h
BAT_GAUGE_HEX=$(i2cget -y -f 0 0x34 0xb9)

# bash math -- converts hex to decimal so `bc` won't complain later...
# MSB is 8 bits, LSB is lower 4 bits
BAT_GAUGE_DEC=$(($BAT_GAUGE_HEX))

echo "Battery gauge = "$BAT_GAUGE_DEC"%" > /home/chip/decoding_contour/battery.log

################################
# Power Action
if [ $BAT_GAUGE_DEC -le 5 ] 
then 
echo 'Low Battery' > /home/chip/decoding_contour/action.log
/sbin/shutdown
fi

# Heat Action - this is temp of AXP209 power management chip, not the battery, which rests ~5mm above it. R8 chip is on reverse of PCB.
if [ ${TEMP_C%.*} -gt 75 ] 
then 
echo 'Overheat' > /home/chip/decoding_contour/action.log
/sbin/shutdown
fi


echo "Waiting..."
sleep $gap_seconds
rm -f latest_sg.json
rm -f latest_basal.json

let COUNT=COUNT+1
echo $COUNT
done