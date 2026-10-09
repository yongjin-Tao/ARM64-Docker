# ARM64-Docker

ARM64 Ubuntu image with `curl` and the MySQL command-line client.

## Pull the image

After the GitHub Actions workflow successfully publishes a build from `main`,
pull the image from GitHub Container Registry:

```bash
docker pull --platform linux/arm64 ghcr.io/yongjin-tao/arm64-docker:main
```

The workflow publishes branch tags such as `main`, version tags such as `1.2.3`
and `1.2` when a `v1.2.3` Git tag is pushed, and short commit tags prefixed with
`sha-`. Pull requests build the image without publishing it. Use `:main` for
the main branch; a `:latest` tag is not guaranteed for branch builds.

If the package is private, authenticate with `docker login ghcr.io` using your
GitHub username and a personal access token (classic) with `read:packages`
permission and access to the package. Enter the token at the password prompt.

## Run the image

Start an interactive Bash shell:

```bash
docker run --rm -it --platform linux/arm64 ghcr.io/yongjin-tao/arm64-docker:main
```

Run a command directly, for example:

```bash
docker run --rm --platform linux/arm64 \
  ghcr.io/yongjin-tao/arm64-docker:main curl --version
```

This image targets ARM64. Running it on an x86-64 host requires ARM64 emulation,
such as the support provided by Docker Desktop or a configured QEMU/binfmt setup.

## Connect to MySQL

The image contains a MySQL-compatible command-line client, not a database server.
Replace the host and username below with your database connection details:

```bash
docker run --rm -it --platform linux/arm64 \
  ghcr.io/yongjin-tao/arm64-docker:main \
  mysql --host=db.example.com --port=3306 --user=myuser --password
```

The client prompts for the password so it is not included in the command or shell
history. The database must be reachable from the container; `localhost` refers
to the container itself, not the Docker host.

For a MySQL server in another container, attach the client to the server's
user-defined Docker network and use the server's container name as the host:

```bash
docker run --rm -it --platform linux/arm64 --network my-network \
  ghcr.io/yongjin-tao/arm64-docker:main \
  mysql --host=mysql-server --port=3306 --user=myuser --password
```

Replace `my-network` and `mysql-server` with the existing network and server
container names.

## Build locally

```bash
docker buildx build --platform linux/arm64 --load -t arm64-docker:local .
docker run --rm -it --platform linux/arm64 arm64-docker:local
```

`--load` imports the built image into the local Docker image store so it can be
run immediately. Cross-platform builds on an x86-64 host also require ARM64
emulation.