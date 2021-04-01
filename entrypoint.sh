#!/bin/bash

set -e

# SELF represents the user visible name of the action.
SELF="auto-go-format"

# GOFMT represents the command to run to format files. The
# given file is substituted for the literal "{FILE}".
GOFMT="go fmt {FILE}"

# log outputs its arguments to the action run log.
log() {
	echo "::set-output name=${SELF}::$*"
}

# err outputs an error message to the action run log.
err() {
	echo "::warning::$*"
}

# die outputs a fatal error message to the action run log.
die() {
	echo "::error::$*"
}

# fmt recieves a file as $1 and formats it in place.
fmt() {
	echo "::group::formatting '$1'"
	echo "${GOFMT}" | sed "s/{FILE}/$1/g" | sh
	echo "::endgroup::"
}

# get retrieves a value from the configured API from the
# resource path $1.
get() {
	echo "set-output name=api::$1"
	curl -X GET -s -H "${AUTH_HEADER}" -H "${API_HEADER}" "${URI}/$1"
}

# parse_user parses the user name from $1 as the user
# data API response.
parse_user() {
	USER_NAME="$(echo "$1" | jq -r ".name")"

	# TODO: if USER_NAME is null something has
	# already gone wrong.
	if [[ "$USER_NAME" == "null" ]]; then
		USER_NAME=$USER_LOGIN
	fi

	echo "${USER_NAME} (Rebase PR Action)"
}

# parse_email parses the user email from $1 as the user
# data API response.
parse_email() {
	USER_EMAIL="$(echo "$1" | jq -r ".email")"

	# TODO: if USER_EMAIL is null something has
	# already gone wrong.
	if [[ "$USER_EMAIL" == "null" ]]; then
		USER_EMAIL="$USER_LOGIN@users.noreply.github.com"
	fi

	echo "$USER_EMAIL"
}

# comment writes $1 as a comment to the current pull request.
comment() {
	PAYLOAD="$(echo '{}' | jq --arg body "$1" '.body = $body')"
	COMMENTS_URL="$(cat /github/workflow/event.json | jq -r .pull_request.comments_url)"

	if [[ "COMMENTS_URL" != null ]]; then
		curl -s -S -H "Authorization: token $GITHUB_TOKEN" --header "Content-Type: application/json" --data "$PAYLOAD" "$COMMENTS_URL" > /dev/null
	else
		err "Couldn't comment: $1"
	fi
}

# config recieves a key as $1 and a value as $2 to set
# the git configuration.
config() {
	echo "::set-output name=config::Setting '$1'"
	git config --global "user.$1" "$2"
}

# checkout changes to (or creates) the branch given as $1.
checkout()  {
	if [[ "$(git branch | grep "$1")" ]]; then
		git checkout "$1"
	else
		git checkout -b "$1"
	fi
}

if [[ -z "$GITHUB_TOKEN" ]]; then
	die "Set the GITHUB_TOKEN env variable."
fi

PR_NUMBER=$(jq --raw-output .pull_request.number "$GITHUB_EVENT_PATH")

log "Collecting information about PR #$PR_NUMBER of $GITHUB_REPOSITORY..."

URI="https://api.github.com"
API_HEADER="Accept: application/vnd.github.v3+json"
AUTH_HEADER="Authorization: token $GITHUB_TOKEN"

PULL_DATA="$(get "/repos/$GITHUB_REPOSITORY/pulls/$PR_NUMBER")"

BASE_REPO="$(echo "$PULL_DATA" | jq -r .base.repo.full_name)"
BASE_BRANCH="$(echo "$PULL_DATA" | jq -r .base.ref)"

if [[ -z "$BASE_BRANCH" ]]; then
	echo "Cannot get base branch information for PR #$PR_NUMBER!"
	echo "API response: $PULL_DATA"
	exit 1
fi

USER_LOGIN="$(jq -r ".pull_request.user.login" "$GITHUB_EVENT_PATH")"

USER_DATA="$(get "/users/${USER_LOGIN}")"

HEAD_REPO="$(echo "$PULL_DATA" | jq -r .head.repo.full_name)"
HEAD_BRANCH="$(echo "$PULL_DATA" | jq -r .head.ref)"

log "Base branch for PR #$PR_NUMBER is $BASE_BRANCH"

USER_TOKEN=${USER_LOGIN}_TOKEN
COMMITTER_TOKEN=${!USER_TOKEN:-$GITHUB_TOKEN}

git remote set-url origin https://x-access-token:$COMMITTER_TOKEN@github.com/$GITHUB_REPOSITORY.git

config name  "$(parse_user  "$USER_DATA")"
config email "$(parse_email "$user_resp")"

git remote add fork https://x-access-token:$COMMITTER_TOKEN@github.com/$HEAD_REPO.git

set -o xtrace

# make sure branches are up-to-date
git fetch origin $BASE_BRANCH
git fetch fork $HEAD_BRANCH

checkout "$HEAD_BRANCH"

URL="https://api.github.com/repos/${BASE_REPO}/pulls/${PR_NUMBER}/files"
FILES=$(curl -s -X GET -G $URL | jq -r '.[] | .filename')
declare -i count=0
declare -i ZERO=0

for FILE in $FILES; do
	if [[ "${FILE##*.}" = "go" && -f $FILE ]]; then
		count=$((count+1))
		fmt "${FILE}"
	fi
done

if [[ $count -eq $ZERO ]]; then
	err "You do not have any go files to format"
	exit $SUCCESS
fi

# Post results back as comment.
if [[ `git status --porcelain` ]]; then
	git status
	git add .
	git commit -m "Formatting files"
	git push -f fork $HEAD_BRANCH

	comment ":rocket: Your go files have been formatted successfully"
else
	comment ":heavy_check_mark: That is a perfectly formatted change."
fi

exit $SUCCESS
