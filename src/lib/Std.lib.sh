#!/usr/bin/env bash

Std::NO_COLOR=


# shellcheck disable=SC2034
function Std::setAnsiCodeOrNull() {
    # local varName="$1"
    declare -n varRef="$1"

    if [[ -n "$2" ]]
    then
        readonly varRef="$(
            tput "$2" "${@:3}" 2> /dev/null || true
        )"
    # else
    #     readonly varRef=''
    fi

    tput sgr0 2> /dev/null || true
}


# DESC: Initialise color variables
# ARGS: None
# OUTS: Read-only variables with ANSI control codes
# NOTE: If --no-color was set the variables will be empty
# shellcheck disable=SC2034,SC2154
function Std::initColors() {
    readonly ta_none="$(tput sgr0 2> /dev/null || true)"

    if [[ -n "${Std::NO_COLOR-}" ]] 
    then
        local empty=empty
    else
        local empty=
    fi

    Std::setAnsiCodeOrNull  ta_bold    ${empty+bold}
    Std::setAnsiCodeOrNull  ta_uscore  ${empty+smul}
    Std::setAnsiCodeOrNull  ta_blink   ${empty+blink}
    Std::setAnsiCodeOrNull  ta_reverse ${empty+rev}
    Std::setAnsiCodeOrNull  ta_conceal ${empty+invis}

    # Foreground codes
    Std::setAnsiCodeOrNull  fg_black   ${empty+setaf} ${empty+0}
    Std::setAnsiCodeOrNull  fg_blue    ${empty+setaf} ${empty+4}
    Std::setAnsiCodeOrNull  fg_cyan    ${empty+setaf} ${empty+6}
    Std::setAnsiCodeOrNull  fg_green   ${empty+setaf} ${empty+2}
    Std::setAnsiCodeOrNull  fg_magenta ${empty+setaf} ${empty+5}
    Std::setAnsiCodeOrNull  fg_red     ${empty+setaf} ${empty+1}
    Std::setAnsiCodeOrNull  fg_white   ${empty+setaf} ${empty+7}
    Std::setAnsiCodeOrNull  fg_yellow  ${empty+setaf} ${empty+3}

    # Background codes
    Std::setAnsiCodeOrNull  bg_black   ${empty+setab} ${empty+0}
    Std::setAnsiCodeOrNull  bg_blue    ${empty+setab} ${empty+4}
    Std::setAnsiCodeOrNull  bg_cyan    ${empty+setab} ${empty+6}
    Std::setAnsiCodeOrNull  bg_green   ${empty+setab} ${empty+2}
    Std::setAnsiCodeOrNull  bg_magenta ${empty+setab} ${empty+5}
    Std::setAnsiCodeOrNull  bg_red     ${empty+setab} ${empty+1}
    Std::setAnsiCodeOrNull  bg_white   ${empty+setab} ${empty+7}
    Std::setAnsiCodeOrNull  bg_yellow  ${empty+setab} ${empty+3}
}


#
#
function Std::printVariables() {
    for variableName in "$@"
    do
        declare -n variableReference="$variableName"

        printf '%s' "$variableName:"

        case "$(declare -p "$variableName")" in
            "declare -a"* )
                for entry in "${variableReference[@]}"
                do
                    printf ' "%s"'  "$entry"
                done
                ;;
            "declare -A"* )
                for key in "${!variableReference[@]}"
                do
                    printf ' %s="%s"'  "$key" "${variableReference[$key]}"
                done
                ;;
            * )
                echo -n " $variableReference"
                ;;
        esac

        echo
    done
}


# DESC: Pretty print the provided string
# ARGS: $1 (required): Message to print (defaults to a green foreground)
#       $2 (optional): Colour to print the message with. This can be an ANSI
#                      escape code or one of the prepopulated color variables.
#       $3 (optional): Set to any value to not append a new line to the message
# OUTS: None
function Std::prettyPrint() {
    if [[ $# -lt 1 ]]; then
        Bash::scriptExit 'Missing required argument to Std::prettyPrint()!' 2
    fi

    if [[ -z ${Std::NO_COLOR-} ]]; then
        if [[ -n ${2-} ]]; then
            printf '%b' "$2"
        else
            printf '%b' "$fg_green"
        fi
    fi

    # Print message & reset text attributes
    if [[ -n ${3-} ]]; then
        printf '%s%b' "$1" "$ta_none"
    else
        printf '%s%b\n' "$1" "$ta_none"
    fi
}


# DESC: Only Std::prettyPrint() the provided string if verbose mode is enabled
# ARGS: $@ (required): Passed through to Std::prettyPrint() function
# OUTS: None
function Std::verbosePrint() {
    if [[ -n ${verbose-} ]]; then
        Std::prettyPrint "$@"
    fi
}
