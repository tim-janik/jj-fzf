#!/usr/bin/env bash
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0

# == Strict mode & restore env ==
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then	# regular bash script
  set -Eeuo pipefail				# strict mode
  __preflightish_fixenv=''
  # Enable debugging
  [[ " $* " =~ " -x " ]] &&
    set -x
else						# sourced script
  __preflightish_fixenv=$'unset __preflightish_fixenv\n'
  # Enter strict mode, but beware to restore shopts on RETURN
  [[ $- == *e* ]] || __preflightish_fixenv="$__preflightish_fixenv"$' set +o errexit \n'
  set -e		# Exit immediately on errors
  [[ $- == *u* ]] || __preflightish_fixenv="$__preflightish_fixenv"$' set +o nounset \n'
  set -u		# Treat unset variables as error
  shopt -qo errtrace || __preflightish_fixenv="$__preflightish_fixenv"$' set +o errtrace \n'
  set -E		# Any trap on ERR is inherited by functions and subshells
  shopt -qo pipefail || __preflightish_fixenv="$__preflightish_fixenv"$' set +o pipefail \n'
  set -o pipefail	# Return value of a pipeline is 0 only if all commands in the pipeline exit 0
fi

# == Helpers ==
__preflightish_die() { echo "$0: **ERROR**: ${*:-aborting}" >&2; exit 127 ; }
__preflightish_fixenv="$__preflightish_fixenv"$' unset -f __preflightish_die \n'

# == Bash ==
# bash 5.1 introduced $SRANDOM
bash -c '[[ -n ${SRANDOM+set} ]]' ||
  __preflightish_die "Failed to detect 'bash' >= 5.1 in \$PATH"
[[ "`bash -c 'set -o'`" =~ emacs ]] ||
  __preflightish_die "The 'bash' executable lacks interactive readline support"

# == sed ==
if ! declare -F sed >/dev/null; then	# ignore existing sed() compat func
  if ! sed --version 2>/dev/null | grep -Fq 'GNU sed' ; then
    # sed is not GNU
    if gsed --version 2>/dev/null | grep -Fq 'GNU sed' ; then
      # use gsed instead of sed
      sed() { gsed "$@"; }
      export -f sed
    else
      __preflightish_die "Failed to find GNU sed as 'sed' or 'gsed'"
    fi
  fi
fi


# == Success ==
[[ "${BASH_SOURCE[0]}" == "$0" ]] &&
  echo "  OK         All preflight.sh checks passed"
eval "$__preflightish_fixenv"	# Restore shell options
true	# otherwise exit status from above could apply
