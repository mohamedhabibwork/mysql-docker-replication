# Troubleshooting

A curated list of common issues encountered when running the MySQL replication sandbox and the steps to resolve them.

## Containers fail health checks

- **Symptom:** `docker ps` shows either container restarting, healthcheck reports `unhealthy`.
- **Fix:**
  - Confirm the local ports (default `3308`/`3309`) are free.
  - Ensure `MYSQL_ROOT_PASSWORD` is identical in `master/.env` and `replica/.env`.
  - Run `./mange.sh fix-permissions` to reset folder permissions, then retry `./mange.sh start`.

## Replica stuck with `Slave_IO_Running: No`

- **Symptom:** `SHOW SLAVE STATUS\G` shows `Slave_IO_Running: No` and `Last_IO_Error` complains about authentication or SSL.
- **Fix:**
  - Verify the master is reachable: `docker exec mysql-replica ping -c1 mysql-master` (or the configured host).
  - Check that `MYSQL_REPLICATION_USER`/`MYSQL_REPLICATION_PASSWORD` match across `.env` files.
  - If SSL is enabled, confirm certificates exist inside the replica under `/var/lib/mysql/ssl/` and that `ca-cert.pem` matches the master.
  - Run `./mange.sh start` again to recreate the replication user and reissue `CHANGE MASTER TO`.

## Replica behind after reset

- **Symptom:** Tables created on the master do not appear on the replica after using `./mange.sh reset`.
- **Fix:** `reset` removes local data directories. Reimport your schema or seed data onto the master, then validate replication flows. Consider backing up `master/data/` or using mysqldump before destructive resets.

## Certificate generation fails

- **Symptom:** `./mange.sh generate-certs` prints `[ERROR] Failed to generate ...`.
- **Fix:**
  - Ensure OpenSSL is installed (`openssl version`).
  - Check write permissions for the `ssl-certs/` directory.
  - Review the console output for hints; rerun with `bash -x ./generate-ssl-certs.sh` for verbose tracing.

## `test-ssl.sh not found` warning

- **Symptom:** `fix-permissions` mentions `test-ssl.sh not found`.
- **Fix:** The helper script sets executable bits conditionally. The absence of `test-ssl.sh` is harmless. Ignore the warning or add your own testing script at the repository root if desired.

## Forgetting to copy `.env.example`

- **Symptom:** Compose uses default values or fails with missing variables.
- **Fix:** Copy `.env.example` to `.env` in both `master/` and `replica/`, then edit the new files. The helper script sources `.env` directly; missing files will cause `bash: source: no such file` errors.

## Cleaning up after experiments

To reclaim disk space:

1. Run `./mange.sh stop` to tear down containers.
2. Optionally delete `master/data/`, `replica/data/`, and `ssl-certs/` if you no longer need them.
3. Run `docker volume prune` and `docker image prune` to remove unused artifacts (be aware that this impacts other projects, too).

## Still stuck?

- Review Docker logs: `docker logs mysql-master --tail 100`.
- Inspect MySQL error logs under `master/logs/` and `replica/logs/`.
- File an issue using the bundled bug report template (include `docker-compose.yml`, `.env` snippets, and logs).
