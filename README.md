# Part 3 - Supply buildpack for Cloud Foundry sidecars

Cloud Foundry sidecars are an additional process running inside your application container (see [blog post](https://www.cloudfoundry.org/blog/how-to-push-an-app-to-cloud-foundry-with-sidecars/)). Cloud Foundry buildpacks allow the installation of additional software within your application container.

In this sample project, we use a buildpack to install a pre-compiled executable `config-server`, which is run within the  application container as a sidecar.

Run through the demonstration below, and then see the highlights of parts of this repo/buildpack.

## Requirements

This demonstration of sidecars requires a Cloud Foundry running [capi-release](https://github.com/cloudfoundry/capi-release) [`1.79.0`](https://github.com/cloudfoundry/capi-release/releases/tag/1.79.0) or greater (for example [cf-deployment v7.11.0](https://github.com/cloudfoundry/cf-deployment/releases/tag/v7.11.0) or higher).

## Demonstration

```plain
cf v3-create-app app-using-config-server
cf v3-apply-manifest -f fixtures/rubyapp/manifest.yml
cf v3-push app-using-config-server -p fixtures/rubyapp
...
   -----> Installing config-server v0.0.1
...
```

If you view the logs you'll see the sidecar's output and the ruby app's output:

```plain
$ cf logs app-using-config-server --recent
...
[APP/PROC/WEB/SIDECAR/CONFIG-SERVER/0] OUT listening 0.0.0.0:8082...
[APP/PROC/WEB/0] ERR [2019-05-18 02:53:35] INFO  WEBrick 1.3.1
[APP/PROC/WEB/0] ERR [2019-05-18 02:53:35] INFO  ruby 2.4.6 (2019-04-01) [x86_64-linux]
[APP/PROC/WEB/0] ERR [2019-05-18 02:53:35] INFO  WEBrick::HTTPServer#start: pid=16 port=8080
```

**But does it blend?**

If we interact with our main app we see that it can now communicate with its sidecar to get some internally secret configuration.

```plain
$ curl -k https://app-using-config-server.dev.cfdev.sh
Hi, I'm an app with a sidecar!
$ curl -k https://app-using-config-server.dev.cfdev.sh/config
{"Scope":"some-service.admin","Password":"not-a-real-p4$$w0rd"}
```

Obviously this is a silly example. No one put hyphens in their passwords.

## Highlights

Like [sample1-sidecar-buildpack](https://github.com/starkandwayne/part3-sidecar-buildpack), this project is first-and-foremostly a supply buildpack, which also includes an application for dev/testing/demonstration.

Unlike sample1, this project also includes the source code for [`config-server`](src/config-server-sidecar), as well as a script for compilation and storing to an AWS S3 bucket ([`scripts/build_and_upload.sh`](scripts/build_and_upload.sh)).

A supply buildpack can be used in addition to a normal buildpack to inject additional software/libraries/executables/files into the application droplet and runtime containers. This buildpack injects a pre-compiled executable `config-server` into the application droplet, which can then be run as a sidecar by the application.

A supply buildpack needs:

* a [`bin/supply`](bin/supply) file
* to be included in an application's [`manifest.yml`](fixtures/rubyapp/manifest.yml) list of `buildpacks`, but cannot be the last in that list.

Our sample application's `manifest.yml` specifies this buildpack as the first in the list. It references the buildpack by its HTTPS URI to the git repository. It could have also referenced an HTTPS URI to a `.zip` file, or the name of a pre-uploaded buildpack (as found in `cf buildpacks` list).

```yaml
  buildpacks:
  - https://github.com/starkandwayne/part3-sidecar-buildpack
  - ruby_buildpack
```

The `bin/supply` can create/install files into a specific folder. This folder is provided as the first argument when `bin/supply` is executed during staging.

In sample1 we created a silly executable, but in sample2 we are downloading a pre-compiled executable from the Internet. We've stored the URL in [`.downloadurl`](.downloadurl) file.

```shell
curl -sSf $(cat .downloadurl) -o $BUILD_DIR/config-server
chmod +x $BUILD_DIR/config-server
```

In order for this file to exist on the Internet, we added [`scripts/build_and_upload.sh`](scripts/build_and_upload.sh). It builds the Golang project for a 64-bit Linux architecture (to match the Linux containers used by Cloud Foundry).

```shell
cd src/config-server-sidecar
GOOS=linux GOARCH=amd64 go build -o "config-server-v${VERSION}" .
```

It uploads the artifact to an S3 bucket:

```shell
aws s3 cp \
  "src/config-server-sidecar/config-server-v${VERSION}" \
  "s3://${BUCKET}/config-server-sidecar/"
```

Finally, it updates the `.downloadurl` file in the buildpack repo so that the `bin/supply` staging command knowns how to fetch the pre-compiled binary.

The S3 bucket has been made read-only for all files, so that anyone can use this buildpack.

![read-only](https://cl.ly/e7f534258b41/public-read-only-bucket.png)

```json
{
    "Version": "2008-10-17",
    "Statement": [
        {
            "Sid": "AllowPublicRead",
            "Effect": "Allow",
            "Principal": {
                "AWS": "*"
            },
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::sample1-sidecar-buildpack/*"
        }
    ]
}
```

## Thanks

The sample app in `fixtures/rubyapp` and its example of running a fictional `config-server` sidecar originate from https://github.com/cloudfoundry-samples/capi-sidecar-samples/tree/master/sidecar-dependent-app.

The `config-server` executable also comes from the same repo at https://github.com/cloudfoundry-samples/capi-sidecar-samples/tree/master/config-server-sidecar.
