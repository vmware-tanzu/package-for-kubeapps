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

  # It's not enough to wait for the pod to be ready, we need to wait until
  # the carvel data packaging API services is available. Cannot see way to
  # user `kubectl wait` for this either, since no top-level conditions.
  until kubectl get apiservices v1alpha1.data.packaging.carvel.dev -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' | grep True ; do
      echo "Waiting for v1alpha1.data.packaging.carvel.dev apiservice to be available..."
      sleep 3 ;
  done
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
