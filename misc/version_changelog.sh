:

set -e

NAME='dmtr'
VERPRFX='0.1'

BACKUP=
MD_CHANGELOG='CHANGELOG.md'
DEB_CHANGELOG='debian/changelog'
DISTS='lunar mantic'
META='urgency=low'
EMAIL='yvs <VSYakovetsky@gmail.com>'

FILE_Y1='pubspec.yaml'
FILE_Y2='snap/snapcraft.yaml'
PATT_Y='version:'
FILE_D='bin/params.dart'
PATT_D='version\s+='

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
[ -n "$BACKUP" ] && cp "$FILE_Y1" "/tmp/$(basename $FILE_Y1).bk"
[ -n "$BACKUP" ] && cp "$FILE_Y2" "/tmp/$(basename $FILE_Y2).bk"
sed -i "s/^\(\s*$PATT_Y\).*/\1 $vn/" "$FILE_Y1" "$FILE_Y2"
[ -n "$BACKUP" ] && cp "$FILE_D" "/tmp/$(basename $FILE_D).bk"
sed -i "s/^\(\s*$PATT_D\).*;/\1 \'$vn\';/" "$FILE_D"

[ -n "$BACKUP" ] && cp "$MD_CHANGELOG" "/tmp/$(basename $MD_CHANGELOG).bk"
[ -n "$BACKUP" ] && cp "$DEB_CHANGELOG" "/tmp/$(basename $DEB_CHANGELOG).bk"

## md format
printf "## $VERPRFX.${next}$md_comments\n" > "$MD_CHANGELOG"
git log | while read w r; do
	if [ "$w" = 'commit' ]; then
		printf "\n## $VERPRFX.$vers\n"
		vers=$(($vers - 1))
	elif [ -z "$w" -o "$w" = 'Author:' -o "$w" = 'Date:' ]; then
		:
	else
		echo "- $w $r"
	fi
done >>"$MD_CHANGELOG"

## deb format
_tf="/tmp/$(basename $DEB_CHANGELOG).$$"
trap "rm -f $tmpf" EXIT TERM
cp "$DEB_CHANGELOG" "$_tf"
printf "$NAME ($VERPRFX.$next) $DISTS; $META\n$deb_comments\n\n -- $EMAIL  $(date -R)\n\n" | cat - "$_tf" >"$DEB_CHANGELOG"

echo "Keep in mind to do:"
echo "	git diff"
echo "	git status"
echo "	dart analyze"
echo "	git add ."
echo "	git commit $git_comments"
echo "	git push"

