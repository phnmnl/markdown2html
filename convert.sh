#!/usr/bin/env bash

set -o nounset
set -o errexit

function log() {
  echo -e "$(date +"%F %T") [${BASH_SOURCE}] -- $@" >&2
}

function delete_folder() {
    local type="${1}"
    local path="${2}"
    if [[ ! -z "${path}" && -d "${path}" ]]; then
        log " - Removing ${type} folder ${path}"
        rm -Rf "${path}"
    fi
}

function delete_remote_git_list(){
    # remove downloaded list of repositories
    if [[ ! -z "${remoteGitList}" ]]; then
        log "\nCleaning: removing temp list of repositories..."
        rm ${gitList}
    fi
}

function delete_created_folders(){
    if [[ -d "${htmlFolder}" || -d "${markdownFolder}" ]]; then
        log "\nCleaning: removing created folders..."
        delete_folder "html" ${htmlFolder}
        delete_folder "markdown" ${markdownFolder}
    fi
}

function on_error(){
    log "Error at line ${BASH_LINENO[0]} running command ${BASH_COMMAND}"
    if [[ ! -z ${container_name} ]]; then
        log "Conversion of the container '${container_name}' failed!"
    fi
    # cleanup
    delete_created_folders
}

function on_interrupt(){
    # cleanup
    delete_created_folders
}


function on_exit(){
    delete_remote_git_list
}

# set error handler
trap on_error ERR

# set interrupt handler
trap on_interrupt INT TERM

# log exit handler
trap on_exit EXIT

# compute an absolute path
function absPath(){
    if [[ -d "$1" ]]; then
      (cd "$1" && echo "$(pwd -P)")
    else
      (cd "$(dirname "$1")" && echo "$(pwd -P)/$(basename "$1")")
    fi
}

# convert md files of a git repo into html
function convert_markdown(){
    local source_path="${1}"
    local target_path="${2}"
    # ensure an empty target folder
    rm -Rf "${target_path}" && mkdir -p "${target_path}"
    # perform the conversion of .md files
    for file in `ls "${source_path}"`;
    do
        file=$(basename "${file}")
        filename="${file%.*}"
        extension="${file##*.}"
        if [[ ! -d "${file}" ]] && [[ ${extension} = "md" ]]; then
          log "Converting ${file} to ${filename}${targetExtension}..."
          "${markdownExecutable}" --extras fenced-code-blocks \
                    "${source_path}/$file" > "${target_path}/${filename}${targetExtension}"
      fi
    done
}

# print usage
function print_usage(){
    echo -e "\nUSAGE: ${0} [--force-cleanup] [--html <PATH>] [--md <PATH>] [--git-branch <BRANCH_NAME>] <REPOSITORIES_LIST_FILE>\n"  >&2
}

# set defaults
markdownExecutable="markdown2"
markdownFolder="wiki-markdown"
htmlFolder="wiki-html"
gitList="conf/gitList.txt"
gitBranch="master"
remoteGitList=""
targetExtension=".html"
forceCleanup=false
waitBetweenRepos=5 # seconds

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

# log configuration
(echo -e "\n-------------------------------------------------------------------------------------------------------"
echo -e "*** Converter Configuration *** "
echo -e "-------------------------------------------------------------------------------------------------------"
echo "Markdown folder: ${markdownFolder}"
echo "Html folder: ${htmlFolder}"
echo "Git Repositories file: ${gitList}"
echo "Git branch: ${gitBranch}"
echo -e "-------------------------------------------------------------------------------------------------------") >&2

# download the list file if it is a HTTP(s) resource
if [[ ! -z "${gitList}" && "${gitList}" =~ ^https?://.+  ]]; then
    log "Downloading list of repositories..."
    remoteGitList="${gitList}"
    gitList=$(mktemp)
    wget -O "${gitList}" "${remoteGitList}"
    log "Downloading list of repositories... DONE"
fi

# Check whether the gitList file exists or not
if [[ ! -f "${gitList}" ]]; then
    log "GitList file '${gitList}' doesn't exist!!!"
    exit 2
fi

# force absolute paths
htmlFolder=$(absPath "${htmlFolder}")
markdownFolder=$(absPath "${markdownFolder}")
gitList=$(absPath "${gitList}")

# create required folder if they don't exist
mkdir -p "${markdownFolder}"
mkdir -p "${htmlFolder}"

# set markdown folder as working dir
cd "${markdownFolder}"

# process list of container repositories
while IFS= read line
do
    # skip blank lines
    if [[ ! -z ${line} ]]; then
        # extract the container name
        container_name=$(echo ${line} | sed -e 's/https:\/\/\([^\/]\+\)\/\([^\/]\+\)\/\(.*\)\.git/\3/g')
        log "----"
        log "Processing container '$container_name'..."
        # if the repository already exists simply update it
        # otherwise it will be cloned
        if [[ -d "${container_name}" && ! ${forceCleanup} ]]; then
            log "Updating existing repository..."
            cd "${container_name}" && git pull origin "${gitBranch}" && cd ..
        else
            # cleanup existing git repositories is required
            if [[ -d "${container_name}" ]]; then
                log "Cleaning existing repositories..."
                rm -Rf "./${container_name}"
                log "Cleaning existing repositories... DONE"
            fi
            # download the repository
            git clone --depth 1 -b "${gitBranch}" "$line"
        fi
        # convert markdown
        convert_markdown "./${container_name}" "${htmlFolder}/${container_name}"
        log "Processing container '$container_name'... DONE"
        # wait before the next conversion job
        sleep ${waitBetweenRepos}
    fi
done <"$gitList"
