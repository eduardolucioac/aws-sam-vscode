#!/bin/bash

# NOTE: Avoids problems with relative paths.
SCRIPT_DIR_S="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

function f_ask_support() {
    : 'Display a notice asking for a donation.'

    # shellcheck disable=SC2086
    if [ $I_SUPPORT_FREE_SOFTWARE_N_THIS_WORK -eq 1 ]; then
        return
    fi

    echo " > ------------------- 
I'm just a regular everyday normal guy with bills and family.
This is an open-source project and will continue to be so forever.

Please consider to deposit a donation through PayPal 
( https://www.paypal.com/donate/?hosted_button_id=TANFQFHXMZDZE ).

Support free software and my work!🐧❤️
 < ------------------- "
}

# NOTE: In some cases when the application directory is accessed via bash script
# executed by VSCode the virtualenv does not activate automatically even if this
# is configured.
function f_venv_activate() {
    : 'Activates the virtualenv.'

    # shellcheck disable=SC1091
    source "$SCRIPT_DIR_S/venv.bash"
}

# NOTE: This function will basically ensure that the container will be removed if
# sam doesn't.
function f_rm_sam_container() {
    : 'Removes a container created by sam.

    Removes a container created by sam identifying it by the mapped port.
    '

    SAM_CONT_ID=$(docker container ls --format="{{.ID}}\t{{.Ports}}" |
        grep ":$DEGUB_PORT-" |
        awk '{print $1}')
    if [ -n "$SAM_CONT_ID" ]; then
        docker container stop "$SAM_CONT_ID" 2>/dev/null 1>/dev/null
        docker container rm "$SAM_CONT_ID" 2>/dev/null 1>/dev/null
    fi
}

F_FLOW_STATUS=0
function f_flow_status() {
    : 'Checks if the flow_status file has a certain value.

    Args:
        EXPECTED_STATE (str): The value you want to check in the flow_status file.
    '

    local EXPECTED_STATE=$1
    FLOW_STATUS=$(cat ./.temp/flow_status 2>/dev/null)

    if [ "$FLOW_STATUS" != "$EXPECTED_STATE" ]; then
        F_FLOW_STATUS=0
    else
        # shellcheck disable=SC2034
        F_FLOW_STATUS=1
    fi
}
