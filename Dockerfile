ARG TAG="v1.0.0"
ARG UBI_IMAGE
ARG GOLANG_VERSION
ARG GOBORING_IMAGE=goboring/golang:${GOLANG_VERSION}
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

FROM ${GOBORING_IMAGE} as config-daemon-builder
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
WORKDIR /
COPY centos.repo /etc/yum.repos.d/centos.repo
RUN yum update -y \
    && ARCH_DEP_PKGS=$(if [ "$(uname -m)" != "s390x" ]; then echo -n mstflint ; fi) \
    && yum install -y $ARCH_DEP_PKGS \
    && rm -rf /var/cache/yum
COPY --from=config-daemon-builder /go/sriov-network-operator/build/_output/linux/amd64/sriov-network-config-daemon /usr/bin/
COPY --from=config-daemon-builder /go/sriov-network-operator/build/_output/linux/amd64/plugins /plugins
COPY --from=config-daemon-builder /go/sriov-network-operator/bindata /bindata
ENV PLUGINSPATH=/plugins
ENTRYPOINT ["/usr/bin/sriov-network-config-daemon"]

# Create the webhook image
FROM ${UBI_IMAGE} as webhook
RUN yum update -y && \
    rm -rf /var/cache/yum
WORKDIR /
LABEL io.k8s.display-name="sriov-network-webhook" \
      io.k8s.description="This is an admission controller webhook that mutates and validates customer resources of sriov network operator."
COPY --from=builder /go/sriov-network-operator/build/_output/linux/amd64/webhook /usr/bin/webhook
CMD ["/usr/bin/webhook"]

# Create the operator image
FROM ${UBI_IMAGE} as operator
RUN yum update -y && \
    rm -rf /var/cache/yum
WORKDIR /
COPY --from=builder /go/sriov-network-operator/build/_output/linux/amd64/manager /usr/bin/sriov-network-operator
COPY --from=builder /go/sriov-network-operator/bindata /bindata
ENTRYPOINT ["/usr/bin/sriov-network-operator"]
