ARG UBI_IMAGE
ARG HARDENED_IMAGE

FROM ${HARDENED_IMAGE} as base-builder
ARG TAG
ARG BUILD
ENV VERSION_OVERRIDE=${TAG}${BUILD}
COPY patch patch
RUN git clone --depth 1 --branch ${TAG} https://github.com/k8snetworkplumbingwg/sriov-network-operator \
    && cd sriov-network-operator \ 
    && git apply ../patch/* \
    && make clean

FROM base-builder as builder
ENV CGO_ENABLED=0
RUN cd sriov-network-operator \
    && make _build-manager \
    && make _build-webhook

FROM buildpack-deps:buster-scm as goboring-image
ARG ARCH=amd64
ARG GO_VERSION="1.16.6"
ARG BORING_VERSION=7
# gcc for cgo
RUN apt-get update && apt-get install -y --no-install-recommends \
                g++ \
                gcc \
                libc6-dev \
                make \
                pkg-config \
        && rm -rf /var/lib/apt/lists/*
ENV GOLANG_VERSION=${VERSION}b${BORING_VERSION}
RUN set -eux; \
        \
        url="https://golang.org/dl/go${GO_VERSION}.linux-${ARCH}.tar.gz"; \
        wget -O go.tgz "$url"; \
        tar -C /usr/local -xzf go.tgz; \
        rm go.tgz; \
        \
        export PATH="/usr/local/go/bin:$PATH"; \
        go version
ENV GOPATH /go
ENV PATH $GOPATH/bin:/usr/local/go/bin:$PATH
RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 777 "$GOPATH"
WORKDIR $GOPATH

FROM goboring-image as config-daemon-builder
ARG TAG
ARG BUILD
ENV VERSION_OVERRIDE=${TAG}${BUILD}
ENV GOFLAGS=-trimpath
COPY --from=base-builder /go/sriov-network-operator /go/sriov-network-operator
RUN cd sriov-network-operator \
    && make _build-sriov-network-config-daemon \
    && make plugins

# Create the config daemon image
FROM ${UBI_IMAGE} as config-daemon
ARG ARCH="amd64"
WORKDIR /
COPY centos.repo /etc/yum.repos.d/centos.repo
RUN yum update -y \
    && ARCH_DEP_PKGS=$(if [ "$(uname -m)" != "s390x" ]; then echo -n mstflint ; fi) \
    && yum install -y $ARCH_DEP_PKGS \
    && rm -rf /var/cache/yum
COPY --from=config-daemon-builder /go/sriov-network-operator/build/_output/linux/${ARCH}/sriov-network-config-daemon /usr/bin/
COPY --from=config-daemon-builder /go/sriov-network-operator/build/_output/linux/${ARCH}/plugins /plugins
COPY --from=config-daemon-builder /go/sriov-network-operator/bindata /bindata
ENV PLUGINSPATH=/plugins
ENTRYPOINT ["/usr/bin/sriov-network-config-daemon"]

# Create the webhook image
FROM ${UBI_IMAGE} as webhook
ARG ARCH="amd64"
RUN yum update -y && \
    rm -rf /var/cache/yum
WORKDIR /
LABEL io.k8s.display-name="sriov-network-webhook" \
      io.k8s.description="This is an admission controller webhook that mutates and validates customer resources of sriov network operator."
COPY --from=builder /go/sriov-network-operator/build/_output/linux/${ARCH}/webhook /usr/bin/webhook
CMD ["/usr/bin/webhook"]

# Create the operator image
FROM ${UBI_IMAGE} as operator
ARG ARCH="amd64"
RUN yum update -y && \
    rm -rf /var/cache/yum
WORKDIR /
COPY --from=builder /go/sriov-network-operator/build/_output/linux/${ARCH}/manager /usr/bin/sriov-network-operator
COPY --from=builder /go/sriov-network-operator/bindata /bindata
ENTRYPOINT ["/usr/bin/sriov-network-operator"]
