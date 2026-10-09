# ARM64-Docker

ARM64 image based on the official `mysql:8.4` LTS image, with the MySQL server,
MySQL command-line client, and `curl`. It inherits the official image's database
initialization, entrypoint, and default `mysqld` command.

**Behavior change:** this replaces the previous Ubuntu client-only image. Running
the image without a command now starts MySQL, not Bash. The base operating system
is Oracle Linux, not Ubuntu.

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

## Start a MySQL server

There is no built-in password. Before the first start, create a local file named
`mysql.env` with the following contents, replacing both password placeholders
with different strong passwords:

```dotenv
MYSQL_ROOT_PASSWORD=replace-with-a-strong-root-password
MYSQL_DATABASE=appdb
MYSQL_USER=appuser
MYSQL_PASSWORD=replace-with-a-strong-app-password
```

Keep this file private. It is excluded from Git and the Docker build context;
on Linux/macOS, restrict its permissions with `chmod 600 mysql.env`. For
production, use a secret manager or the official image's `MYSQL_ROOT_PASSWORD_FILE`
and `MYSQL_PASSWORD_FILE` variables with mounted secret files instead of a
plaintext environment file.

Start the server:

```bash
docker run -d --name mysql-server --platform linux/arm64 \
  --restart unless-stopped \
  --env-file mysql.env \
  -p 127.0.0.1:3306:3306 \
  --mount type=volume,source=mysql-data,target=/var/lib/mysql \
  ghcr.io/yongjin-tao/arm64-docker:main
```

Docker creates the `mysql-data` named volume if it does not exist. The volume
stores database files outside the container and survives container removal.
Port 3306 is bound only to the Docker host's loopback interface, not exposed to
the local network or internet.

Initialization takes time. Follow the logs and wait for initialization to finish
and the final server to report `ready for connections`:

```bash
docker logs -f mysql-server
```

Press Ctrl+C to stop following the logs; the server continues running.

On the **first start with an empty data directory**, `root` uses
`MYSQL_ROOT_PASSWORD`, and `appuser` uses `MYSQL_PASSWORD` with privileges on
`appdb`. Root is local to the container by default; use `appuser` for connections
from outside it. These environment variables do not reset passwords, create users,
or change databases when the volume already contains an initialized database.
Use SQL account-management commands to change existing passwords.

Do not delete `mysql-data` unless you intend to delete the database. Back up
important data before upgrading the image or changing MySQL versions.

This image targets ARM64. Running it on an x86-64 host requires ARM64 emulation,
such as the support provided by Docker Desktop or a configured QEMU/binfmt setup.

## Connect to MySQL

Use the client already installed in the running server container:

```bash
docker exec -it mysql-server mysql --user=appuser --password appdb
```

Enter the password you set in `MYSQL_PASSWORD` at the prompt. For administrative
tasks, connect locally as root and enter `MYSQL_ROOT_PASSWORD`:

```bash
docker exec -it mysql-server mysql --user=root --password
```

If the MySQL client is installed on your computer, connect through the published
port:

```bash
mysql --host=127.0.0.1 --port=3306 --user=appuser --password appdb
```

You can also use this image as a standalone client for another database:

```bash
docker run --rm -it --platform linux/arm64 \
  ghcr.io/yongjin-tao/arm64-docker:main \
  mysql --host=db.example.com --port=3306 --user=myuser --password
```

The client prompts for the password so it is not included in the command or shell
history. The database must be reachable from the container; `localhost` refers
to the container itself, not the Docker host.

For client access from another container, create a user-defined Docker network
and attach the running server:

```bash
docker network create mysql-network
docker network connect mysql-network mysql-server
```

Start a client on the same network:

```bash
docker run --rm -it --platform linux/arm64 --network mysql-network \
  ghcr.io/yongjin-tao/arm64-docker:main \
  mysql --host=mysql-server --port=3306 --user=appuser --password appdb
```

## Shell and other tools

Open a shell in the running database container:

```bash
docker exec -it mysql-server bash
```

To start a separate temporary shell without starting MySQL, explicitly override
the default command:

```bash
docker run --rm -it --platform linux/arm64 \
  ghcr.io/yongjin-tao/arm64-docker:main bash
```

Run `curl` directly:

```bash
docker run --rm --platform linux/arm64 \
  ghcr.io/yongjin-tao/arm64-docker:main curl --version
```

## Build locally

```bash
docker buildx build --platform linux/arm64 --load -t arm64-docker:local .
bash tests/smoke-test.sh arm64-docker:local
```

`--load` imports the built image into the local Docker image store so it can be
run immediately. Cross-platform builds on an x86-64 host also require ARM64
emulation.

The smoke test requires Bash, Docker, and OpenSSL on the host. It verifies ARM64,
the server/client/tools, root and application-user login, and data persistence
after recreating the container. It uses randomly generated temporary passwords
and removes its own test container and volume. GitHub Actions runs this test
before publishing the image.

To run your locally built server, use the server-start command above with
`arm64-docker:local` in place of the GHCR image name.