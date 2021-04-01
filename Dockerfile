FROM golang:alpine

LABEL version="0.0.3" \
    repository="https://github.com/yuri-norwood/auto-go-format" \
    homepage="https://github.com/yuri-norwood/auto-go-format" \
    maintainer="yuri-norwood" \
    "com.github.actions.name"="Golang Formatter" \
    "com.github.actions.description"="Automatically formats golang files in pull requests" \
    "com.github.actions.icon"="git-pull-request" \
    "com.github.actions.color"="blue"

RUN apk --no-cache add jq bash curl git git-lfs
ADD entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
