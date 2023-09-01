#!/bin/bash
# shellcheck disable=SC2034

# > -----------------------------------------
# AWS-SAM-VSCODE CONFIGURATION

# Port on which debug service will be available (str).
DEGUB_PORT="5890"

# Lambda function to be debugged (str).
LAMBDA_FUNC_DEBUG="HelloWorldFunction"

# Debugger start timeout (int).
TIMEOUT_SECS=60

# Give time for the sam container to load its services (int).
WAIT_CONTAINER_SECS=5

# Perform a automated HTTP call to the debugged system automatically (int, 0/1).
# Set your HTTP call in the "./.debug/call.bash" file.
PERFORM_DEBUG_CALL=1

# If you use a Python virtualenv (int, 0/1).
# Set your virtualenv activation in the "./.debug/venv.bash" file.
# NOTE: In some cases when the application directory is accessed via bash script
# executed by VSCode the virtualenv does not activate automatically even if this
# is configured.
USE_VENV=1

# If you use a Python "requirements.txt" file and it is not in the project root folder
# or have a different name, inform here (str).
# eg.: PYTHON_REQUIREMENTS="./requirements/requirements-dev.txt"
PYTHON_REQUIREMENTS=""

# If you use an environment variables file (json), inform here (str).
# eg.: ENV_VARS_FILE="./parameters/dev-params.json"
ENV_VARS_FILE=""

# If your "template.yaml" file is not in the project root folder or have a different,
# inform here (str).
# eg.: TEMPLATE_FILE="./template.yaml"
TEMPLATE_FILE=""

# < -----------------------------------------

# I'm just a regular everyday normal guy with bills and family.
# This is an open-source project and will continue to be so forever.
# Please consider to deposit a donation through PayPal 
# ( https://www.paypal.com/donate/?hosted_button_id=TANFQFHXMZDZE ).
# Support free software and my work! ❤️👨‍👩‍👧🐧
# (int, 0/1).
I_SUPPORT_FREE_SOFTWARE_N_THIS_WORK=0

# aws-sam-vscode 🄯 BSD-3-Clause
# Eduardo Lúcio Amorim Costa
# Brazil-DF 🇧🇷
# https://www.linkedin.com/in/eduardo-software-livre/
