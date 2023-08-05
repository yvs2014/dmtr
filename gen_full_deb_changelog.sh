:

set -e
LANG=C

NAME='dmtr'
BACKUP=yes
DISTS='lunar mantic'
META='urgency=low'
CHANGELOG='debian/changelog'

[ -n "$BACKUP" ] && cp "$CHANGELOG" "/tmp/$(basename $CHANGELOG).bk"
vers="$(git rev-list HEAD | sed -n '$=')"
mnt() { echo "\n -- $auline  $dtline"; }

cat /dev/null >"$CHANGELOG"
(git log --date=rfc ; echo commit) | while read w r; do
	if [ "$w" = 'commit' ]; then
		[ -n "$dtline" ] && mnt # complete prev record
		[ -z "$r" ] && continue
		echo "\n$NAME ($vers) $DISTS; $META"
		vers=$(($vers - 1))
	elif [ "$w" = 'Author:' ]; then
		auline="$r"
	elif [ "$w" = 'Date:' ]; then
		dtline="$r"
	elif [ -z "$w" ]; then
		:
	else
		echo "\n  "'*'" $w $r"
	fi
done >>"$CHANGELOG"
[ -n "$dtline" ] && mnt >>"$CHANGELOG" # complete last record

exit 0

