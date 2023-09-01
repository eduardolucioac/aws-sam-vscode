#!/bin/bash

# NOTE: Avoids problems with relative paths.
SCRIPT_DIR_S="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# NOTE: Load common resources.
# shellcheck disable=SC1091
source "$SCRIPT_DIR_S/common.bash"

# NOTE: Load configurations.
# shellcheck disable=SC1091
source "$SCRIPT_DIR_S/config.bash"

function f_sam_stop_api(){
    : 'Stops the API via sam.'

    # Send a SIGINT signal to the SAM process to gracefully stop it.
    # shellcheck disable=SC2046
    kill -2 $(cat ./.temp/sam_pid) 2> /dev/null

    f_rm_sam_container
}

f_sam_stop_api
# shellcheck disable=SC2046
kill -9 $(cat ./.temp/tail_debug_pid) 2> /dev/null
rm -rf ./.temp
echo " > ------------------- 
STOP
SUCCESS
 < ------------------- "

# NOTE: Give some time in case of a debug restart process.
sleep 3

exit 0
