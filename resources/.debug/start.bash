#!/bin/bash

# NOTE: Avoids problems with relative paths.
SCRIPT_DIR_S="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# NOTE: Load common resources.
# shellcheck disable=SC1091
source "$SCRIPT_DIR_S/common.bash"

# NOTE: Load configurations.
# shellcheck disable=SC1091
source "$SCRIPT_DIR_S/config.bash"

# NOTE: For some reason the sam's outputs (stdout and stderr) are all concentrated
# in stderr, no matter the situation. Hence why "f_tail_stdout" and "f_tail_stderr"
# have the logic below as well as other related logic in this script.

function f_tail_stdout() {
    : 'Monitors sam'\''s stderr output to determine error or success.'

    local SAM_STATUS_B=""
    (
        tail -f ./.temp/stdout_op &
        echo -n $! >./.temp/tail_stdout_pid
    ) | while read -r LINE_NOW; do
        SAM_STATUS_B=$(cat ./.temp/sam_status 2>/dev/null)
        if [ "$SAM_STATUS_B" != "sr" ]; then
            echo -e "$LINE_NOW" | grep -q " * Running on http" && echo -n "sr" >./.temp/sam_status
        fi
        echo -e "$LINE_NOW" | grep -q "START RequestId" && echo -n "ss" >./.temp/sam_status && break
        echo -e "$LINE_NOW" | grep -qi "error" && echo -n "se" >./.temp/sam_status && break
    done
}

function f_tail_stderr() {
    : 'Monitors sam'\''s stdout output to determine error or success.'

    local SAM_STATUS_A=""
    (
        tail -f ./.temp/stderr_op &
        echo -n $! >./.temp/tail_stderr_pid
    ) | while read -r LINE_NOW; do
        SAM_STATUS_A=$(cat ./.temp/sam_status 2>/dev/null)
        if [ "$SAM_STATUS_A" != "er" ]; then
            echo -e "$LINE_NOW" | grep -q " * Running on http" && echo -n "er" >./.temp/sam_status
        fi
        echo -e "$LINE_NOW" | grep -q "START RequestId" && echo -n "es" >./.temp/sam_status && break
        echo -e "$LINE_NOW" | grep -qi "error" && echo -n "ee" >./.temp/sam_status && break
    done
}

EXIT_CODE=0
function f_run_clear() {
    : 'Cleans up temporary products from one run and prepares for the next one.

    Args:
        SAM_STATUS (Optional[str]): "os" - (stdOut Success) Success detected in stdout;
    "oe" - (stdOut Error) Error detected in stdOut; "es" - (stdErr Success) Success
    detected in stderr; "ee" - (stdErr Error) Error detected in stderr; "to" - (TimeOut)
    Timeout; Default "".
    '

    local SAM_STATUS=$1
    if [ -z "$SAM_STATUS" ]; then
        SAM_STATUS=""
    fi

    if [ ${DISARM_TRAP} -eq 1 ]; then
        return
    fi
    # shellcheck disable=SC2046
    kill -9 $(cat ./.temp/tail_stderr_pid 2>/dev/null) 2>/dev/null
    # shellcheck disable=SC2046
    kill -9 $(cat ./.temp/tail_stdout_pid 2>/dev/null) 2>/dev/null
    rm -f ./.temp/tail_stderr_pid
    rm -f ./.temp/tail_stdout_pid
    case "$SAM_STATUS" in
    "os") # stdOut Success
        rm -f ./.temp/stderr_op
        ;;
    "oe") # stdOut Error
        # shellcheck disable=SC2046
        kill -2 $(cat ./.temp/sam_pid 2>/dev/null) 2>/dev/null
        rm -f ./.temp/sam_pid
        rm -f ./.temp/stderr_op
        f_rm_sam_container
        DISARM_TRAP=1
        ;;
    "es") # stdErr Success
        rm -f ./.temp/stdout_op
        ;;
    "ee") # stdErr Error
        # shellcheck disable=SC2046
        kill -2 $(cat ./.temp/sam_pid 2>/dev/null) 2>/dev/null
        rm -f ./.temp/sam_pid
        rm -f ./.temp/stdout_op
        f_rm_sam_container
        DISARM_TRAP=1
        ;;
    "to") # TimeOut
        # shellcheck disable=SC2046
        kill -2 $(cat ./.temp/sam_pid 2>/dev/null) 2>/dev/null
        rm -f ./.temp/sam_pid
        f_rm_sam_container
        DISARM_TRAP=1
        ;;
    "tb") # Trap or Build error
        # shellcheck disable=SC2046
        kill -2 $(cat ./.temp/sam_pid 2>/dev/null) 2>/dev/null
        rm -rf ./.temp
        f_rm_sam_container
        ;;
    esac
}

