#!/bin/bash

# NOTE: Avoids problems with relative paths.
SCRIPT_DIR_S="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# NOTE: Load common resources.
# shellcheck disable=SC1091
source "$SCRIPT_DIR_S/common.bash"

# NOTE: Load configurations.
# shellcheck disable=SC1091
source "$SCRIPT_DIR_S/config.bash"

# NOTE: Removes outputs referring to previous runs.
rm -rf ./.temp
mkdir ./.temp

EXIT_CODE=0
# shellcheck disable=SC2317
function f_rm_requirements() {
    : 'Removes the "requirements.txt" (Python).'

    # NOTE: Conditions to avoid accidental deletion of a "requirements.txt" (Python)
    # file in the project root.
    #  - '[ "$DISARM_TRAP" -eq 1 ]' -> If "DISARM_TRAP" is EQUAL to 1.
    #  - '[ -z "$PYTHON_REQUIREMENTS" ]' -> If "PYTHON REQUIREMENTS" is an empty string.
    #  - '[ ! -L "./requirements.txt" ]' -> If "./requirements.txt" is NOT a symbolic link.
    # [Ref(s).: https://unix.stackexchange.com/a/96910/61742 ]
    # shellcheck disable=SC2086
    if [ $DISARM_TRAP -eq 1 ] || [ -z "$PYTHON_REQUIREMENTS" ] || [ ! -L "./requirements.txt" ] ; then
        return
    fi

    rm -f ./requirements.txt 2> /dev/null
}

# NOTE: The "requirements.txt" (Python) file, if it exists, needs to be in the root
# of the project to be consumed by the "sam build" subcommand.
if [ -n "$PYTHON_REQUIREMENTS" ] ; then
    if [ -f "./requirements.txt" ] ; then
        DISARM_TRAP=1
        echo " > --------------------------------------------------------- 
    A \"requirements.txt\" (Python) file already exists in the project root.
 < --------------------------------------------------------- "
        sleep 10
    else
        echo " > --------------------------------------------------------- 
    Making available (symbolic link) the \"requirements.txt\" (Python) informed \
in the project root.
 < --------------------------------------------------------- "
        ln -rs "$PYTHON_REQUIREMENTS" ./requirements.txt
    fi
fi

DISARM_TRAP=0

# NOTE: Removes the "requirements.txt" (Python) if necessary.
trap 'f_rm_requirements;exit $EXIT_CODE' EXIT

BUILD_STATUS=0
function f_sam_build_api(){
    : 'Build the API via sam.

    Builds the API via sam and and exits 0 ("exit 0") on script if success. Executes
    the line and exits the script on success.

    Returns:
        BUILD_STATUS (int): 1 if the build was successful, 0 otherwise.
    '

    BUILD_STATUS=0
    local TEMPLATE_FILE_NOW=""
    if [ -n "$TEMPLATE_FILE" ] ; then
        # shellcheck disable=SC2089
        TEMPLATE_FILE_NOW="--template-file \"$TEMPLATE_FILE\""
    fi

    # shellcheck disable=SC2086
    # shellcheck disable=SC2090
    sam build \
        "$LAMBDA_FUNC_DEBUG" \
        $TEMPLATE_FILE_NOW | \
    grep -q "Commands you can use next" && \
    echo " > ------------------- 
    BUILD
    SUCCESS
    < ------------------- "; \
    echo -n "BUILD_SUCCESS" > ./.temp/flow_status; \
    EXIT_CODE=0; \
    # shellcheck disable=SC2034
    BUILD_STATUS=1
}

f_venv_activate
f_sam_build_api
if [ $BUILD_STATUS -eq 0 ]; then
    echo " > ------------------- 
    BUILD
    ERROR
    < ------------------- "
    echo -n "BUILD_ERROR" > ./.temp/flow_status;
    EXIT_CODE=1
fi
