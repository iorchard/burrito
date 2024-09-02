#!/bin/bash

# check gh command is available.
if [[ ! -f $(type -p gh) ]]; then
  echo "Abort) gh command is not found."
  exit 1
fi
# check jq command is available.
if [[ ! -f $(type -p jq) ]]; then
  echo "Abort) jq command is not found."
  exit 1
fi

MILESTONE_URL_PATH="/repos/iorchard/burrito/milestones"
#JQ_OPTS="--monochrome-output"
JQ_OPTS=
function create() {
  gh api --method POST -H "Accept: application/vnd.github.v3+json" \
    ${MILESTONE_URL_PATH} \
    -f title="$1" -f state='open' -f description="$1 milestone"
}
function delete() {
  # get number from the title
  NO=$(gh api --method GET -H "Accept: application/vnd.github.v3+json" \
    ${MILESTONE_URL_PATH} | \
    jq  --arg TITLE "$1" '.[] | select(.title==$TITLE) | .number')
  gh api --method DELETE -H "Accept: application/vnd.github.v3+json" \
    ${MILESTONE_URL_PATH}/${NO}
}
function list() {
  gh api --method GET -H "Accept: application/vnd.github.v3+json" \
    ${MILESTONE_URL_PATH} | \
    jq $JQ_OPTS -r '(["NAME", "STATE", "OPEN", "CLOSED", "CREATED"] | (., map(length*"-"))), (.[] | [.title, .state, .open_issues, .closed_issues, .created_at]) | @tsv'
#    ${MILESTONE_URL_PATH} | jq '.[].title'
}
function USAGE() {
  echo "USAGE: $0 [-h|-d|-u]" 1>&2
  echo
  echo " -h --help                  Display this help message."
  echo " create MILESTONE           Create a milestone."
  echo " delete MILESTONE           Delete a milestone."
  echo " list                       List milestones."
  echo
}

if [ $# -lt 1 ]; then
  USAGE
  exit 1
fi

ACTION=$1
shift
while true
do
  case "$ACTION" in
    -h | --help)
      USAGE
      exit 0
      ;;
    create)
      create "$@"
      break
      ;;
    delete)
      delete "$@"
      break
      ;;
    list)
      list
      break
      ;;
    *)
      echo "Error: unknown option: $OPT" 1>&2
      echo
      USAGE
      exit 1
      ;;
  esac
done
