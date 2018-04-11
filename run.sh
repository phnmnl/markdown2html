#!/usr/bin/env bash

set -o nounset
set -o errexit

function log() {
  echo -e "$(date +"%F %T") [${BASH_SOURCE}] -- $@" >&2
}

function remove_folder(){
    local type="${1}"
    local path="${2}"
    if [[ ! -z "${path}" && -d "${path}" ]]; then
        log " - Removing ${type} folder ${path}"
        rm -Rf "${path}"
    fi
}

function remove_old_folders(){
    if [[ -d "${oldHtmlFolder}" || -d "${oldMarkdownFolder}" ]]; then
        log "\nCleaning: removing old folders..."
        remove_folder "old html" ${oldHtmlFolder}
        remove_folder "old markdown" ${oldMarkdownFolder}
    fi
}


function update_links(){
    # check whether there exists the new folder (redundant)
    if [[ -d "${newHtmlFolder}" && -d "${newMarkdownFolder}" ]]; then
        log "\nCreating links to the updated resources..."
        log " - Linking new markdown folder ${newMarkdownFolder}"
        ln -sfn "${newMarkdownFolder}" "${markdownFolder}"
        log " - Linking new html folder ${newHtmlFolder}"
        ln -sfn "${newHtmlFolder}" "${htmlFolder}"
    fi
}


function on_interrupt(){
    interrupted="true"
}

function on_error(){
    log "Error at line ${BASH_LINENO[0]} running command ${BASH_COMMAND}"
}


function on_exit(){
    # cleanup temp folders if the process is interrupted
    if [[ ! -z ${interrupted} ]]; then
        log "Interrupted by signal (SIGINT/SIGTERM)"
        exit 130
    fi
    # cleanup temp folders if the process fails and notify the error code
    if [[ -z ${converter_exit_code} || ${converter_exit_code} -ne 0 ]]; then
        exit 99
    fi
    # update links and remove old resources
    # if the conversion process is OK
    update_links
    remove_old_folders
    exit 0
}

# cleanup temporary data if the process fails
trap on_error ERR

# cleanup temporary data if the process is interrupted
trap on_interrupt INT TERM

# register handler to finalize results on exit
trap on_exit EXIT

# base paths
current_path="$( cd "$(dirname "${0}")" ; pwd -P )"
converter="${current_path}/convert.sh"

if [[ ! -x "${converter}" ]]; then
    log "ERROR! Either the converter script ${converter} isn't present or it's not executable"
    exit 2
fi

# default settings
base_path="."
htmlFolder="$base_path/wiki-html"
markdownFolder="$base_path/wiki-markdown"
gitList="${base_path}/gitList.txt"
gitBranch="master"

# use the configuration file if provided
if [[ "$#" -gt 0 ]]; then
    config_file="${1}"
    if [[ -n "${config_file}" ]]; then
        if [[ ! -f ${config_file} ]]; then
            log "'${config_file}' is not a valid configuration file !!!"
        fi
        log "Using configuration file: ${config_file}"
        source "${config_file}"
    fi
fi
# set directories to host new files
timestamp="$(date +%s)"
newHtmlFolder="${htmlFolder}-${timestamp}"
newMarkdownFolder="${markdownFolder}-${timestamp}"
oldHtmlFolder=""
oldMarkdownFolder=""

# aux variables
interrupted=""
converter_exit_code=""

# read the old html link
if [[ -L "${htmlFolder}" ]]; then
    oldHtmlFolder=$(readlink -f "${htmlFolder}")
fi

# read the old markdown link
if [[ -L "${markdownFolder}" ]]; then
    oldMarkdownFolder=$(readlink -f "${markdownFolder}")
fi

# print path info
log "\nScript path: ${current_path}" \
    "\nTarget base path: ${base_path}" \
    "\nHtml Folder [New]: ${newHtmlFolder}" \
    "\nHtml Folder [Old]: ${oldHtmlFolder}" \
    "\nHtml Folder [Link]: ${htmlFolder}" \
    "\nMarkdown Folder [New]: ${newMarkdownFolder}" \
    "\nMarkdown Folder [Old]: ${oldMarkdownFolder}" \
    "\nMarkdown Folder [Link]: ${markdownFolder}"

# start conversion
${converter} \
    --force-cleanup \
    --html "${newHtmlFolder}" \
    --md "${newMarkdownFolder}" \
    --git-branch "${gitBranch}" \
    "${gitList}"

# get the converter exit code
converter_exit_code=$? # This will always be zero as long as errexit is enabled
