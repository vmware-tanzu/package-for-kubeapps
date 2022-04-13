# Kubeapps

Kubeapps is a web-based UI for launching and managing applications on Kubernetes.

[Overview of Kubeapps](https://github.com/vmware-tanzu/kubeapps)

## Components

The Kubeapps application is itself comprised of a number of smaller components:

- The Kubeapps dashboard is the user-interface that runs in the browser.
- The Kubeapps APIs service is the backend which serves requests for the user interface.
- A number of other components, such as nginx, Postgres, oauth2-proxy and Redis are used depending on the configuration.

See [Kubeapps Components](https://github.com/vmware-tanzu/kubeapps/tree/main/docs/reference/developer) in our main documentation for more information.

## Supported Providers

The following table shows the providers this package can work with.

| AWS  | Azure | vSphere | Docker |
|------|-------|---------|--------|
| ✅   | ✅    | ✅      | ✅     |

Although please note that currently Kubeapps can only be run on TCE with token authentication which is appropriate for demonstration purposes only. For more information, please see the relevant [Contour issue #4290](https://github.com/projectcontour/contour/issues/4290)

## Configuration

The configuration for the Kubeapps Carvel package is currently identical to the related Bitnami Helm chart. Please refer to the [configuration options in the Chart readme](https://github.com/vmware-tanzu/kubeapps/tree/main/chart/kubeapps).

Although the configuration options are identical, with TCE the environment into which Kubeapps is installed is different. In particular, when TCE is installed with Contour, certain functionality of Kubeapps is not currently possible. In this environment, Kubeapps can only be used with service-account token authentication, which is suitable for demonstration purposes only. The recommended OpenIDConnect authentication for Kubeapps is not currently possible when using Contour until the fix for [Contour issue #4920](https://github.com/projectcontour/contour/issues/4290) is released.

When running Kubeapps on a cluster with Contour installed, it is possible to use Kubeapps with token authentication together with a [required Contour `HTTPProxy` custom resource](https://github.com/vmware-tanzu/kubeapps/issues/3716#issuecomment-1067532124) that ensures the requests to the Kubeapps backend are routed correctly.

## Installation

   ```shell
   tanzu package install kubeapps \
      --package-name kubeapps.community.tanzu.vmware.com \
      --version ${KUBEAPPS_PACKAGE_VERSION} \
      --
   ```

   > You can get the `${KUBEAPPS_PACKAGE_VERSION}` by running `tanzu
   > package available list kubeapps.community.tanzu.vmware.com`.
   > Specifying a namespace may be required depending on where your package
   > repository was installed.

## Documentation

For Kubeapps-specific documentation, check out
our the main repository
[vmware-tanzu/kubeapps](https://github.com/vmware-tanzu/kubeapps).

Other documentation related to the Carvel package of Kubeapps:

[carvel]: https://carvel.dev/
[kapp-controller]: https://github.com/vmware-tanzu/carvel-kapp-controller
[Tanzu CLI]: https://github.com/vmware-tanzu/tanzu-framework

## Contributing

The package-for-kubeapps project team welcomes contributions from the community. Before you start working with package-for-kubeapps, please
read our [Developer Certificate of Origin](https://cla.vmware.com/dco). All contributions to this repository must be
signed as described on that page. Your signature certifies that you wrote the patch or have the right to pass it on
as an open-source patch. For more detailed information, refer to [CONTRIBUTING.md](CONTRIBUTING.md).

## License

See the [Apache License](./LICENSE)
