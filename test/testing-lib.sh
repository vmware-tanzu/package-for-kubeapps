#! /usr/bin/env bash

# Copyright 2022 the Kubeapps contributors.
# SPDX-License-Identifier: Apache-2.0

set -o errexit
set -o nounset
set -o pipefail

K8S_KIND_VERSION=${K8S_KIND_VERSION:-"1.24.0@sha256:0866296e693efe1fed79d5e6c7af8df71fc73ae45e3679af05342239cdc5bc8e"}
CLUSTER_CONFIG=${CLUSTER_CONFIG:-"/tmp/kubeapps-carvel-e2e"}
CLUSTER_NAME="kubeapps-carvel-e2e"
KAPP_CONTROLLER_VERSION=${KAPP_CONTROLLER_VERSION:-"v0.38.3"}

setup_kind_cluster() {
  echo "Creating Kind cluster '${CLUSTER_NAME}'"
  kind create cluster --image "kindest/node:${K8S_KIND_VERSION}" \
    --name "${CLUSTER_NAME}" \
    --kubeconfig="${CLUSTER_CONFIG}" \
    --retain --wait 120s

  touch "${CLUSTER_CONFIG}"
  echo "Cluster config: ${CLUSTER_CONFIG}"
  local API_SERVER=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "${CLUSTER_NAME}-control-plane")
  API_SERVER="https://$API_SERVER:6443" yq -i eval '.clusters[0].cluster.server = env(API_SERVER)' $CLUSTER_CONFIG
  kubectl --kubeconfig="${CLUSTER_CONFIG}" apply -f "https://github.com/vmware-tanzu/carvel-kapp-controller/releases/download/${KAPP_CONTROLLER_VERSION}/release.yml"

  # It's not enough to wait for the pod to be ready, we need to wait until
  # the carvel data packaging API services is available. Cannot see way to
  # user `kubectl wait` for this either, since no top-level conditions.
  until kubectl --kubeconfig="${CLUSTER_CONFIG}" get apiservices v1alpha1.data.packaging.carvel.dev -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' | grep True ; do
      echo "Waiting for v1alpha1.data.packaging.carvel.dev apiservice to be available..."
      sleep 3 ;
  done
}

delete_kind_cluster() {
  kind delete cluster --name "$CLUSTER_NAME"
}

install_kubeapps() {
    local version=$1

    echo "Installing Kubeapps with Carvel package $version"
    kubectl --kubeconfig="${CLUSTER_CONFIG}" apply \
      -f metadata.yaml \
      -f "$version/package.yaml"

    tanzu package install kubeapps \
      --kubeconfig="${CLUSTER_CONFIG}" \
      --package-name kubeapps.community.tanzu.vmware.com \
      --version "$version" \
      --values-file test/test-values.yaml

    echo "Package install for version '$version' reconciled successfully. Deleting..."
    tanzu package installed delete kubeapps \
      --kubeconfig="${CLUSTER_CONFIG}" \
      --yes
}
