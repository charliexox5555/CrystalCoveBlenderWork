#!/bin/zsh
# One Roblox Studio is shared by several Claude sessions. Take the lock before starting Play or
# making Edit-mode installs, release it when Studio is back in Edit. Slots should stay under ~15 min;
# a lock older than 20 min is treated as stale and can be taken.
#   tools/studio_lock.sh status
#   tools/studio_lock.sh acquire <session-name>   # exit 0 = yours, 1 = busy (prints holder)
#   tools/studio_lock.sh release <session-name>
#   tools/studio_lock.sh queue <session-name>     # join the waiting line (first in line gets priority)
LOCK=/private/tmp/glassclash_studio_lock
QUEUE=/private/tmp/glassclash_studio_queue
STALE=1200
FREE=/private/tmp/glassclash_studio_free_since
SKIP=240 # a queue head that doesn't take a free lock within this many seconds loses its turn
cmd=$1; who=$2
now=$(date +%s)
holder() { [[ -f $LOCK/owner ]] && cat $LOCK/owner; }
age() { [[ -f $LOCK/since ]] && echo $(( now - $(cat $LOCK/since) )) || echo 0; }
case $cmd in
status)
	if [[ -d $LOCK ]]; then echo "held by $(holder) for $(age)s"; else echo "free"; fi
	[[ -s $QUEUE ]] && echo "queue: $(tr '\n' ' ' < $QUEUE)"
	;;
queue)
	touch $QUEUE; grep -qx "$who" $QUEUE || echo "$who" >> $QUEUE
	echo "queued: $(tr '\n' ' ' < $QUEUE)"
	;;
acquire)
	[[ -z $who ]] && { echo "usage: acquire <name>"; exit 2; }
	first=$( [[ -s $QUEUE ]] && head -1 $QUEUE )
	if [[ -n $first && $first != $who && ! -d $LOCK ]]; then
		[[ -f $FREE ]] || echo $now > $FREE
		if (( now - $(cat $FREE) > SKIP )); then
			echo "$first missed its turn; moving it to the back"
			sed -i '' "1d" $QUEUE; echo "$first" >> $QUEUE; echo $now > $FREE
			first=$(head -1 $QUEUE)
		fi
	fi
	if [[ -n $first && $first != $who ]]; then echo "busy: $first is first in the queue"; exit 1; fi
	if [[ -d $LOCK && $(age) -gt $STALE ]]; then echo "taking stale lock from $(holder)"; rm -rf $LOCK; fi
	if mkdir $LOCK 2>/dev/null; then
		echo $who > $LOCK/owner; echo $now > $LOCK/since
		[[ -f $QUEUE ]] && sed -i '' "/^$who\$/d" $QUEUE
		echo "acquired by $who"
	else
		[[ $(holder) == $who ]] && { echo "already yours"; exit 0; }
		echo "busy: held by $(holder) for $(age)s"; exit 1
	fi
	;;
release)
	if [[ $(holder) == $who ]]; then rm -rf $LOCK; echo $now > $FREE; echo "released"; else echo "not held by $who ($(holder))"; fi
	;;
*) echo "usage: status | acquire <name> | release <name> | queue <name>"; exit 2 ;;
esac
