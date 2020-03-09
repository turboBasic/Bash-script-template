#!/usr/bin/env bash

# DESC: Handler for unexpected errors
# ARGS: $1 (optional): Exit code (defaults to 1)
# OUTS: None
function Bash::trapError() {
    local exitCode=1

    # Disable the error trap handler to prevent potential recursion
    trap - ERR

    # Consider any further errors non-fatal to ensure we run to completion
    set +o errexit
    set +o pipefail

    # Validate any provided exit code
    if [[ ${1-} =~ ^[0-9]+$ ]]; then
        exitCode="$1"
    fi

    # Output debug data if in Cron mode
    # printCronDiagnosticsOrSkip 
    if [[ -n ${cron-} ]]; then
        # Restore original file output descriptors
        # shellcheck disable=SC2154
        if [[ -n "${Bash::SCRIPT_OUTPUT-}" ]]; then
            exec 1>&3 2>&4
        fi


        # shellcheck source=/dev/null
        printf '%b%b\n' "${ta_none-}" "${fg_magenta-}"
        printf '***** Abnormal termination of script *****\n'
        printf '%b\n' "$ta_none"

        Std::printVariables \
            SCRIPT_PATH \
            SCRIPT_PATH_RESOLVED \
            SCRIPT_DIR \
            LIB_DIR_RESOLVED \
            SCRIPT_NAME \
            SCRIPT_ARGS \
            exitCode
        echo

        # Print the script log if we have it. It's possible we may not if we
        # failed before we even calledBash::cronInit(). This can happen if bad
        # parameters were passed to the script so we bailed out very early.
        if [[ -n ${Bash::SCRIPT_OUTPUT-} ]]; then
            printf 'Script Output:\n\n%s\n' "$(cat "${Bash::SCRIPT_OUTPUT-}")"
        else
            printf 'Script Output:          None (failed before log init)\n'
        fi
    fi

    # Exit with failure status
    exit $((exitCode))
}

# DESC: Handler for exiting the script
# ARGS: None
# OUTS: None
function Bash::trapExit() {
    cd "$ORIG_CWD"

    # Remove Cron mode script log
    if [[ -n ${cron-} && -f ${Bash::SCRIPT_OUTPUT-} ]]; then
        rm "${Bash::SCRIPT_OUTPUT}"
    fi

    # Remove script execution lock
    if [[ -d ${script_lock-} ]]; then
        rmdir "$script_lock"
    fi

    # Restore terminal colors
    printf '%b' "$ta_none"
}

# DESC: Exit script with the given message
# ARGS: $1 (required): Message to print on exit
#       $2 (optional): Exit code (defaults to 0)
# OUTS: None
# NOTE: The convention used in this script for exit codes is:
#       0: Normal exit
#       1: Abnormal exit due to external error
#       2: Abnormal exit due to script error
function Bash::scriptExit() {
    if [[ $# -eq 1 ]]; then
        printf '%s\n' "$1"
        exit 0
    fi

    if [[ ${2-} =~ ^[0-9]+$ ]]; then
        printf '%b\n' "$1"
        # If we've been provided a non-zero exit code run the error trap
        if [[ $2 -ne 0 ]]; then
            Bash::trapError "$2"
        else
            exit 0
        fi
    fi

    Bash::scriptExit 'Missing required argument to Bash::scriptExit()!' 2
}




# DESC: Initialise Cron mode
# ARGS: None
# OUTS: $Bash::SCRIPT_OUTPUT: Path to the file stdout & stderr was redirected to
function Bash::cronInit() {
    if [[ -n ${cron-} ]]; then
        # Redirect all output to a temporary file
        readonly Bash::SCRIPT_OUTPUT="$(mktemp --tmpdir "$SCRIPT_NAME".XXXXX)"
        exec 3>&1 4>&2 1> "${Bash::SCRIPT_OUTPUT}" 2>&1
    fi
}

# DESC: Acquire script lock
# ARGS: $1 (optional): Scope of script execution lock (system or user)
# OUTS: $script_lock: Path to the directory indicating we have the script lock
# NOTE: This lock implementation is extremely simple but should be reliable
#       across all platforms. It does *not* support locking a script with
#       symlinks or multiple hardlinks as there's no portable way of doing so.
#       If the lock was acquired it's automatically released on script exit.
function Bash::lockInit() {
    local lock_dir
    if [[ $1 = 'system' ]]; then
        lock_dir="/tmp/$SCRIPT_NAME.lock"
    elif [[ $1 = 'user' ]]; then
        lock_dir="/tmp/$SCRIPT_NAME.$UID.lock"
    else
        Bash::scriptExit 'Missing or invalid argument to Bash::lockInit()!' 2
    fi

    if mkdir "$lock_dir" 2> /dev/null; then
        readonly script_lock="$lock_dir"
        Std::verbosePrint "Acquired script lock: $script_lock"
    else
        Bash::scriptExit "Unable to acquire script lock: $lock_dir" 1
    fi
}
