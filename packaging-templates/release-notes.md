## Manual installation without repository

You can download the metadata.yaml and package.yaml and apply them to your cluster (with kapp-controller installed) with:

```bash
kubectl apply -n kapp-controller-packaging-global -f metadata.yaml -f package.yaml
```

You can then install with:

```
tanzu package install kubeapps --package-name kubeapps.community.tanzu.vmware.com --version VERSION
```

where VERSION is the version specified in the `package.yaml`.
