# Operations Guide

The `mange.sh` helper script orchestrates most day-to-day tasks. This page dives into what each command does under the hood and when to use it.

## Command Reference

| Command | Description |
| --- | --- |
| `./mange.sh start` | Creates volume folders, fixes permissions, launches master, optionally copies SSL assets, launches replica, configures replication, and enforces read-only mode on the replica. |
| `./mange.sh stop` | Runs `docker-compose down` for both the master and replica projects, preserving volumes by default. |
| `./mange.sh status` | Prints `SHOW MASTER STATUS` and `SHOW SLAVE STATUS` output. When SSL is enabled, also returns SSL-related server variables for the master. |
| `./mange.sh logs master` | Follows the master container logs with Docker Compose. |
| `./mange.sh logs replica` | Follows the replica container logs with Docker Compose. |
| `./mange.sh reset` | Prompts for confirmation, stops both stacks, removes containers and volumes, and deletes the `data/` and `logs/` directories. Use with caution. |
| `./mange.sh generate-certs` | Invokes `generate-ssl-certs.sh` to populate `ssl-certs/` with a CA, server, and client certificate/key pair. Prompts before overwriting existing material. |
| `./mange.sh ssl-export` | Deprecated alias that reruns the SSL setup logic. Provided for backwards compatibility. |
| `./mange.sh fix-permissions` | Ensures scripts are executable, configs are world-readable, data/log directories are writeable, and certificate permissions are correct. |
| `./mange.sh help` | Displays inline usage instructions. |

## Lifecycle Overview

1. **Directory Preparation** – `setup_directories` creates all required folders (`master/data`, `replica/logs`, etc.).
2. **Permission Normalization** – `fix_permissions` grants permissive access to directories and scripts to avoid Docker volume permission issues across platforms.
3. **Master Bootstrap** – Master Compose stack starts first. Health checks ensure the container is ready before advancing.
4. **SSL Setup** – When `SSL_ENABLED=true`, certificates are copied into `/var/lib/mysql/ssl` inside the master container and ownership is set to `mysql:mysql`. The container restarts to pick up the new files.
5. **Replica Bootstrap** – Replica stack starts and waits for MySQL to accept connections before receiving certificates (if enabled).
6. **Replication Configuration** – The script captures the current master binlog file + position, recreates the replication user (with or without `REQUIRE SSL`), executes `CHANGE MASTER TO`, starts the slave, and enables `read_only` + `super_read_only`.

## Manual Checks

- `docker ps` – Verify both containers are running.
- `docker logs mysql-master --tail 20` – Inspect recent master logs.
- `docker exec mysql-replica mysql -e "SHOW SLAVE STATUS\G"` – Confirm `Slave_IO_Running` and `Slave_SQL_Running` are both `Yes`.
- `SHOW VARIABLES LIKE 'have_ssl';` – Validate SSL negotiation on the master (expect `YES`).

## Graceful Shutdown

To stop the topology temporarily:

```bash
./mange.sh stop
```

This command preserves the contents of `data/` and `logs/`. Restart with `./mange.sh start` when ready.

## Full Reset

Use the reset workflow when you want a clean slate:

```bash
./mange.sh reset
```

- Respond `yes` to confirm.
- Volumes are removed via `docker-compose down -v` and local directories are emptied.
- Regenerate certificates if you removed `ssl-certs/` afterward.

## Adding Additional Replicas

The bundled script assumes a single replica. To add more replicas:

1. Duplicate the `replica/` directory and rename it (e.g., `replica-east/`).
2. Update `CONTAINER_NAME`, `HOST_PORT`, and `SERVER_ID` to unique values.
3. Copy or symlink the certificates if SSL is required.
4. Run `docker-compose up -d` inside each replica folder and manually execute the replication setup SQL statements (you can reuse the logic in `setup_replication`).

Future versions of the management script could be extended to automate multi-replica scenarios; contributions welcome.
