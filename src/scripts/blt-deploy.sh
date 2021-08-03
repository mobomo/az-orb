#!/bin/bash
set -eu

# VARS EVAL.
TAG_TO_DEPLOY=$(eval echo "$TAG")

# Determine azure environment, since az user/keys are per env.
get-azure-key() {
  local -n AZURE_KEY="$1"
  if [[ -n ${AZURE_KEY_DEV} && -n ${AZURE_KEY_TEST} ]]; then
    case "$AZ_ENV" in
      dev)
          AZURE_KEY=${AZURE_KEY_DEV};;
      test)
          AZURE_KEY=${AZURE_KEY_TEST};;
      prod)
          AZURE_KEY=${AZURE_KEY_PROD};;
      *)
          export AZURE_KEY=""
          echo "Provided $AZ_ENV is not a recognized Env."
          exit 1
          ;;
    esac
  else
    echo "Please set the AZ User key as an env variable for all your envs. IE: AZURE_KEY_DEV and AZURE_KEY_TEST".
  fi
}

# Info
echo "Tag to deploy to ${AZ_ENV}: $TAG_TO_DEPLOY"

deploy-tag-az() {
  local AZURE_ENV_KEY=''
  get-azure-key AZURE_ENV_KEY

  if [[ -n ${TAG_TO_DEPLOY} && -n ${AZURE_ENV_KEY} ]]; then
    echo "Deploying $TAG_TO_DEPLOY to AZ ${AZ_ENV}..."
    curl -s -u "${AZ_USER}":"${AZURE_ENV_KEY}" -X POST \
      -H 'Content-Type: application/json' \
      -d '{"scope": "sites", "sites_ref": "tags/'"${TAG_TO_DEPLOY}"'", "sites_type": "'"${DEPLOY_TYPE}"'", "stack_id": 1}' \
      https://www."${AZ_ENV}"-"${AZ_SITE}".acsitefactory.com/api/v1/update
    printf "\n"
    ## @to-do: use jq to read response and exit with 1 and error message if 'message' contains Bad Request/Error, etc...
  else
    printf "ERROR: tag and AZURE_KEY_[ENV] env variable are required. \nPlease make sure your job is passing the required params and required environment variables are set\n"
  fi
}
deploy-tag-az
# Exporting varibles for Slack messages.
echo "export AZ_ENV=$AZ_ENV" >> "$BASH_ENV"
echo "export TAG_TO_DEPLOY=$TAG_TO_DEPLOY" >> "$BASH_ENV"