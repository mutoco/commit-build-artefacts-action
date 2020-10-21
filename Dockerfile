FROM debian:stable-slim

LABEL "name"="commit-build-artefacts-action"
LABEL "maintainer"="Roman Schmid <bummzack@gmail.com>"
LABEL "version"="0.1.0"

RUN apt-get update && \
    apt-get install --no-install-recommends -y rsync zip jq findutils curl ca-certificates
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
