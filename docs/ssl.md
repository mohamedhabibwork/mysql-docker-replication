# SSL and Certificate Management

Replication can be secured with TLS using the helper scripts included in this repository. This guide explains certificate generation, installation, validation, and rotation.

## Certificate Layout

`generate-ssl-certs.sh` produces the following assets in `ssl-certs/`:

- `ca-key.pem` / `ca-cert.pem` – Certificate authority pair used to sign the server and client certificates.
- `server-key.pem` / `server-cert.pem` – Installed on the master container and referenced by MySQL via `master/master.cnf`.
- `client-key.pem` / `client-cert.pem` – Copied to the replica and referenced when the replica connects with `MASTER_SSL=1`.

All keys default to 2048-bit RSA, valid for 3650 days (10 years).

## Generating Certificates

```bash
./mange.sh generate-certs
```

- Creates `ssl-certs/` when missing.
- Prompts before overwriting existing PEM files.
- Sets restrictive permissions (directories `755`, public certs `644`, private keys `600`).
- Verifies the certificate chain with `openssl verify`.

> The script asks for confirmation when certificates already exist. Answer `yes` to regenerate or `no` to keep existing files.

## Installing Certificates

When `SSL_ENABLED=true`:

1. `./mange.sh start` calls `setup_ssl` after the master container becomes healthy.
2. Certificates are copied into `/var/lib/mysql/ssl/` inside each container.
3. Ownership is set to `mysql:mysql` and permissions to `600/644` as appropriate.
4. The master container restarts to load the certificates.
5. The replica copies the CA + client pair and configures `CHANGE MASTER TO ... MASTER_SSL=1`.

## Validation Steps

- Run `SHOW VARIABLES LIKE 'have_ssl';` on the master – expect `YES`.
- Run `SHOW STATUS LIKE 'Ssl_cipher';` on both nodes – expect a non-empty cipher when clients connect with TLS.
- Inspect `SHOW SLAVE STATUS\G` and confirm `Master_SSL_Allowed`, `Master_SSL_CA_File`, `Master_SSL_Cert`, and `Master_SSL_Key` are populated.

## Rotating Certificates

1. Run `./mange.sh generate-certs` to issue fresh keys (or distribute new CA-signed certs into `ssl-certs/`).
2. Execute `./mange.sh start` (or `./mange.sh stop` followed by `./mange.sh start`) to propagate the updated files. The helper automatically re-copies them.
3. Validate replication and SSL status as described above.

## Using External PKI

If you prefer certificates issued by an enterprise CA:

1. Place `ca-cert.pem`, `server-cert.pem`, `server-key.pem`, `client-cert.pem`, and `client-key.pem` into `ssl-certs/` manually.
2. Ensure files use PEM encoding and private keys are unencrypted.
3. Set permissions as described earlier (`chmod 644` for certificates, `chmod 600` for keys).
4. Run `./mange.sh start` (or `fix-permissions` + `setup_ssl` via `ssl-export`) to copy files into containers.

## Disabling SSL

- Set `SSL_ENABLED=false` in both `master/.env` and `replica/.env`.
- Run `./mange.sh start` to restart the stack. The helper will skip certificate copying and configure replication without the `REQUIRE SSL` clause.
- Optionally remove `ssl-certs/` if certificates are no longer needed.
