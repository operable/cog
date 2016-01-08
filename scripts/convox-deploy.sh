#!/bin/sh

set -e

ENVIRONMENT=${DEPLOY_ENV:="staging"}
APP_NAME="cog"

CONVOX="/app/bin/convox" # From operable-freight

${CONVOX} deploy --app ${APP_NAME}

