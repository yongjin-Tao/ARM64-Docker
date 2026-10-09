#!/usr/bin/env bash
set -euo pipefail

image="${1:?Usage: bash tests/smoke-test.sh IMAGE}"
suffix="$(openssl rand -hex 8)"
container="arm64-mysql-test-$suffix"
volume="arm64-mysql-test-data-$suffix"
MYSQL_ROOT_PASSWORD="$(openssl rand -hex 24)"
MYSQL_PASSWORD="$(openssl rand -hex 24)"
export MYSQL_ROOT_PASSWORD MYSQL_PASSWORD

cleanup() {
    local status=$?
    if docker container inspect "$container" >/dev/null 2>&1; then
        if [ "$status" -ne 0 ]; then
            docker logs "$container" >&2
        fi
        docker rm --force --volumes "$container" >/dev/null
    fi
    if docker volume inspect "$volume" >/dev/null 2>&1; then
        docker volume rm "$volume" >/dev/null
    fi
    return "$status"
}
trap cleanup EXIT

test "$(docker image inspect "$image" --format '{{.Os}}/{{.Architecture}}')" = linux/arm64
docker run --rm --platform linux/arm64 "$image" bash -ec \
    'curl --version; mysql --version; mysqld --version'
docker volume create "$volume" >/dev/null

start_server() {
    docker run --detach --platform linux/arm64 --name "$container" \
        --env MYSQL_ROOT_PASSWORD --env MYSQL_PASSWORD \
        --env MYSQL_DATABASE=smoke_test --env MYSQL_USER=smoke_user \
        --mount "type=volume,source=$volume,target=/var/lib/mysql" \
        "$image" >/dev/null
}

wait_for_server() {
    local attempt
    for attempt in {1..120}; do
        if docker exec "$container" bash -ec \
            'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql --protocol=TCP \
                --host=127.0.0.1 --user=root --connect-timeout=2 \
                --execute="SELECT 1"' >/dev/null 2>&1; then
            return 0
        fi
        if [ "$(docker inspect "$container" --format '{{.State.Running}}')" != true ]; then
            echo "MySQL exited before becoming ready." >&2
            return 1
        fi
        sleep 2
    done
    echo "MySQL did not become ready within the startup timeout." >&2
    return 1
}

start_server
wait_for_server
docker exec "$container" bash -ec \
    'MYSQL_PWD="$MYSQL_PASSWORD" mysql --protocol=TCP --host=127.0.0.1 \
        --user=smoke_user smoke_test \
        --execute="CREATE TABLE persistence_check (id INT PRIMARY KEY);
                   INSERT INTO persistence_check VALUES (42);"'

docker stop --time 30 "$container" >/dev/null
docker rm --volumes "$container" >/dev/null
start_server
wait_for_server
result="$(docker exec "$container" bash -ec \
    'MYSQL_PWD="$MYSQL_PASSWORD" mysql --protocol=TCP --host=127.0.0.1 \
        --user=smoke_user --batch --skip-column-names smoke_test \
        --execute="SELECT id FROM persistence_check;"')"
test "$result" = 42
echo "ARM64 MySQL server, client, user initialization, and data persistence verified."
