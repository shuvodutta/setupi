### BEGIN INIT INFO
# Provides:			partition resizing & checking on raspbian
# Required-Start:	$local_fs $syslog
# Required-Stop:	$local_fs $syslog
# Default-Start:	2 3 4 5
# Default-Stop:		0 1 6
# Short-Description:	will resize & check rootfs on raspbian, it's one shot operation.
# Description:		this will be put by setupi.sh for partition resizing, it'll self-destruct once the operation(s) are done.
### END INIT INFO

# no log function yet.

ROOTPRTN="/dev/root"
RSZPARTSCRIPT="rszprtn.sh"

EXITVAL="0"

case $1
in
	start)
			if [ -L $ROOTPRTN ]
			then
				# live resizing!
				resize2fs $ROOTPRTN
				# check return status
				:
				# check filesystem for error; live!
				fsck -f $ROOTPRTN
				# check return status
				:
				# remove this script from init.d
				update-rc.d ${RSZPARTSCRIPT%%".sh"} remove
				# check return status
				:
				EXITVAL="0"
				reboot
			else
				"rszprtn.sh: error: $ROOTPRTN does not exist!\n"
				EXITVAL="1"
			fi
			;;
	stop)
			printf "usage: $0 start\n"
			EXITVAL="2"
			;;
	restart)
			printf "usage: $0 start\n"
			EXITVAL="2"
			;;
	force-reload)
			printf "usage: $0 start\n"
			EXITVAL="2"
			;;
	status)
			printf "usage: $0 start\n"
			EXITVAL="2"
			;;
	*)
			printf "usage: $0 start\n"
			EXITVAL="2"
			;;
esac

exit $EXITVAL
