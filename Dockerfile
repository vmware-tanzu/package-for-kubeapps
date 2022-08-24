# Copyright 2022 the Kubeapps contributors.
# SPDX-License-Identifier: Apache-2.0

FROM bitnami/node:16.17.0

ARG KIND_VERSION="v0.14.0"
ARG YQ_VERSION="v4.27.2"
ARG TANZU_FRAMEWORK_VERSION="v0.25.0"
ARG HELM_VERSION="v3.9.3"
ARG DOCKER_CE_VERSION="5:20.10.17~3-0~debian-bullseye"
ARG CONTAINERD_VERSION="1.6.7-1"
ARG KUBECTL_VERSION="1.25.0-00"

# Dependencies
RUN apt-get -y update && apt-get install --yes wget curl jq perl apt-transport-https ca-certificates gnupg2 software-properties-common && \
        update-ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src

# Install Bitnami's Readme generator
RUN git clone --single-branch --no-tags https://github.com/bitnami-labs/readme-generator-for-helm readmenator
RUN cd ./readmenator && npm install
RUN npm install --global --only=production ./readmenator

# Install Carvel toolset
RUN bash -c "set -eo pipefail; wget -O- https://carvel.dev/install.sh | bash"

# Install yq
RUN wget "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64.tar.gz" -O - | tar xz && mv yq_linux_amd64 /usr/local/bin/yq

# Install Helm
RUN wget "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz" -O - | tar xz && mv linux-amd64/helm /usr/local/bin/

# Install Docker
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -
RUN add-apt-repository "deb [arch=$(dpkg --print-architecture)] https://download.docker.com/linux/debian bullseye stable"
RUN apt-get update && apt-get install --yes docker-ce=${DOCKER_CE_VERSION} docker-ce-cli=${DOCKER_CE_VERSION} containerd.io=${CONTAINERD_VERSION}

# Install Kind
RUN wget "https://kind.sigs.k8s.io/dl/$KIND_VERSION/kind-$(uname)-$(dpkg --print-architecture)" -O /usr/local/bin/kind
RUN chmod +x /usr/local/bin/kind

# Install kubectl
RUN curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
RUN echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | \
        tee /etc/apt/sources.list.d/kubernetes.list
RUN apt-get update && apt-get install --yes kubectl=${KUBECTL_VERSION}

# Install Tanzu CLI
RUN wget "https://github.com/vmware-tanzu/tanzu-framework/releases/download/${TANZU_FRAMEWORK_VERSION}/tanzu-cli-linux-amd64.tar.gz"
RUN mkdir tanzu && tar -zxvf tanzu-cli-linux-amd64.tar.gz -C tanzu
RUN install tanzu/${TANZU_FRAMEWORK_VERSION}/tanzu-core-linux_amd64 /usr/local/bin/tanzu
RUN wget "https://github.com/vmware-tanzu/tanzu-framework/releases/download/${TANZU_FRAMEWORK_VERSION}/tanzu-framework-plugins-standalone-linux-amd64.tar.gz"
RUN mkdir tanzu-plugins && tar -zxvf tanzu-framework-plugins-standalone-linux-amd64.tar.gz -C tanzu-plugins
ENV TANZU_CLI_NO_INIT=true
RUN tanzu plugin install --local ./tanzu-plugins/standalone-plugins package

WORKDIR /usr/src/packager
ENTRYPOINT [ "/bin/bash" ]
