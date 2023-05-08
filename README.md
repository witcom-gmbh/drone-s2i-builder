# Drone.io plugin to build images with s2i

[Source to image](https://github.com/openshift/source-to-image), aka "s2i", is a Red Hat project originaly created to build images from sources without the need of a Dockerfile, made for Openshit/OKD (see https://www.openshift.com/ and the community version https://www.okd.io/). It is possible to create multi-stage or "chained" images, to create runtime-images with a small footprint. 

[Drone](https://drone.io) is a CI/CD solution that can run on Docker and Kubernetes.

To be able to have the same build solution, you need this plugin.

**Before using this plugin**, please make sure that you know how is working "source to image".

## Usage

In your .drone.yml file, you can use `some-repo/drone-s2i-builder` - you can use these paramters:

- `builder_image` (mandatory) is the "s2i" image that is used to build the sources
- `push` (boolean, default to false) will push your image to `target_image` after the build
- `target_image` (mandatory if `push` is true) is the target-image that is created the s2i build-process 
- `source` (defaults to DRONE_WORKSPACE_BASE) Path to the sources. 
- `extract` (boolean, default to false) will extract parts of the built-image to a `cache_dir` directory
- `extract_path` (mandatory if `extract` is true) is the path of the build-output image that will be extracted 
- `cache_dir` (mandatory if `extract` is true) is the temporary path where `extract_path` will be stored
- `context` (string, default to "./") is the context directory inside your repository
- `registry` is the registry you want to login (login not yet supported)
- `insecure` (boolean, default to false) to use the `registry` as "insecure" (http instead of https)
- `username` if set with `password`, try to authenticate `registry` with that user
- `password` is the password used to authenticate user 
- `cert` (optional) is the base64 encoded certificate to write in `/etc/docker/certs.d/${registry}/ca.crt` where `registry` is the corresponding parameter. One more time, please use a secret to store the certificate.

The following example will perform a multi-stage build with s2i. 

* First step: Build Angular webapp with node-js s2i image and extract the comiled output to a temporary directory which is shared in the pipeline
* Second step: Take the build-output of the first step as input for another s2i step that build a nginx-image with the compiled application

It is easy to add intermediate steps that perform some actions with the extracted code

```yaml
kind: pipeline
name: default

steps:
  - name: s2i-build-angular
    image: some-repo/drone-s2i-builder:latest
    volumes:
    - name: cache
      path: /drone/cache
    pull: always
    settings:
      builder_image: registry.access.redhat.com/ubi8/nodejs-16-minimal:1-14 
	  extract: true
	  extract_path: /opt/app-root/src/dist/my-app
	  cache_dir: /drone/cache
      target: docker-registry:5000/witcom/webapp
  - name: s2i-build-nginx
    image: some-repo/drone-s2i-builder:latest
    volumes:
    - name: cache
      path: /drone/cache
    pull: always
    settings:
      builder_image: registry.access.redhat.com/ubi9/nginx-120
	  push: true
	  source: /drone/cache
      target_image: docker-registry:5000/witcom/webapp
      tags:
        - latest
        - ${DRONE_TAG}
      user:
        from_secret: registry-username
      password:
        from_secret: registry-password

volumes:
- name: cache
  temp: {}

```

## Privileged mode

As we need docker daemon to be launched, you'll need to use "`privileged: true`". That means that the repository should be trusted.

To avoid that, you can add the plugin to `DRONE_RUNNER_PRIVILEGED_IMAGES`:

```
DRONE_RUNNER_PRIVILEGED_IMAGES=plugins/docker,plugins/ecr,metal3d/drone-plugin-s2i
```

That way, you will not need to set privileged mode, and others users will be able to build images with s2i.