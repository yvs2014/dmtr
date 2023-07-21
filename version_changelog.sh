:

set -e

VERPRFX='0.1'
#TAG0='d36a7e3'

BACKUP=yes

CHANGELOG='CHANGELOG.md'
FILE1='pubspec.yaml'
PATT1='version:'
FILE2='bin/common.dart'
PATT2='final version ='


[ $# -lt 1 ] && { echo "Use: $(basename $0) 'string with comment'"; exit 1; }

git_comments=
chl_comments=
for m in "$@"; do
	git_comments="$git_comments -m \"$m\""
	chl_comments="$chl_comments\n- $m"
done


[ -n "$TAG0" ] && { fltr=sed; fargs="/^$TAG0/q"; } || fltr=cat

vers="$(git rev-list HEAD | $fltr $fargs | sed -n '$=')"
next=$(($vers + 1))

[ -n "$BACKUP" ] && cp "$FILE1" "/tmp/$(basename $FILE1).bk"
sed -i "s/^\($PATT1\).*/\1 $VERPRFX.$next/" $FILE1
[ -n "$BACKUP" ] && cp "$FILE2" "/tmp/$(basename $$FILE2).bk"
sed -i "s/^\($PATT2\).*/\1 \'$VERPRFX.$next\';/" $FILE2

[ -n "$BACKUP" ] && cp "$CHANGELOG" "/tmp/$(basename $CHANGELOG).bk"

echo "## $VERPRFX.${next}$chl_comments" > "$CHANGELOG"
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

echo "Keep in mind to do:"
echo "	git diff"
echo "	git status"
echo "	git add ."
echo "	git commit $git_comments"
echo "	git push"

