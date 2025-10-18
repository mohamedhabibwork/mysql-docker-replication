# MySQL Master-Replica Setup

This is a Docker-based MySQL master-replica replication setup with persistent data storage on disk.

## 📋 Features

- MySQL 8.0 Master-Replica replication
- Binary logging with ROW format
- Persistent data storage on disk (not Docker volumes)
- Environment-based configuration
- Read-only replica (configurable)
- Automated replication setup
- Easy management script

## 🚀 Quick Start

### Option A: Same Server Deployment

#### 1. Setup Environment Files

Copy the example environment files and configure them:

```bash
cp master/.env.example master/.env
cp replica/.env.example replica/.env
```

Edit the `.env` files and change the default passwords:
- `master/.env` - Configure master database credentials
- `replica/.env` - Configure replica database credentials (keep `MASTER_HOST=mysql-master`)

#### 2. Start the Setup

```bash
./mange.sh start
```

This will:
- Create necessary data directories
- Start the master MySQL instance
- Start the replica MySQL instance
- Automatically configure replication
- Verify the setup

### Option B: Different Servers Deployment

#### On Master Server:

1. Setup environment file:
```bash
cd master
cp .env.example .env
```

2. Edit `master/.env` and configure:
   - Change all passwords
   - Set `MASTER_HOST_IP` to the master server's IP address (e.g., `192.168.1.100`)

3. Start master:
```bash
cd /path/to/mysql/master
docker-compose up -d
```

4. Create replication user:
```bash
docker exec mysql-master mysql -u root -p${MYSQL_ROOT_PASSWORD} -e \
  "CREATE USER 'repl'@'%' IDENTIFIED BY 'replpassword'; \
   GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%'; \
   FLUSH PRIVILEGES;"
```

5. Get binary log position:
```bash
docker exec mysql-master mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "SHOW MASTER STATUS\G"
```
Note the `File` and `Position` values.

#### On Replica Server:

1. Setup environment file:
```bash
cd replica
cp .env.example .env
```

2. Edit `replica/.env` and configure:
   - Change all passwords (must match master)
   - Set `MASTER_HOST` to the master server's IP address (e.g., `192.168.1.100`)
   - Ensure `MYSQL_REPLICATION_USER` and `MYSQL_REPLICATION_PASSWORD` match what you created on master

3. Start replica:
```bash
cd /path/to/mysql/replica
docker-compose up -d
```

4. Configure replication (replace FILE and POSITION with values from step 5 above):
```bash
docker exec mysql-replica mysql -u root -p${MYSQL_ROOT_PASSWORD} -e \
  "CHANGE MASTER TO \
   MASTER_HOST='MASTER_IP_ADDRESS', \
   MASTER_USER='repl', \
   MASTER_PASSWORD='replpassword', \
   MASTER_LOG_FILE='mysql-bin.000001', \
   MASTER_LOG_POS=123; \
   START SLAVE;"
```

5. Verify replication:
```bash
docker exec mysql-replica mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "SHOW SLAVE STATUS\G"
```

**Important for Different Servers:**
- Ensure firewall allows connections on port 3308 (or your configured port) from replica to master
- Master and replica must be able to reach each other via network
- Consider using VPN or secure network for production

## 📝 Management Commands

```bash
./mange.sh start      # Start master & replica with replication setup
./mange.sh stop       # Stop both containers
./mange.sh status     # Show master and replica status
./mange.sh logs master   # View master logs
./mange.sh logs replica  # View replica logs
./mange.sh reset      # Reset all data (WARNING: deletes everything)
./mange.sh help       # Show help
```

## 🔧 Configuration

### Master Configuration (`master/.env`)
- `MYSQL_ROOT_PASSWORD` - Root password for master
- `MYSQL_DATABASE` - Database name to create
- `MYSQL_USER` - Application user
- `MYSQL_PASSWORD` - Application user password
- `MYSQL_REPLICATION_USER` - Replication user
- `MYSQL_REPLICATION_PASSWORD` - Replication user password
- `HOST_PORT` - Port to expose (default: 3306)
- `DATA_DIR` - Data directory path
- `LOGS_DIR` - Logs directory path

### Replica Configuration (`replica/.env`)
- Same as master, plus:
- `MASTER_HOST` - Master container name (default: mysql-master)
- `HOST_PORT` - Port to expose (default: 3307)

## 🔌 Connection Details

### Master
- **Host**: `localhost`
- **Port**: `3306` (configurable in `.env`)
- **Root Password**: Set in `master/.env`

### Replica
- **Host**: `localhost`
- **Port**: `3307` (configurable in `.env`)
- **Root Password**: Set in `replica/.env`
- **Note**: Replica is read-only by default

## 📁 Data Storage

All data is stored on disk at:
- Master data: `./master/data/`
- Master logs: `./master/logs/`
- Replica data: `./replica/data/`
- Replica logs: `./replica/logs/`

## 🔍 Verify Replication

Check replication status:
```bash
./mange.sh status
```

Look for:
- `Slave_IO_Running: Yes`
- `Slave_SQL_Running: Yes`
- `Seconds_Behind_Master: 0` (or small number)

## 🛠️ Troubleshooting

### Replication not working
1. Check status: `./mange.sh status` (same server) or manually on each server
2. View logs: `./mange.sh logs master` or `./mange.sh logs replica`
3. Verify network connectivity:
   - Same server: Check if containers are on same network
   - Different servers: Test with `telnet MASTER_IP 3308` from replica server
4. Ensure replication credentials are correct in `.env` files
5. Check firewall rules (for different server setup)

### Permission issues
Ensure data directories have proper permissions:
```bash
chmod 777 master/data master/logs replica/data replica/logs
```

### Cannot connect to master from replica (different servers)
1. Verify master IP address is correct in replica `.env`
2. Check firewall on master server allows port 3308 (or your configured port)
3. Ensure MySQL user 'repl'@'%' exists on master
4. Test connection: `telnet MASTER_IP 3308`

### Reset and start fresh
Same server:
```bash
./mange.sh reset
./mange.sh start
```

Different servers:
- Stop containers on both servers
- Delete data directories on both servers
- Follow deployment steps again

## ⚠️ Security Notes

1. Change all default passwords in `.env` files
2. Never commit `.env` files to version control (already in `.gitignore`)
3. Use strong passwords for production environments
4. Consider using Docker secrets for sensitive data in production
5. Restrict network access to MySQL ports

## 📚 Additional Resources

- [MySQL Replication Documentation](https://dev.mysql.com/doc/refman/8.0/en/replication.html)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
