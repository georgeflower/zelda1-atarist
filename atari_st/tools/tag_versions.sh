#!/bin/sh
# Tags 0.18 .. 0.30 on the commits that finished them (see CHANGELOG.md), and 0.31 on HEAD (run it on master after the
# M1 PR is merged, or pass the commit). Then: git push origin --tags
set -e
i=18
for c in 8b3459e bd26899 e2de20b 7280fa7 590fbac aeddde9 bce634e 75336fb 6556dd4 9220dcb 8c1217b ebb5247; do
    git tag "0.$i" "$c"
    i=$((i + 1))
done
git tag 0.30 f617c72
git tag 0.31 51deaa4
git tag 0.32 "${1:-HEAD}"
