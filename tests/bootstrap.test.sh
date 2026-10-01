#!/usr/bin/env bash
set -u
WB_SRC=$(cd "$(dirname "$0")/.." && pwd)
. "$WB_SRC/tests/harness.sh"

echo "bootstrap prints check and the link plan but changes nothing"
t_fixture
cp "$WB_SRC/scripts/bootstrap" "$T_REPO/scripts/" 2>/dev/null
printf '#!/usr/bin/env bash\necho "check ran"\nexit 1\n' > "$T_REPO/scripts/check"; chmod +x "$T_REPO/scripts/check"
out=$(HOME=$T_HOME "$T_REPO/scripts/bootstrap" 2>&1); rc=$?
assert_eq "exit 0 even when check fails on a fresh machine" 0 "$rc"
assert_contains "runs check" "check ran" "$out"
assert_contains "shows link plan" "[plan] alpha" "$out"
refute "creates no link" test -L "$T_HOME/.alpha"
refute "creates no backup" test -e "$T_HOME/.cli-workbench-backup"
t_cleanup
t_done
