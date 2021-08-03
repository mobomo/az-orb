#!/bin/bash
set -eu

# VARS EVAL.
TAG_TO_DEPLOY=$(eval echo "$TAG")
JIRA_TOKEN=$(eval echo "$JIRA_AUTH_TOKEN")

# Determine azure environment, since az user/keys are per env.
get-azure-key() {
  local AZURE_KEY
  if [[ -n ${AZURE_KEY_DEV} && -n ${AZURE_KEY_UAT} ]]; then
    case "$AZ_ENV" in
      dev)
          AZURE_KEY=${AZURE_KEY_DEV};;
      uat)
          AZURE_KEY=${AZURE_KEY_UAT};;
      stage)
          AZURE_KEY=${AZURE_KEY_STAGE};;
      prod)
          AZURE_KEY=${AZURE_KEY_PROD};;
      *)
          AZURE_KEY=null
          echo "Provided $AZ_ENV is not a recognized Env."
          ;;
    esac
    echo "$AZURE_KEY"
  else
    echo "Please set the AZ User key as an env variable for all your envs. IE: AZURE_KEY_DEV and AZURE_KEY_TEST".
  fi
}

# Get the current tag deployed on az env.
get-current-tag() {
  local AZURE_KEY
  AZURE_KEY=$(get-azure-key)
  curl -s -X GET https://www."${AZ_ENV}"-"${AZ_SITE}".acsitefactory.com/api/v1/vcs?type="sites" \
    -u "${AZ_USER}":"${AZURE_KEY}" | jq -r '.current' | sed 's/tags\///'

}
CURRENT_TAG=$(get-current-tag)
echo "Current Tag on ${AZ_ENV}: $CURRENT_TAG"

# With the the current tag, get a list of issues IDs that were committed between current and latest.
get-jira-issues() {
  local JIRA_ISSUES
  if [ -n "${CURRENT_TAG}" ]; then
    JIRA_ISSUES=$(git log "${CURRENT_TAG}".."${TAG_TO_DEPLOY}" | grep -e '[A-Z]\+-[0-9]\+' -o | sort -u | tr '\n' ',' | sed '$s/,$/\n/')
    echo "$JIRA_ISSUES"
  else
    echo "We were not able to get current tag deployed to AZ Env. Please check the 'az-' parameters are correctly set."
  fi
}

# Jira API call to transition the issues.
transition-issues() {
  JIRA_ISSUES=$(get-jira-issues)
  if [ -n "${JIRA_ISSUES}" ]; then
    echo "Included tickets between ${CURRENT_TAG} and ${TAG_TO_DEPLOY}: ${JIRA_ISSUES}"
    echo "export JIRA_ISSUES=$(get-jira-issues)" >> "$BASH_ENV"
    for issue in ${JIRA_ISSUES//,/ }
      do
        echo "Transitioning $issue..."
        ## Transition to "Deployed to ${AZ_ENV}".
        curl \
          -X POST \
          -H "Authorization: Basic ${JIRA_TOKEN}" \
          -H "Content-Type: application/json" \
          --data '{"transition": { "id": "'"${JIRA_TRANS_ID}"'" }}' \
          "${JIRA_URL}"/rest/api/2/issue/"$issue"/transitions
      done
  else
    echo "There are no issues to transition."
    echo 'export JIRA_ISSUES="No Tickets"' >> "$BASH_ENV"
  fi
}
transition-issues