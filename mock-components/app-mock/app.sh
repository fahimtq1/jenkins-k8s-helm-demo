#!/bin/bash
#
# Mock DTA script for the Jenkins pipeline demo.
# It simulates the 'stage' and 'commit' commands.
#
# Location on Jenkins Agent: /opt/test-dta/tools/dta.sh

# --- Configuration ---
LOG_FILE="/opt/test-dta/dta_mock_log.txt"
STAGED_DIR="/opt/test-dta/staged"
# --- End Configuration ---

# Get command-line arguments
COMMAND=$1
ARG1=$2

# Function to write log messages
log_message() {
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$TIMESTAMP] $1" >> "${LOG_FILE}"
}

echo "Mock DTA Executed with: command='${COMMAND}', arg1='${ARG1}'"
log_message "Received command: '${COMMAND}' with argument '${ARG1}'"

# --- Command Logic ---
case "${COMMAND}" in
    stage)
        if [ -z "${ARG1}" ]; then
            echo "ERROR: 'stage' command requires a source directory path."
            log_message "ERROR: 'stage' command received no source path."
            exit 1
        fi
        echo "Simulating DTA stage for source: '${ARG1}'"
        mkdir -p "${STAGED_DIR}/$(date +%Y%m%d)"
        # In a real scenario, you might copy files here. For the mock, we just log it.
        log_message "SUCCESS: Staged content from source '${ARG1}'"
        ;;

    commit)
        if [ "${ARG1}" != "cks" ]; then
            echo "ERROR: 'commit' command only supports 'cks' component for this mock."
            log_message "ERROR: 'commit' received unknown component '${ARG1}'"
            exit 1
        fi
        echo "Simulating DTA commit for component: ${ARG1}"
        log_message "SUCCESS: Committed component '${ARG1}'. Mock version is now 2.0."
        ;;

    listrevisions)
        if [ "${ARG1}" != "cks" ]; then
            echo "ERROR: 'listrevisions' command only supports 'cks' component for this mock."
            log_message "ERROR: 'listrevisions' received unknown component '${ARG1}'"
            exit 1
        fi
        echo "Simulating DTA listrevisions for cks. Current mock version: 2.0-test"
        log_message "SUCCESS: Listed revisions for '${ARG1}'."
        ;;

    rollback)
        if [ "${ARG1}" != "cks" ]; then
            echo "ERROR: 'rollback' command only supports 'cks' component for this mock."
            log_message "ERROR: 'rollback' received unknown component '${ARG1}'"
            exit 1
        fi
        echo "Simulating DTA rollback for component: ${ARG1}"
        log_message "SUCCESS: Rolled back component '${ARG1}'. Mock version is now 1.0."
        ;;

    *)
        echo "ERROR: Unknown DTA command '${COMMAND}'"
        log_message "ERROR: Received unknown command '${COMMAND}'"
        exit 1
        ;;
esac

exit 0