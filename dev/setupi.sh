#!/bin/bash

# File: ./setupi.sh
# Author: Shuvo Dutta
# Required By (File(s)): NIL
# External File(s): NIL
# Copyright: GNU/GPL
# Creation Date: 21-04-2016
# Last Modification: $DATE
# Baseline: NIL
# This script will automatically set-up/configure newly installed minibian/raspbian on raspberry pi, meant for 'server installations'.

VERSION="0.1"
DATE="25-04-2016"

# Configuration Block
HW_CONFIG="1"
HW_I2C_EN="1"
HW_SPI_EN="0"

RSZ_PART="1"

NW_CONFIG="1"
CONFIG_HSTNM="1"
CONFIG_STAT_IP="1"

ADD_USR="1"
ADD_USR_SUDO="1"

DIS_ROOT="1"
DIS_ROOT_LOCAL="1"
DIS_ROOT_SSH="1"

PKGS_INSTL="1"
#

CONFIG_STATE="0"
CONFIG_STATE_MAX="6"
RSPBN_LAST_PRTN_NO="3"

BLOCKDEV="/dev/mmcblk0"

SYS_CONFIG_DIR="/etc/"
HOST_FILE="hostname"
NW_FILE="network"
CONFIG_DIR="/boot/"
FILE_CONFIG_STATE="setupi.state"

# exit status
# 0: success
# ($CONFIG_STATE + 1): failure @ $CONFIG_STATE
# 127: no root priviledge

chkprvlg()
{
	if [ `id -u` -ne $ROOTUID ]
	then
		printf "This Script needs root priviledge to execute...\n"
		exit 127
	fi
}

chkdist()
{
	:
}

readconfigstate()
{
	if [ -f $CONFIG_DIR$FILE_CONFIG_STATE ]
	then
		CONFIG_STATE=`$CATBIN $CONFIG_DIR$FILE_CONFIG_STATE`
	else
		printf "$CONFIG_STATE\n" > $FILE_CONFIG_STATE
	fi
}

exitsetup()
{
	CONFIG_STATE=`$EXPRBIN $CONFIG_STATE + 1`
	printf "$CONFIG_STATE\n" > $FILE_CONFIG_STATE
	exit `expr $CONFIG_STATE + 1`
}

hwconfig()
{
	if [ $HW_I2C_EN -eq "1" ]
	then
		:
	fi
	if [ $HW_SPI_EN -eq "1"]
	then
		:
	fi
}

rszprtn()
{
	local DEVTYPE="0"
	local PRTN_NO="0"
	local FLAG="0"
	local FSTYPE="0"
	local STRTSEC="0"
	local ENDSEC="0"
	
	# delete swap & main/root (partition no. 3 & 2),
	# +create a new primary partition with start sec. same as earlier main/root
	# +& size is up to the end of the card. we'll use 'parted' for this.
	# assumed partition layout: boot(1), rootfs(2), swap(3)
	
	# we need to check if it's sd/msd card or not; if it's not then
	# +it's better not to proceed further.
	# (ref. raspi-config @ https://github.com/asb/raspi-config)
	# i'm using 'mmc' prefix returned by 'parted print'; correctness of
	# +which has to be checked.
	DEVTYPE=`ls -l /dev/root | cut -d'>' -f2 | tr -d [:blank:]`
	
	# we need to verify assumed partition layout first
	# 1. get last partition no. (no. of total partitions)
	PRTN_NO=`parted -s $BLOCKDEV unit s print -m | tail -n 1 | cut -d: -f1`
	if [ $PRTN_NO -eq $RSPBN_LAST_PRTN_NO ]
	then
		# 2. check whether first partition is with 'boot' flag or not
		FLAG=`parted -s $BLOCKDEV unit s print -m | head -n 3 | tail -n 1 | cut -d: -f7 | cut -d';' -f1`
		if [  "$FLAG" == "boot"]
		then
			# 3. check whether last partition is 'swap' or not
			FSTYPE=`parted -s $BLOCKDEV unit s print -m | head -n 5 | tail -n 1 | cut -d: -f5 | cut -d'(' -f1`
			if [ "$FSTYPE" == "linux-swap"]
			then
				# 'get start-sector(rootfs)->delete(swap, rootfs)->create(new rootfs)
				STRTSEC=`parted -s $BLOCKDEV unit s print -m | head -n 4 | tail -n 1 | cut -d: -f2 | cut -ds -f1`
				ENDSEC=`parted -s $BLOCKDEV unit s print -m | head -n 2 | tail -n 1 | cut -d: -f2 | cut -ds -f1`
				ENDSEC=`expr $ENDSEC - 1`
				if [ $ENDSEC -gt $STRTSEC ]
				then
					:
				else
					exitsetup
				fi
			else
				exitsetup
			fi
		else
			exitsetup
		fi
	else
		exitsetup
	fi
	# schedule a run for 'resize2fs' & 'fsck' on next boot through init script(s).
	:
}

