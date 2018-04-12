#!/usr/bin/env bash

set -o nounset
set -o errexit

# set defaults
markdownFolder="wiki-markdown"
htmlFolder="wiki-html"
gitList="conf/gitList.txt"
gitBranch="master"
forceCleanup=false

function log() {
  echo -e "$(date +"%F %T") [${BASH_SOURCE}] -- $@" >&2
}

function on_error(){
    log "Error at line ${BASH_LINENO[0]} running command ${BASH_COMMAND}"
}

# set error handler
trap on_error ERR

# print usage
function print_usage(){
    echo -e "\nUSAGE: ${0} [--force-cleanup] [--html <PATH>] [--md <PATH>] [--git-branch <BRANCH_NAME>] <REPOSITORIES_LIST_FILE>\n"  >&2
}

# Collect arguments to be passed on to the next program in an array, rather than
# a simple string. This choice lets us deal with arguments that contain spaces.
ARGS=()

# parse arguments
while [ "$#" -gt 0 ]; do
    # Copy so we can modify it (can't modify $1)
    OPT="$1"
    # Detect argument termination
    if [ x"$OPT" = x"--" ]; then
            shift
            for OPT ; do
                    # append to array
                    ARGS+=("$OPT")
            done
            break
    fi
    # Parse current opt
    while [ x"$OPT" != x"-" ] ; do
            case "$OPT" in
                  -h | --help )
                          print_usage
                          exit 0
                          ;;
                  --force-cleanup )
                          forceCleanup=true
                          ;;
                  --html=* )
                          htmlFolder="${OPT#*=}"
                          shift
                          ;;
                  --html )
                          htmlFolder="$2"
                          shift
                          ;;
                  --md=* )
                          markdownFolder="${OPT#*=}"
                          shift
                          ;;
                  --md )
                          markdownFolder="$2"
                          shift
                          ;;
                  --git-branch=* )
                          gitBranch="${OPT#*=}"
                          shift
                          ;;
                  --git-branch )
                          gitBranch="$2"
                          shift
                          ;;
                  * )
                          # append to array
                          ARGS+=("$OPT")
                          break
                          ;;
            esac
            break
    done
    # move to the next param
    shift
done

# set and trim the REPOSITORIES_LIST_PARAMETER containing the list of git repositories
gitList="${ARGS//[[:space:]]/}"

# check whether gitList parameter has been provided
if [[ -z "${gitList}" ]]; then
    echo -e "\nYou need to provide the <REPOSITORIES_LIST_FILE> !!!\n" >&2
    exit 2
fi

# export
export markdownFolder
export htmlFolder
export gitList
export gitBranch
export forceCleanup