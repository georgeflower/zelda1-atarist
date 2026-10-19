#!/bin/sh
# Tags 0.18 .. 0.29 on the commits that finished them (see CHANGELOG.md), and 0.30 on HEAD (run it on master after the
# versions PR is merged). Then: git push origin --tags
set -e
i=18
for c in 8b3459e bd26899 e2de20b 7280fa7 590fbac aeddde9 bce634e 75336fb 6556dd4 9220dcb 8c1217b ebb5247; do
    git tag "0.$i" "$c"
    i=$((i + 1))
done
git tag 0.30 "${1:-HEAD}"