confignw()
{
	if [ $CONFIG_HSTNM -eq "1" ]
	then
		:
	fi
	if [ $CONFIG_STAT_IP -eq "1" ]
	then
		:
	fi
}

addusrpi()
{
	:
}

addusrsudo()
{
	:
}

disroot()
{
	if [ $DIS_ROOT_LOCAL -eq "1" ]
	then
		:
	fi
	if [ $DIS_ROOT_SSH -eq "1" ]
	then
		:
	fi
}

pkgsinstl()
{
	:
}

# main
local count="0"
chkprvlg
chkdist
readconfigstate

for((count=$CONFIG_STATE;count<=$CONFIG_STATE_MAX;count++));
do
	case $count
	in
		0)
			if [ $HW_CONFIG -eq "1" ]
			then
				hwconfig
			fi
			CONFIG_STATE=`$EXPRBIN $CONFIG_STATE + 1`
			printf "$CONFIG_STATE\n" > $FILE_CONFIG_STATE
			;;
		1)
			if [ $RSZ_PART -eq "1" ]
			then
				rszprtn
			fi
			CONFIG_STATE=`$EXPRBIN $CONFIG_STATE + 1`
			printf "$CONFIG_STATE\n" > $FILE_CONFIG_STATE
			;;
		2)
			if [ $CONFIG_NW -eq "1" ]
			then
				confignw
			fi
			CONFIG_STATE=`$EXPRBIN $CONFIG_STATE + 1`
			printf "$CONFIG_STATE\n" > $FILE_CONFIG_STATE
			;;
		3)
			if [ $ADD_USR -eq "1" ]
			then
				addusrpi
			fi
			CONFIG_STATE=`$EXPRBIN $CONFIG_STATE + 1`
			printf "$CONFIG_STATE\n" > $FILE_CONFIG_STATE
			;;
		4)
			if [ $ADD_USR_SUDO -eq "1" ]
			then
				addusrsudo
			fi
			CONFIG_STATE=`$EXPRBIN $CONFIG_STATE + 1`
			printf "$CONFIG_STATE\n" > $FILE_CONFIG_STATE
			;;
		5)
			if [ $DIS_ROOT -eq "1" ]
			then
				disroot
			fi
			CONFIG_STATE=`$EXPRBIN $CONFIG_STATE + 1`
			printf "$CONFIG_STATE\n" > $FILE_CONFIG_STATE
			;;
		6)
			if [ $PKGS_INSTL -eq "1" ]
			then
				pkgsinstl
			fi
			CONFIG_STATE=`$EXPRBIN $CONFIG_STATE + 1`
			printf "$CONFIG_STATE\n" > $FILE_CONFIG_STATE
			;;
		*)
			printf "main(): Fatal Error! undefined state encountered!\n"
			break;
		esac
done
exit 0
