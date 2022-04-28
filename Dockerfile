FROM golang:alpine

LABEL version="0.0.1"
LABEL repository="https://github.com/sladyn98/auto-go-format"
LABEL homepage="https://github.com/sladyn98/auto-go-format"
LABEL maintainer="sladyn98"
LABEL "com.github.actions.name"="Golang Formatter"
LABEL "com.github.actions.description"="Automatically formats golang files in pull requests"
LABEL "com.github.actions.icon"="git-pull-request"
LABEL "com.github.actions.color"="blue"

RUN apk --no-cache add jq bash curl git git-lfs
RUN GO111MODULE=on go install mvdan.cc/gofumpt
ADD entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
