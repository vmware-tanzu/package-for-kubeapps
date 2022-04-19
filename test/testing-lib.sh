#! /usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

K8S_KIND_VERSION=${K8S_KIND_VERSION:-"1.21.1@sha256:69860bda5563ac81e3c0057d654b5253219618a22ec3a346306239bba8cfa1a6"}
CLUSTER_CONFIG=${CLUSTER_CONFIG:-"/tmp/kubeapps-carvel-e2e"}
KAPP_CONTROLLER_VERSION=${KAPP_CONTROLLER_VERSION:-"v0.32.0"}

setup_kind_cluster() {
  kind create cluster --image "kindest/node:${K8S_KIND_VERSION}" \
    --name kubeapps-carvel-e2e \
    --kubeconfig="${CLUSTER_CONFIG}" \
    --retain --wait 120s

  touch "${CLUSTER_CONFIG}"
  echo "Cluster config: ${CLUSTER_CONFIG}"
  kubectl --kubeconfig="${CLUSTER_CONFIG}" apply -f "https://github.com/vmware-tanzu/carvel-kapp-controller/releases/download/${KAPP_CONTROLLER_VERSION}/release.yml"

  # TODO: Need to wait until CR is being recognised, otherwise get the
  # following when installing kubeapps.
  # unable to recognize "metadata.yaml": no matches for kind "PackageMetadata" in version "data.packaging.carvel.dev/v1alpha1"
  # unable to recognize "8.0.10-dev1/package.yaml": no matches for kind "Package" in version "data.packaging.carvel.dev/v1alpha1"
  # Error 1 occurred on 1. View logs in /tmp/package-kubeapps-version.log
}

delete_kind_cluster() {
  kind delete cluster --name kubeapps-carvel-e2e
}

install_kubeapps() {
    local version=$1
    kubectl --kubeconfig="${CLUSTER_CONFIG}" apply \
      -f metadata.yaml \
      -f "$version/package.yaml"

    tanzu package install kubeapps \
      --kubeconfig="${CLUSTER_CONFIG}" \
      --package-name kubeapps.community.tanzu.vmware.com \
      --version "$version" \
      --values-file test/test-values.yaml

    echo "Package install reconciled successfully. Deleting..."
    tanzu package installed delete kubeapps \
      --kubeconfig="${CLUSTER_CONFIG}" \
      --yes
}