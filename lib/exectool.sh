#!/usr/bin/env bash
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0
exec $EXECTOOL_CMD "$@"
# Hook to serve as a single-executable trampoline for e.g. `EXECTOOL_CMD="git diff" jj show --tool exectool.sh`
