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
# +I tried to use GNU 'coreutils' as much as possible.

VERSION="0.1"
DATE="27-04-2016"

# Configuration Block
HW_CONFIG="0"
HW_I2C_EN="0"
HW_SPI_EN="0"

RSZ_PART="1"

NW_CONFIG="0"
CONFIG_HSTNM="0"
CONFIG_STAT_IP="0"

ADD_USR="0"
ADD_USR_SUDO="0"

DIS_ROOT="0"
DIS_ROOT_LOCAL="0"
DIS_ROOT_SSH="0"

PKGS_INSTL="0"
#

ROOTUID="0"
CNFGSTATE="0"
CNFGSTATEMX="6"
RSPBNLASTPRTNNO="3"

ROOTPARTN="/dev/root"
ROOTPRTNNO="0"
ROOTPRTNDEV="mmcblk0"
BLOCKDEV="/dev/"$ROOTPRTNDEV

SYSCNFGDIR="/etc/"
INITDIR=$SYSCNFGDIR"init.d/"
INITDFLTDIR=$SYSCNFGDIR"defaults/"
HOSTFILE="hostname"
NWFILE="network"
CNFGDIR="/boot/setupi/"
CNFGSTATEFILE="setupi.state"
RSZPARTSCRIPT="rszprtn.sh"

# exit status
# 0: success
# ($CNFGSTATE + 1): failure @ $CNFGSTATE
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
	if [ -f $CNFGDIR$CNFGSTATEFILE ]
	then
		CNFGSTATE=`cat $CNFGDIR$CNFGSTATEFILE`
	else
		printf "$CNFGSTATE\n" > $CNFGSTATEFILE
	fi
}

exitsetup()
{
	CNFGSTATE=`expr $CNFGSTATE + 1`
	printf "$CNFGSTATE\n" > $CNFGSTATEFILE
	exit `expr $CNFGSTATE + 1`
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
	local PRTNNO="0"
	local FLAG="0"
	local FSTYPE="0"
	local STRTSEC="0"
	local ENDSEC="0"
	
	# delete swap & main/root (partition no. 3 & 2),
	# +create a new primary partition with start sec. same as earlier main/root
	# +& size is up to the end of the card. we'll use 'parted' for this.
	# assumed partition layout: boot(1), rootfs(2), swap(3) or boot(1), rootfs(2)
	
	# we need to check if it's sd/msd card or not; if it's not then
	# +it's better not to proceed further.
	# (ref. raspi-config @ https://github.com/asb/raspi-config)
	if [ -L $ROOTPARTN ]
	then
		# raspbian; /dev/root->/dev/mmcblk0p02
		DEVTYPE=`readlink $ROOTPARTN | rev | cut -d'/' -f1 | rev`
	else
		# minibian; /dev/mmcblk0p02
		DEVTYPE=`mount | grep -i 'mmc' | sort | cut -d' ' -f1 | tail -n 1 | rev | cut -d/ -f1 | rev`
	fi
	if [ "${DEVTYPE##$ROOTPRTNDEV}" != "$DEVTYPE" ]
	then
		# we need to verify assumed partition layout first. we'll proceed if
		# +rootfs is on partition 2. moving the rootfs partition/partition-start
		# +(in case if it's on 3) has it's own issues (ext4: journal etc.).
		# +'boot' is always on 1.(?)
		ROOTPRTNNO=`echo ${DEVTYPE##$ROOTPRTNDEV} | cut -dp -f2 | cut -d0 -f1`
		if [ $ROOTPRTNNO -eq "2" ]
		then
			# 1. get last partition no. (no. of total partitions)
			PRTNNO=`parted -s $BLOCKDEV unit s print -m | tail -n 1 | cut -d: -f1`
			if [ $PRTNNO -eq "2" ] || [ $PRTNNO -eq "3" ]
			then
				# 2. check whether first partition is with 'boot' flag or not
				FLAG=`parted -s $BLOCKDEV unit s print -m | head -n 3 | tail -n 1 | cut -d: -f7 | cut -d';' -f1`
				# temp. hack
				FLAG="boot"
				if [ "$FLAG" == "boot" ]
				then
					case $PRTNNO
					in
						2)
							# rootfs is on partition 2 & it's last partition
							# 'get start-sector'(rootfs)->'get end-sector'(sd/msd-card)
							STRTSEC=`parted -s $BLOCKDEV unit s print -m | head -n 4 | tail -n 1 | cut -d: -f2 | cut -ds -f1`
							ENDSEC=`parted -s $BLOCKDEV unit s print -m | head -n 2 | tail -n 1 | cut -d: -f2 | cut -ds -f1`
							ENDSEC=`expr $ENDSEC - 1`
							;;
						3)
							# partition 3, we'll proceed only if it's linux-swap; other partition type may mean custom partition layout
							FSTYPE=`parted -s $BLOCKDEV unit s print -m | head -n 5 | tail -n 1 | cut -d: -f5 | cut -d'(' -f1`
							if [ "$FSTYPE" == "linux-swap"]
							then
								# 'get start-sector'(rootfs)->'get end-sector'(sd/msd-card)->delete(swap)
								STRTSEC=`parted -s $BLOCKDEV unit s print -m | head -n 4 | tail -n 1 | cut -d: -f2 | cut -ds -f1`
								ENDSEC=`parted -s $BLOCKDEV unit s print -m | head -n 2 | tail -n 1 | cut -d: -f2 | cut -ds -f1`
								ENDSEC=`expr $ENDSEC - 1`
								parted -s $BLOCKDEV rm $PRTNNO
								PRTNNO=`expr $PRTNNO - 1`
							else
								printf "error: partition-resizing: partition 3 is not linux-swap!\n"
								exitsetup
							fi
							;;
						*)
							exitsetup
							;;
					esac
					if [ $ENDSEC -gt $STRTSEC ]
					then
						# remove partition 2; rootfs
						parted -s $BLOCKDEV rm $PRTNNO
						# create new partition 2; rootfs with same star sec. but new end sec.
						parted -s $BLOCKDEV unit s mkpart primary ext4 $STRTSEC $ENDSEC
					else
						printf "error: partition-resizing: end sector no. is less than start sector no.!\n"
						exitsetup
					fi
				else
					printf "error: partition-resizing: first partition is not boot!\n"
					exitsetup
				fi
			else
				printf "error: partition-resizing: no. of partitions is more than 3!\n"
				exitsetup
			fi
		else
			printf "error: partition-resizing: rootfs is not on partition 2!\n"
			exitsetup
		fi
	else
		printf "error: partition-resizing: it's not a sd/msd card!\n"
		exitsetup
	fi
	# schedule a run for 'resize2fs' & 'fsck' on next boot through init script(s).
	cp $CNFGDIR$RSZPARTSCRIPT $INITDIR$RSZPARTSCRIPT
	chmod +x $INITDIR$RSZPARTSCRIPT
	update-rc.d $RSZPARTSCRIPT defaults
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
count="0"
chkprvlg
chkdist
readconfigstate

