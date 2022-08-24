# Copyright 2022 the Kubeapps contributors.
# SPDX-License-Identifier: Apache-2.0

FROM node:bullseye

ARG KIND_VERSION="v0.14.0"
ARG YQ_VERSION="v4.27.2"
ARG TANZU_FW_VERSION="v0.25.0"

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
RUN wget "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64.tar.gz" -O - | tar xz && mv yq_linux_amd64 /usr/bin/yq

# Install Helm
RUN curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | tee /usr/share/keyrings/helm.gpg > /dev/null
RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | \
        tee /etc/apt/sources.list.d/helm-stable-debian.list
RUN apt-get update && apt-get install --yes helm

# Install Docker
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -
RUN add-apt-repository "deb [arch=$(dpkg --print-architecture)] https://download.docker.com/linux/debian bullseye stable"
RUN apt-get update && apt-get install --yes docker-ce docker-ce-cli containerd.io

# Install Kind
RUN wget "https://kind.sigs.k8s.io/dl/$KIND_VERSION/kind-$(uname)-$(dpkg --print-architecture)" -O /usr/local/bin/kind
RUN chmod +x /usr/local/bin/kind
RUN kind --version

# Install kubectl
RUN curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
RUN echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | \
        tee /etc/apt/sources.list.d/kubernetes.list
RUN apt-get update && apt-get install --yes kubectl

# Install Tanzu CLI
RUN wget "https://github.com/vmware-tanzu/tanzu-framework/releases/download/${TANZU_FW_VERSION}/tanzu-cli-linux-amd64.tar.gz"
RUN mkdir tanzu && tar -zxvf tanzu-cli-linux-amd64.tar.gz -C tanzu
RUN install tanzu/${TANZU_FW_VERSION}/tanzu-core-linux_amd64 /usr/local/bin/tanzu
RUN wget "https://github.com/vmware-tanzu/tanzu-framework/releases/download/${TANZU_FW_VERSION}/tanzu-framework-plugins-standalone-linux-amd64.tar.gz"
RUN mkdir tanzu-plugins && tar -zxvf tanzu-framework-plugins-standalone-linux-amd64.tar.gz -C tanzu-plugins
ENV TANZU_CLI_NO_INIT=true
RUN tanzu plugin install --local ./tanzu-plugins/standalone-plugins package

WORKDIR /usr/src/packager
ENTRYPOINT [ "/bin/bash" ]
