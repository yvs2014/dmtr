:

set -e
LANG=C

NAME='dmtr'
BACKUP=yes
DISTS='lunar mantic'
META='urgency=low'
CHANGELOG='debian/changelog'
BASE='0.1'

[ -n "$BACKUP" ] && [ -f "$CHANGELOG" ] && cp "$CHANGELOG" "/tmp/$(basename $CHANGELOG).bk"
vers="$(git rev-list HEAD | sed -n '$=')"
mnt() { printf "\n -- $auline  $dtline\n\n"; }

cat /dev/null >"$CHANGELOG"
(git log --date=rfc ; echo commit) | while read w r; do
	if [ "$w" = 'commit' ]; then
		[ -n "$dtline" ] && mnt # complete prev record
		[ -z "$r" ] && continue
		echo "$NAME ($BASE.$vers) $DISTS; $META"
		vers=$(($vers - 1))
	elif [ "$w" = 'Author:' ]; then
		auline="$r"
	elif [ "$w" = 'Date:' ]; then
		dtline="$r"
	elif [ -z "$w" ]; then
		:
	else
		printf "\n  "'*'" $w $r\n"
	fi
done >>"$CHANGELOG"
[ -n "$dtline" ] && mnt >>"$CHANGELOG" # complete last record

exit 0

