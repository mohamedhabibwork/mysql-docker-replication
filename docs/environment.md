# Environment Configuration

Both Docker Compose projects (`master/docker-compose.yml` and `replica/docker-compose.yml`) rely on a `.env` file that defines container names, credentials, ports, and replication settings. This document explains every variable and offers setup guidance for local and remote scenarios.

> Copy the provided `.env.example` files to `.env` before editing.

## Shared Credentials

| Variable | Location | Description |
| --- | --- | --- |
| `MYSQL_ROOT_PASSWORD` | master, replica | Root password for each MySQL instance. Must match between master and replica unless you intend to manage separate credentials manually. |
| `MYSQL_DATABASE` | master, replica | Default application database created on first boot. |
| `MYSQL_USER` / `MYSQL_PASSWORD` | master, replica | Application user credentials; replicated database schema ensures the account exists in both containers. |

## Replication User

| Variable | Location | Description |
| --- | --- | --- |
| `MYSQL_REPLICATION_USER` | master, replica | User created on the master and used by the replica to authenticate. |
| `MYSQL_REPLICATION_PASSWORD` | master, replica | Password for the replication user. |

Make sure the replication credentials match across both `.env` files. The helper script provisions the user automatically when replication starts.

## Container Metadata

| Variable | Location | Description |
| --- | --- | --- |
| `CONTAINER_NAME` | master, replica | Friendly name used by Docker and referenced by scripts. Defaults to `mysql-master` and `mysql-replica`. |
| `HOST_PORT` | master, replica | Host port exposed for the container's MySQL service. The master defaults to `3308`, the replica to `3309`. Adjust when ports conflict with existing services. |
| `SERVER_ID` | master, replica | Unique server ID required by MySQL replication. Leave `1` for the master and `2` for the replica unless you run multiple replicas; each server must have a distinct positive integer. |

## Data and Log Paths

| Variable | Location | Description |
| --- | --- | --- |
| `DATA_DIR` | master, replica | Path (relative to the compose file) used for the MySQL data directory volume (`/var/lib/mysql`). Adjust when targeting a different host path or shared storage. |
| `LOGS_DIR` | master, replica | Path for MySQL logs (`/var/log/mysql`). |

The helper script creates these directories and sets permissive (777) permissions to avoid permission denied errors with Docker Desktop volumes. Restrict them further if you manage ownership manually.

## Master Host Resolution

| Variable | Location | Description |
| --- | --- | --- |
| `MASTER_HOST` | replica | Hostname or IP address the replica uses during `CHANGE MASTER TO`. For local Compose topologies, set this to `mysql-master` (the service/container name). For remote replication, set it to the master host IP or DNS name. |
| `MASTER_HOST_IP` | master, replica | Optional convenience variable when shipping certificates or referencing the master from external scripts. Not consumed directly by Docker Compose, but available for custom automation. |

## SSL Enablement

| Variable | Location | Description |
| --- | --- | --- |
| `SSL_ENABLED` | master, replica | When `true`, `mange.sh` copies certificates into each container and configures replication to require TLS. Set to `false` in both `.env` files to disable certificate management and REQUIRE SSL clauses. |

> **Important:** The sample file `master/.env.example` currently contains a malformed `SSL_ENABLED` line (`SSL_ENABLED=true192.168.1.100`). Replace it with `SSL_ENABLED=true` before use.

## Local Workstation Topology

Set the following values when running everything on the same machine:

```
# master/.env
CONTAINER_NAME=mysql-master
HOST_PORT=3308
MASTER_HOST_IP=
SSL_ENABLED=true

# replica/.env
CONTAINER_NAME=mysql-replica
HOST_PORT=3309
MASTER_HOST=mysql-master
SSL_ENABLED=true
```

Using the container name ensures traffic traverses the private Docker network created by Compose.

## Remote Replica Scenario

When the master and replica run on different hosts:

1. Set `MASTER_HOST_IP` in `master/.env` to the master machine's routable IP (e.g., `10.10.0.4`).
2. Set `MASTER_HOST` in `replica/.env` to the same IP or a DNS entry.
3. Expose the master MySQL port publicly or via a VPN and update `HOST_PORT` if you remap to a non-standard port.
4. Copy certificates from the master host to the replica host (e.g., `rsync -avz ssl-certs/ replica-host:/path/to/repo/ssl-certs/`).

## Regenerating Credentials Safely

- Update the desired variables in both `.env` files.
- Run `./mange.sh stop` to gracefully stop the stack.
- Execute `./mange.sh start` to restart containers. The helper script recreates the replication user with the new credentials and reconfigures the replica automatically.

## Version Control Tips

- Never commit `.env` files containing secrets. Add them to `.gitignore` when customizing the project.
- Keep `.env.example` up to date as a self-documenting baseline for collaborators.
