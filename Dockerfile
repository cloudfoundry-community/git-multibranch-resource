FROM gliderlabs/alpine:3.3

ENV LANG C

RUN apk add --no-cache curl bash git redis jq openssh perl

RUN git config --global user.name "Concourse CI GIT Resource" \
 && git config --global user.email "git.concourse-ci@localhost"

ADD assets/ /opt/resource/
RUN chmod +x /opt/resource/*

ADD test/ /opt/resource-tests/
RUN /opt/resource-tests/all.sh \
 && rm -rf /tmp/*
