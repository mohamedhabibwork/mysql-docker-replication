#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Function to print messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to create data directories
setup_directories() {
    print_info "Setting up data directories..."
    
    # Create all necessary directories
    mkdir -p "$SCRIPT_DIR/master/data"
    mkdir -p "$SCRIPT_DIR/master/data/ssl"
    mkdir -p "$SCRIPT_DIR/master/logs"
    mkdir -p "$SCRIPT_DIR/replica/data"
    mkdir -p "$SCRIPT_DIR/replica/data/ssl"
    mkdir -p "$SCRIPT_DIR/replica/logs"
    mkdir -p "$SCRIPT_DIR/ssl-certs"
    
    print_info "Directories created successfully"
}

# Function to fix all permissions
fix_permissions() {
    print_info "Fixing file and folder permissions..."
    
    # Fix data and logs directories (MySQL needs write access)
    print_info "Setting permissions for data directories..."
    if [ -d "$SCRIPT_DIR/master/data" ]; then
        chmod -R 777 "$SCRIPT_DIR/master/data" 2>/dev/null || true
        print_info "  ✓ Master data directory: 777"
    fi
    
    if [ -d "$SCRIPT_DIR/master/logs" ]; then
        chmod -R 777 "$SCRIPT_DIR/master/logs" 2>/dev/null || true
        print_info "  ✓ Master logs directory: 777"
    fi
    
    if [ -d "$SCRIPT_DIR/replica/data" ]; then
        chmod -R 777 "$SCRIPT_DIR/replica/data" 2>/dev/null || true
        print_info "  ✓ Replica data directory: 777"
    fi
    
    if [ -d "$SCRIPT_DIR/replica/logs" ]; then
        chmod -R 777 "$SCRIPT_DIR/replica/logs" 2>/dev/null || true
        print_info "  ✓ Replica logs directory: 777"
    fi
    
    # Fix SSL certificates directory
    if [ -d "$SCRIPT_DIR/ssl-certs" ]; then
        chmod 755 "$SCRIPT_DIR/ssl-certs" 2>/dev/null || true
        chmod 644 "$SCRIPT_DIR/ssl-certs"/*.pem 2>/dev/null || true
        print_info "  ✓ SSL certificates directory: 755, files: 644"
    fi
    
    # Fix script permissions
    print_info "Setting permissions for scripts..."
    chmod +x "$SCRIPT_DIR/mange.sh" 2>/dev/null || true
    chmod +x "$SCRIPT_DIR/test-ssl.sh" 2>/dev/null || true
    print_info "  ✓ Management scripts: executable"
    
    # Fix master init scripts
    if [ -f "$SCRIPT_DIR/master/init-ssl.sh" ]; then
        chmod +x "$SCRIPT_DIR/master/init-ssl.sh" 2>/dev/null || true
    fi
    
    # Fix configuration files
    if [ -f "$SCRIPT_DIR/master/master.cnf" ]; then
        chmod 644 "$SCRIPT_DIR/master/master.cnf" 2>/dev/null || true
    fi
    
    if [ -f "$SCRIPT_DIR/replica/replica.cnf" ]; then
        chmod 644 "$SCRIPT_DIR/replica/replica.cnf" 2>/dev/null || true
    fi
    print_info "  ✓ Configuration files: 644"
    
    # Fix .env files (should be readable but secure)
    if [ -f "$SCRIPT_DIR/master/.env" ]; then
        chmod 600 "$SCRIPT_DIR/master/.env" 2>/dev/null || true
    fi
    
    if [ -f "$SCRIPT_DIR/replica/.env" ]; then
        chmod 600 "$SCRIPT_DIR/replica/.env" 2>/dev/null || true
    fi
    print_info "  ✓ Environment files: 600 (secure)"
    
    # Fix docker-compose files
    if [ -f "$SCRIPT_DIR/master/docker-compose.yml" ]; then
        chmod 644 "$SCRIPT_DIR/master/docker-compose.yml" 2>/dev/null || true
    fi
    
    if [ -f "$SCRIPT_DIR/replica/docker-compose.yml" ]; then
        chmod 644 "$SCRIPT_DIR/replica/docker-compose.yml" 2>/dev/null || true
    fi
    print_info "  ✓ Docker Compose files: 644"
    
    # Fix documentation files
    chmod 644 "$SCRIPT_DIR"/*.md 2>/dev/null || true
    print_info "  ✓ Documentation files: 644"
    
    print_info "All permissions fixed successfully"
}

# Function to generate SSL certificates
generate_ssl_certs() {
    print_info "Generating SSL certificates..."
    
    if [ ! -f "$SCRIPT_DIR/generate-ssl-certs.sh" ]; then
        print_error "generate-ssl-certs.sh not found"
        return 1
    fi
    
    bash "$SCRIPT_DIR/generate-ssl-certs.sh"
    return $?
}

# Function to initialize SSL certificates
setup_ssl() {
    print_info "Setting up SSL certificates..."
    
    # Load environment variables
    source "$SCRIPT_DIR/master/.env"
    MASTER_CONTAINER=$CONTAINER_NAME
    SSL_ENABLED=${SSL_ENABLED:-false}
    
    if [ "$SSL_ENABLED" != "true" ]; then
        print_info "SSL is disabled in configuration"
        return 0
    fi
    
    print_info "SSL is enabled. Checking for certificates..."
    
    # Check if pre-generated certificates exist in ssl-certs folder
    if [ ! -f "$SCRIPT_DIR/ssl-certs/ca-cert.pem" ] || [ ! -f "$SCRIPT_DIR/ssl-certs/server-cert.pem" ] || [ ! -f "$SCRIPT_DIR/ssl-certs/client-cert.pem" ]; then
        print_warning "SSL certificates not found in ssl-certs/ folder"
        print_info "Generating certificates now..."
        generate_ssl_certs
        if [ $? -ne 0 ]; then
            print_error "Failed to generate SSL certificates"
            return 1
        fi
    else
        print_info "✓ Found pre-generated SSL certificates in ssl-certs/"
    fi

    # Copy certificates to master container
    print_info "Copying SSL certificates to master container..."
    docker cp "$SCRIPT_DIR/ssl-certs/ca-cert.pem" $MASTER_CONTAINER:/var/lib/mysql/ssl/ 2>/dev/null
    docker cp "$SCRIPT_DIR/ssl-certs/server-cert.pem" $MASTER_CONTAINER:/var/lib/mysql/ssl/ 2>/dev/null
    docker cp "$SCRIPT_DIR/ssl-certs/client-cert.pem" $MASTER_CONTAINER:/var/lib/mysql/ssl/ 2>/dev/null

    if [ $? -ne 0 ]; then
        print_error "Failed to copy SSL certificates to master"
        return 1
    fi


    # Copy SSL certificates to replica container
    print_info "Copying SSL certificates to replica container..."
    source "$SCRIPT_DIR/replica/.env"
    REPLICA_CONTAINER=$CONTAINER_NAME
    docker cp "$SCRIPT_DIR/ssl-certs/ca-cert.pem" $REPLICA_CONTAINER:/var/lib/mysql/ssl/ 2>/dev/null
    docker cp "$SCRIPT_DIR/ssl-certs/client-cert.pem" $REPLICA_CONTAINER:/var/lib/mysql/ssl/ 2>/dev/null
    docker cp "$SCRIPT_DIR/ssl-certs/client-key.pem" $REPLICA_CONTAINER:/var/lib/mysql/ssl/ 2>/dev/null 
    if [ $? -ne 0 ]; then
        print_error "Failed to copy SSL certificates to replica"
        return 1
    fi
    # Wait for MySQL to be ready
    print_info "Waiting for MySQL initialization..."
    local retries=0
    local max_retries=60
    while [ $retries -lt $max_retries ]; do
        docker exec $MASTER_CONTAINER mysql -u root -p$MYSQL_ROOT_PASSWORD -e "SELECT 1;" 2>/dev/null
        if [ $? -eq 0 ]; then
            print_info "MySQL is ready"
            break
        fi
        sleep 2
        retries=$((retries+1))
    done
    
    if [ $retries -eq $max_retries ]; then
        print_error "MySQL did not start within expected time"
        return 1
    fi
    
    # Check if SSL certificates are already mounted via volume
    print_info "Checking SSL certificate availability in master container..."
    docker exec $MASTER_CONTAINER test -f /var/lib/mysql/ssl/ca-cert.pem 2>/dev/null
    if [ $? -eq 0 ]; then
        print_info "✓ SSL certificates are already available (mounted via volume)"
    else
        print_warning "SSL certificates not found in container. Please ensure ssl-certs directory is mounted as volume in docker-compose.yml"
        print_info "Add this volume mapping to your master docker-compose.yml:"
        print_info "    volumes:"
        print_info "      - ../ssl-certs:/var/lib/mysql/ssl:ro"
        return 1
    fi
    
    print_info "✓ SSL certificates copied to master successfully"
    
    # Restart MySQL to load SSL configuration
    print_info "Restarting MySQL to load SSL configuration..."
    docker restart $MASTER_CONTAINER
    sleep 10
    
    # Wait for MySQL to be ready again
    retries=0
    while [ $retries -lt $max_retries ]; do
        docker exec $MASTER_CONTAINER mysql -u root -p$MYSQL_ROOT_PASSWORD -e "SELECT 1;" 2>/dev/null
        if [ $? -eq 0 ]; then
            break
        fi
        sleep 2
        retries=$((retries+1))
    done
    
    # Verify SSL is working
    SSL_STATUS=$(docker exec $MASTER_CONTAINER mysql -u root -p$MYSQL_ROOT_PASSWORD -e "SHOW VARIABLES LIKE 'have_ssl';" 2>/dev/null | grep have_ssl | awk '{print $2}')
    if [ "$SSL_STATUS" = "YES" ]; then
        print_info "✓ SSL is enabled and working on master"
    else
        print_warning "SSL certificates exist but MySQL SSL is not enabled"
        print_info "Check master logs: docker logs $MASTER_CONTAINER"
    fi
}

# Function to copy SSL certificates to replica
copy_ssl_to_replica() {
    print_info "Setting up SSL on replica..."
    
    source "$SCRIPT_DIR/replica/.env"
    REPLICA_CONTAINER=$CONTAINER_NAME
    SSL_ENABLED=${SSL_ENABLED:-false}
    
    if [ "$SSL_ENABLED" != "true" ]; then
        print_info "SSL is disabled on replica"
        return 0
    fi
    
    # Check if SSL certificates directory exists
    if [ ! -d "$SCRIPT_DIR/ssl-certs" ] || [ ! -f "$SCRIPT_DIR/ssl-certs/ca-cert.pem" ]; then
        print_error "SSL certificates not found in $SCRIPT_DIR/ssl-certs/"
        print_error "Please ensure:"
        print_error "  1. Run './mange.sh generate-certs' to generate certificates"
        print_error "  2. For different servers: copy ssl-certs/ directory from master"
        return 1
    fi
    
    print_info "SSL certificates found and mounted via Docker volume."
    
    # Wait for replica to be ready
    print_info "Waiting for replica MySQL to be ready..."
    local retries=0
    local max_retries=60
    while [ $retries -lt $max_retries ]; do
        docker exec $REPLICA_CONTAINER mysql -u root -p$REPLICA_ROOT_PASSWORD -e "SELECT 1;" 2>/dev/null
        if [ $? -eq 0 ]; then
            print_info "Replica MySQL is ready"
            break
        fi
        sleep 3
        retries=$((retries+1))
    done
    
    if [ $retries -eq $max_retries ]; then
        print_error "Replica MySQL did not start within expected time"
        print_info "Checking replica logs..."
        docker logs $REPLICA_CONTAINER --tail 50
        return 1
    fi
    
    # Verify certificates are accessible in replica
    docker exec $REPLICA_CONTAINER test -f /var/lib/mysql/ssl/ca-cert.pem 2>/dev/null
    if [ $? -eq 0 ]; then
        print_info "✓ SSL certificates verified on replica"
    else
        print_error "SSL certificates not found in replica container"
        return 1
    fi
}

# Function to start containers
start() {
    print_info "Starting MySQL Master and Replica..."
    
    # Setup directories first
    setup_directories
    
    # Fix all permissions
    fix_permissions
    
    # Start master
    cd "$SCRIPT_DIR/master"
    print_info "Starting Master MySQL..."
    docker-compose up -d
    
    # Wait for master to be ready
    print_info "Waiting for Master to be ready..."
    sleep 15
    
    # Setup SSL if enabled
    setup_ssl
    
    # Start replica
    cd "$SCRIPT_DIR/replica"
    print_info "Starting Replica MySQL..."
    docker-compose up -d
    
    # Wait for replica to be ready
    sleep 10
    
    # Copy SSL certificates to replica
    copy_ssl_to_replica
    
    # Setup replication
    setup_replication
    
    print_info "MySQL Master and Replica are running!"
    print_info "Master: localhost:3308"
    print_info "Replica: localhost:3309"
}

# Function to setup replication
setup_replication() {
    print_info "Setting up replication..."
    
    # Load environment variables
    source "$SCRIPT_DIR/master/.env"
    MASTER_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
    REPL_USER=$MYSQL_REPLICATION_USER
    REPL_PASSWORD=$MYSQL_REPLICATION_PASSWORD
    MASTER_CONTAINER=$CONTAINER_NAME
    
    source "$SCRIPT_DIR/replica/.env"
    REPLICA_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
    REPLICA_CONTAINER=$CONTAINER_NAME
    MASTER_HOST_FROM_REPLICA=$MASTER_HOST
    
    # Get binary log position from master
    BIN_LOG_STATUS=$(docker exec $MASTER_CONTAINER mysql -u root -p$MASTER_ROOT_PASSWORD -e "SHOW MASTER STATUS\G" 2>/dev/null)
    
    if [ -z "$BIN_LOG_STATUS" ]; then
        print_error "Could not get binary log status from master"
        return 1
    fi
    
    # Extract File and Position
    BIN_LOG_FILE=$(echo "$BIN_LOG_STATUS" | grep "File:" | awk '{print $2}')
    BIN_LOG_POS=$(echo "$BIN_LOG_STATUS" | grep "Position:" | awk '{print $2}')
    
    print_info "Binary Log File: $BIN_LOG_FILE, Position: $BIN_LOG_POS"
    
    # Create replication user on master
    print_info "Creating replication user on master..."
    
    # Check if SSL is enabled
    source "$SCRIPT_DIR/master/.env"
    SSL_ENABLED=${SSL_ENABLED:-false}
    
    if [ "$SSL_ENABLED" = "true" ]; then
        docker exec $MASTER_CONTAINER mysql -u root -p$MASTER_ROOT_PASSWORD -e \
            "CREATE USER IF NOT EXISTS '$REPL_USER'@'%' IDENTIFIED BY '$REPL_PASSWORD' REQUIRE SSL; \
             GRANT REPLICATION SLAVE ON *.* TO '$REPL_USER'@'%'; \
             FLUSH PRIVILEGES;" 2>/dev/null
        print_info "Replication user created with SSL requirement"
    else
        docker exec $MASTER_CONTAINER mysql -u root -p$MASTER_ROOT_PASSWORD -e \
            "CREATE USER IF NOT EXISTS '$REPL_USER'@'%' IDENTIFIED BY '$REPL_PASSWORD'; \
             GRANT REPLICATION SLAVE ON *.* TO '$REPL_USER'@'%'; \
             FLUSH PRIVILEGES;" 2>/dev/null
        print_info "Replication user created without SSL"
    fi
    
    # Configure replica to replicate from master
    print_info "Configuring replica to replicate from master..."
    
    source "$SCRIPT_DIR/replica/.env"
    SSL_ENABLED=${SSL_ENABLED:-false}
    
    if [ "$SSL_ENABLED" = "true" ]; then
        docker exec $REPLICA_CONTAINER mysql -u root -p$REPLICA_ROOT_PASSWORD -e \
            "CHANGE MASTER TO \
             MASTER_HOST='$MASTER_HOST_FROM_REPLICA', \
             MASTER_USER='$REPL_USER', \
             MASTER_PASSWORD='$REPL_PASSWORD', \
             MASTER_LOG_FILE='$BIN_LOG_FILE', \
             MASTER_LOG_POS=$BIN_LOG_POS, \
             MASTER_SSL=1, \
             MASTER_SSL_CA='/var/lib/mysql/ssl/ca-cert.pem', \
             MASTER_SSL_CERT='/var/lib/mysql/ssl/client-cert.pem', \
             MASTER_SSL_KEY='/var/lib/mysql/ssl/client-key.pem'; \
             START SLAVE;" 2>/dev/null
        print_info "Replication configured with SSL enabled"
    else
        docker exec $REPLICA_CONTAINER mysql -u root -p$REPLICA_ROOT_PASSWORD -e \
            "CHANGE MASTER TO \
             MASTER_HOST='$MASTER_HOST_FROM_REPLICA', \
             MASTER_USER='$REPL_USER', \
             MASTER_PASSWORD='$REPL_PASSWORD', \
             MASTER_LOG_FILE='$BIN_LOG_FILE', \
             MASTER_LOG_POS=$BIN_LOG_POS; \
             START SLAVE;" 2>/dev/null
        print_info "Replication configured without SSL"
    fi
    
    # Set read_only and super_read_only on replica
    print_info "Enabling read-only mode on replica..."
    docker exec $REPLICA_CONTAINER mysql -u root -p$REPLICA_ROOT_PASSWORD -e \
        "SET GLOBAL super_read_only = OFF; SET GLOBAL read_only = ON; SET GLOBAL super_read_only = ON;" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        print_info "✓ Replica set to read-only mode (super_read_only enabled)"
    else
        print_warning "Failed to set read-only mode on replica"
    fi
    
    # Check replica status
    sleep 5
    print_info "Checking replica status..."
    docker exec $REPLICA_CONTAINER mysql -u root -p$REPLICA_ROOT_PASSWORD -e "SHOW SLAVE STATUS\G" 2>/dev/null
}

# Function to stop containers
stop() {
    print_info "Stopping MySQL Master and Replica..."
    
    cd "$SCRIPT_DIR/master"
    docker-compose down
    
    cd "$SCRIPT_DIR/replica"
    docker-compose down
    
    print_info "Stopped successfully"
}

# Function to show status
status() {
    # Load environment variables
    source "$SCRIPT_DIR/master/.env"
    MASTER_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
    MASTER_CONTAINER=$CONTAINER_NAME
    SSL_ENABLED=${SSL_ENABLED:-false}
    
    source "$SCRIPT_DIR/replica/.env"
    REPLICA_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
    REPLICA_CONTAINER=$CONTAINER_NAME
    
    print_info "Master Status:"
    docker exec $MASTER_CONTAINER mysql -u root -p$MASTER_ROOT_PASSWORD -e "SHOW MASTER STATUS\G" 2>/dev/null
    
    if [ "$SSL_ENABLED" = "true" ]; then
        print_info "Master SSL Status:"
        docker exec $MASTER_CONTAINER mysql -u root -p$MASTER_ROOT_PASSWORD -e "SHOW VARIABLES LIKE '%ssl%';" 2>/dev/null
    fi
    
    print_info "Replica Status:"
    docker exec $REPLICA_CONTAINER mysql -u root -p$REPLICA_ROOT_PASSWORD -e "SHOW SLAVE STATUS\G" 2>/dev/null
}

# Function to view logs
logs() {
    case "$2" in
        master)
            docker-compose -f "$SCRIPT_DIR/master/docker-compose.yml" logs -f
            ;;
        replica)
            docker-compose -f "$SCRIPT_DIR/replica/docker-compose.yml" logs -f
            ;;
        *)
            print_error "Usage: $0 logs [master|replica]"
            ;;
    esac
}

# Function to reset (WARNING: deletes data)
reset() {
    print_warning "This will delete all data in master and replica!"
    read -p "Are you sure? (yes/no): " confirmation
    
    if [ "$confirmation" = "yes" ]; then
        print_info "Stopping containers..."
        cd "$SCRIPT_DIR/master"
        docker-compose down -v
        
        cd "$SCRIPT_DIR/replica"
        docker-compose down -v
        
        print_info "Deleting data directories..."
        rm -rf "$SCRIPT_DIR/master/data"/*
        rm -rf "$SCRIPT_DIR/master/logs"/*
        rm -rf "$SCRIPT_DIR/replica/data"/*
        rm -rf "$SCRIPT_DIR/replica/logs"/*
        
        print_info "Reset completed. Run '$0 start' to restart."
    else
        print_info "Reset cancelled"
    fi
}

# Function to show usage
usage() {
    echo "Usage: $0 {start|stop|status|logs|reset|generate-certs|ssl-export|fix-permissions|help}"
    echo ""
    echo "Commands:"
    echo "  start            - Start MySQL Master and Replica with replication setup"
    echo "  stop             - Stop MySQL Master and Replica"
    echo "  status           - Show Master and Replica status"
    echo "  logs             - Show logs (usage: $0 logs [master|replica])"
    echo "  reset            - Reset all data (WARNING: deletes everything)"
    echo "  generate-certs   - Generate SSL certificates in ssl-certs/ folder"
    echo "  ssl-export       - Export SSL certificates from master (deprecated)"
    echo "  fix-permissions  - Fix all file and folder permissions"
    echo "  help             - Show this help message"
}

# Main script logic
case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    status)
        status
        ;;
    logs)
        logs "$@"
        ;;
    reset)
        reset
        ;;
    generate-certs)
        generate_ssl_certs
        ;;
    ssl-export)
        print_warning "ssl-export is deprecated. Use 'generate-certs' instead."
        setup_ssl
        ;;
    fix-permissions)
        setup_directories
        fix_permissions
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        print_error "Unknown command: $1"
        echo ""
        usage
        exit 1
        ;;
esac