function f_sam_start_api() {
    : 'Starts the API via sam.

    Starts the API via sam and redirects its "stderr" and "stdout" to files so its 
    behavior can be monitored.
    '

    local TEMPLATE_FILE_NOW=""
    if [ -n "$TEMPLATE_FILE" ]; then
        # shellcheck disable=SC2089
        TEMPLATE_FILE_NOW="--template-file \"$TEMPLATE_FILE\""
    fi

    local ENV_VARS_FILE_NOW=""
    if [ -n "$ENV_VARS_FILE" ]; then
        # shellcheck disable=SC2089
        ENV_VARS_FILE_NOW="--env-vars \"$ENV_VARS_FILE\""
    fi

    # NOTE: The "exec" command is a strategy to allow the use of the SIGINT signal
    # (code 2, "Ctrl+c") via a bash script to terminate the sam process. This way,
    # we allow sam to terminate its other processes without having "orphaned" processes.
    # --env-vars ./parameters/dev-params.json \

    # shellcheck disable=SC2086
    # shellcheck disable=SC2090
    exec sam local start-api \
        $TEMPLATE_FILE_NOW \
        $ENV_VARS_FILE_NOW \
        --parameter-overrides Debug="on" \
        --debug-port "$DEGUB_PORT" \
        --warm-containers LAZY \
        --debug-function "$LAMBDA_FUNC_DEBUG" \
        2>./.temp/stderr_op 1>./.temp/stdout_op &
    echo -n $! >./.temp/sam_pid
}

# NOTE: Checks that the build was successful and does not run this script on failure.
f_flow_status "BUILD_SUCCESS"
if [ "$F_FLOW_STATUS" -eq 0 ]; then
    DISARM_TRAP=1
    f_run_clear "tb"
    exit 0
fi

DISARM_TRAP=0

# NOTE: Ensures that the runtime environment is always healthy and clean.
# shellcheck disable=SC2064
trap "f_run_clear \"tb\";exit $EXIT_CODE" EXIT

f_venv_activate
f_sam_start_api

# NOTE: Give the "sam local start-api" command some time to effectively make available
# the output files "./.temp/stderr_op" and "./.temp/stdout_op".
sleep 3

f_tail_stdout &
f_tail_stderr &

SYS_READY_ACTION=1
for ((i = 0; i <= TIMEOUT_SECS; i++)); do
    SAM_STATUS=$(cat ./.temp/sam_status 2>/dev/null)
    case "$SAM_STATUS" in
    "os") # stdOut Success
        f_run_clear "os"

        f_ask_support

        # NOTE: Giving time to the container.
        # shellcheck disable=SC2086
        sleep $WAIT_CONTAINER_SECS

        echo " > ------------------- 
START
SUCCESS
 < ------------------- "
        echo -n "START_SUCCESS" >./.temp/flow_status

        EXIT_CODE=0
        # shellcheck disable=SC2086
        if [ $PERFORM_DEBUG_CALL -eq 1 ]; then
            echo $$ >./.temp/tail_debug_pid
            tail -f ./.temp/stdout_op ./.temp/call_stdout_stderr_op
        else
            echo $$ >./.temp/tail_debug_pid
            tail -f ./.temp/stdout_op
        fi
        ;;
    "oe") # stdOut Error
        f_run_clear "oe"
        EXIT_CODE=1
        echo " > ------------------- 
