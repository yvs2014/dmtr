:

set -e

NAME='dmtr'
VERPRFX='0.1'

BACKUP=yes
CHANGELOG='CHANGELOG.md'
DEBCHANGELOG='debian/changelog'
DISTS='lunar mantic'
META='urgency=low'
EMAIL='yvs <VSYakovetsky@gmail.com>'

FILE1='pubspec.yaml'
PATT1='version:'
FILE2='bin/params.dart'
PATT2='final version ='
FILE3='snapcraft.yaml'
PATT3='version:'


[ $# -lt 1 ] && { echo "Use: $(basename $0) 'string with comment'"; exit 1; }

git_comments=
md_comments=
deb_comments=
for m in "$@"; do
	git_comments="$git_comments -m \"$m\""
	md_comments="$md_comments\n- $m"
	deb_comments="$deb_comments\n  "'*'" $m"
done


[ -n "$TAG0" ] && { fltr=sed; fargs="/^$TAG0/q"; } || fltr=cat

vers="$(git rev-list HEAD | $fltr $fargs | sed -n '$=')"
next=$(($vers + 1))
vn="$VERPRFX.$next"
[ -n "$BACKUP" ] && cp "$FILE1" "/tmp/$(basename $FILE1).bk"
sed -i "s/^\(\s*$PATT1\).*/\1 $vn/" $FILE1
[ -n "$BACKUP" ] && cp "$FILE2" "/tmp/$(basename $$FILE2).bk"
sed -i "s/^\(\s*$PATT2\).*;/\1 \'$vn\';/" $FILE2
[ -n "$BACKUP" ] && cp "$FILE3" "/tmp/$(basename $$FILE3).bk"
sed -i "s/^\(\s*$PATT3\).*/\1 \'$vn\'/" $FILE3

[ -n "$BACKUP" ] && cp "$CHANGELOG" "/tmp/$(basename $CHANGELOG).bk"
[ -n "$BACKUP" ] && cp "$DEBCHANGELOG" "/tmp/$(basename $DEBCHANGELOG).bk"

## md format
echo "## $VERPRFX.${next}$md_comments" > "$CHANGELOG"
git log | while read w r; do
	if [ "$w" = 'commit' ]; then
		echo ""
		echo "## $VERPRFX.$vers"
		vers=$(($vers - 1))
	elif [ -z "$w" -o "$w" = 'Author:' -o "$w" = 'Date:' ]; then
		:
	else
		echo "- $w $r"
	fi
done >>"$CHANGELOG"

## deb format
tmpf="/tmp/debch.$$"
trap "rm -f $tmpf" EXIT TERM
( echo "$NAME ($next) $DISTS; $META\n$deb_comments\n\n -- $EMAIL  $(date -R)\n"; cat "$DEBCHANGELOG"; ) >"$tmpf"
mv "$tmpf" "$DEBCHANGELOG"

echo "Keep in mind to do:"
echo "	git diff"
echo "	git status"
echo "	git add ."
echo "	git commit $git_comments"
echo "	git push"

