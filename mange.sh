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
    
    mkdir -p "$SCRIPT_DIR/master/data"
    mkdir -p "$SCRIPT_DIR/master/logs"
    mkdir -p "$SCRIPT_DIR/replica/data"
    mkdir -p "$SCRIPT_DIR/replica/logs"
    
    chmod 777 "$SCRIPT_DIR/master/data"
    chmod 777 "$SCRIPT_DIR/master/logs"
    chmod 777 "$SCRIPT_DIR/replica/data"
    chmod 777 "$SCRIPT_DIR/replica/logs"
    
    print_info "Directories created successfully"
}

# Function to start containers
start() {
    print_info "Starting MySQL Master and Replica..."
    
    setup_directories
    
    # Start master
    cd "$SCRIPT_DIR/master"
    print_info "Starting Master MySQL..."
    docker-compose up -d
    
    # Wait for master to be ready
    print_info "Waiting for Master to be ready..."
    sleep 15
    
    # Start replica
    cd "$SCRIPT_DIR/replica"
    print_info "Starting Replica MySQL..."
    docker-compose up -d
    
    # Wait for replica to be ready
    sleep 10
    
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
    docker exec $MASTER_CONTAINER mysql -u root -p$MASTER_ROOT_PASSWORD -e \
        "CREATE USER '$REPL_USER'@'%' IDENTIFIED BY '$REPL_PASSWORD'; \
         GRANT REPLICATION SLAVE ON *.* TO '$REPL_USER'@'%'; \
         FLUSH PRIVILEGES;" 2>/dev/null
    
    # Configure replica to replicate from master
    print_info "Configuring replica to replicate from master..."
    docker exec $REPLICA_CONTAINER mysql -u root -p$REPLICA_ROOT_PASSWORD -e \
        "CHANGE MASTER TO \
         MASTER_HOST='$MASTER_HOST_FROM_REPLICA', \
         MASTER_USER='$REPL_USER', \
         MASTER_PASSWORD='$REPL_PASSWORD', \
         MASTER_LOG_FILE='$BIN_LOG_FILE', \
         MASTER_LOG_POS=$BIN_LOG_POS; \
         START SLAVE;" 2>/dev/null
    
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
    
    source "$SCRIPT_DIR/replica/.env"
    REPLICA_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
    REPLICA_CONTAINER=$CONTAINER_NAME
    
    print_info "Master Status:"
    docker exec $MASTER_CONTAINER mysql -u root -p$MASTER_ROOT_PASSWORD -e "SHOW MASTER STATUS\G" 2>/dev/null
    
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
    echo "Usage: $0 {start|stop|status|logs|reset|help}"
    echo ""
    echo "Commands:"
    echo "  start      - Start MySQL Master and Replica with replication setup"
    echo "  stop       - Stop MySQL Master and Replica"
    echo "  status     - Show Master and Replica status"
    echo "  logs       - Show logs (usage: $0 logs [master|replica])"
    echo "  reset      - Reset all data (WARNING: deletes everything)"
    echo "  help       - Show this help message"
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
