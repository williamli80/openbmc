#!/bin/sh

echo shutdown: "$@"

export PS1=shutdown-sh#\ 
# exec bin/sh

cd /
if [ ! -e /proc/mounts ]
then
	mkdir -p /proc
	mount  proc /proc -tproc
	umount_proc=1
else
	umount_proc=
fi

# Remove an empty oldroot, that means we are not invoked from systemd-shutdown
rmdir /oldroot 2>/dev/null

# Move /oldroot/run to /mnt in case it has the underlying rofs loop mounted.
# Ordered before /oldroot the overlay is unmounted before the loop mount
mkdir -p /mnt
mount --move /oldroot/run /mnt

set -x
for f in $( awk '/oldroot|mnt/ { print $2 }' < /proc/mounts | sort -r )
do
	umount $f
done
set +x

image=/run/initramfs/image-
if test -s /run/fw_env -a -c /run/mtd:u-boot-env -a ! -e ${image}u-boot-env &&
	! cmp /run/mtd:u-boot-env /run/fw_env
then
	ln -sn /run/fw_env ${image}u-boot-env
fi

if test -x /update && ls $image* > /dev/null 2>&1
then
	/update ${1+"$@"}
fi

echo Remaining mounts:
cat /proc/mounts

test "umount_proc" && umount /proc && rmdir /proc

# ioctl(TIOC_DRAIN) to drain tty messages to console
test -t 1 && stty cooked 0<&1

# Execute the command systemd told us to ...
if test -d /oldroot  && test "$1"
then
	if test "$1" == kexec
	then
		$1 -f -e
	else
		$1 -f
	fi
fi


echo "Execute ${1-reboot} -f if all unounted ok, or exec /init"

export PS1=shutdown-sh#\ 
exec /bin/sh