START
ERROR
< ------------------- "
        tail -f ./.temp/stdout_op
        echo -n "START_ERROR" >./.temp/flow_status
        # exit 1
        break
        ;;
    "es") # stdErr Success
        f_run_clear "es"

        f_ask_support

        # NOTE: Giving time to the container.
        # shellcheck disable=SC2086
        sleep $WAIT_CONTAINER_SECS

        echo " > ------------------- 
START
SUCCESS
 < ------------------- "

        echo -n "START_SUCCESS" >./.temp/flow_status

        EXIT_CODE=0
        # shellcheck disable=SC2086
        if [ $PERFORM_DEBUG_CALL -eq 1 ]; then
            echo $$ >./.temp/tail_debug_pid
            tail -f ./.temp/stderr_op ./.temp/call_stdout_stderr_op
        else
            echo $$ >./.temp/tail_debug_pid
            tail -f ./.temp/stderr_op
        fi
        ;;
    "ee") # stdErr Error
        f_run_clear "ee"
        EXIT_CODE=1
        echo " > ------------------- 
START
ERROR
< ------------------- "
        tail -f ./.temp/stderr_op
        echo -n "START_ERROR" >./.temp/flow_status
        break
        ;;
    "sr" | "er") # stdOut/stdErr Ready
        # shellcheck disable=SC2086
        if [ $SYS_READY_ACTION -eq 1 ]; then
            if [ $PERFORM_DEBUG_CALL -eq 1 ]; then
                echo " > --------------------------------------------------------- 
    Running the \"call.bash\" script.
 < --------------------------------------------------------- "
                # shellcheck disable=SC1091
                source "$SCRIPT_DIR_S/call.bash" >./.temp/call_stdout_stderr_op 2>&1 &
            else
                echo " > --------------------------------------------------------- 
    Make the http request to the \"$LAMBDA_FUNC_DEBUG\" function!
 < --------------------------------------------------------- "
            fi
        fi
        SYS_READY_ACTION=0
        ;;
    esac

    # NOTE: X loops/X seconds.
    sleep 1

    # shellcheck disable=SC2086
    if [ ${i} -ge $TIMEOUT_SECS ]; then
        f_run_clear "to"
        echo " > --------------------------------------------------------- 
    SCRIPT TIMEOUT! ($TIMEOUT_SECS seconds)
    The debugging process starts only after a http request 
    to the \"$LAMBDA_FUNC_DEBUG\" function!
 < --------------------------------------------------------- "
        EXIT_CODE=0
        tail -f ./.temp/stdout_op ./.temp/stderr_op
    fi
done

# exit 0

# [Ref(s).: # https://awstip.com/deploy-a-lambda-layer-and-function-together-via-sam-e95e29194ef7 ,
# https://github.com/aws/aws-sam-cli/issues/1163#issuecomment-514031539 ,
# https://github.com/eduardolucioac/ez_gitea/blob/main/script/ez_gitea.bash ,
# https://medium.com/bip-xtech/a-practical-guide-surviving-aws-sam-part-3-lambda-layers-8a55eb5d2cbe ,
# https://opensource.com/article/20/6/bash-trap ,
# https://serverfault.com/a/903631/276753 ,
# https://stackoverflow.com/a/3786955/3223785 ,
# https://stackoverflow.com/a/44538799/3223785 ,
# https://stackoverflow.com/a/56720474/3223785 ,
# https://stackoverflow.com/a/59461674/3223785 ,
# https://stackoverflow.com/a/67872135/3223785 ,
# https://stackoverflow.com/a/7178916/3223785 ,
# https://stackoverflow.com/a/7287873/3223785 ,
# https://superuser.com/a/900134/195840 ,
# https://tecadmin.net/how-to-run-a-command-on-bash-script-exits/ ,
# https://unix.stackexchange.com/a/275333/61742 ,
# https://unix.stackexchange.com/a/308666/61742 ,
# https://unix.stackexchange.com/a/387329/61742 ]