if [ -f $INITDIR$RSZPARTSCRIPT ] || [ : ]
then
	update-rc.d ${RSZPARTSCRIPT%%".sh"} remove
fi

for((count=0;count<=$CNFGSTATEMX;count++));
do
	case $count
	in
		0)
			if [ $HW_CONFIG -eq "1" ]
			then
				hwconfig
			fi
			CNFGSTATE=`expr $CNFGSTATE + 1`
			printf "$CNFGSTATE\n" > $CNFGSTATEFILE
			;;
		1)
			if [ $RSZ_PART -eq "1" ]
			then
				rszprtn
			fi
			CNFGSTATE=`expr $CNFGSTATE + 1`
			printf "$CNFGSTATE\n" > $CNFGSTATEFILE
			;;
		2)
			if [ $NW_CONFIG -eq "1" ]
			then
				confignw
			fi
			CNFGSTATE=`expr $CNFGSTATE + 1`
			printf "$CNFGSTATE\n" > $CNFGSTATEFILE
			;;
		3)
			if [ $ADD_USR -eq "1" ]
			then
				addusrpi
			fi
			CNFGSTATE=`expr $CNFGSTATE + 1`
			printf "$CNFGSTATE\n" > $CNFGSTATEFILE
			;;
		4)
			if [ $ADD_USR_SUDO -eq "1" ]
			then
				addusrsudo
			fi
			CNFGSTATE=`expr $CNFGSTATE + 1`
			printf "$CNFGSTATE\n" > $CNFGSTATEFILE
			;;
		5)
			if [ $DIS_ROOT -eq "1" ]
			then
				disroot
			fi
			CNFGSTATE=`expr $CNFGSTATE + 1`
			printf "$CNFGSTATE\n" > $CNFGSTATEFILE
			;;
		6)
			if [ $PKGS_INSTL -eq "1" ]
			then
				pkgsinstl
			fi
			CNFGSTATE=`expr $CNFGSTATE + 1`
			printf "$CNFGSTATE\n" > $CNFGSTATEFILE
			;;
		*)
			printf "main(): Fatal Error! undefined state encountered!\n"
			break;
		esac
done
exit 0
