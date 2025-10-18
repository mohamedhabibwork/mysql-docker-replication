#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SSL_DIR="$SCRIPT_DIR/ssl-certs"

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

# Function to generate SSL certificates
generate_certificates() {
    print_info "Generating SSL certificates in $SSL_DIR..."
    
    # Create SSL directory if it doesn't exist
    mkdir -p "$SSL_DIR"
    
    # Check if certificates already exist
    if [ -f "$SSL_DIR/ca-cert.pem" ] && [ -f "$SSL_DIR/server-cert.pem" ] && [ -f "$SSL_DIR/client-cert.pem" ]; then
        print_warning "SSL certificates already exist in $SSL_DIR"
        read -p "Do you want to regenerate them? (yes/no): " regenerate
        if [ "$regenerate" != "yes" ]; then
            print_info "Keeping existing certificates"
            return 0
        fi
        print_info "Removing old certificates..."
        rm -f "$SSL_DIR"/*.pem
    fi
    
    cd "$SSL_DIR"
    
    # Generate CA key and certificate
    print_info "Generating CA key and certificate..."
    openssl genrsa 2048 > ca-key.pem
    openssl req -new -x509 -nodes -days 3650 -key ca-key.pem -out ca-cert.pem \
        -subj "/C=US/ST=State/L=City/O=Organization/OU=MySQL/CN=MySQL_CA"
    
    if [ $? -ne 0 ]; then
        print_error "Failed to generate CA certificate"
        return 1
    fi
    
    # Generate server key and certificate
    print_info "Generating server key and certificate..."
    openssl req -newkey rsa:2048 -days 3650 -nodes -keyout server-key.pem -out server-req.pem \
        -subj "/C=US/ST=State/L=City/O=Organization/OU=MySQL/CN=MySQL_Server"
    openssl rsa -in server-key.pem -out server-key.pem
    openssl x509 -req -in server-req.pem -days 3650 -CA ca-cert.pem -CAkey ca-key.pem -set_serial 01 -out server-cert.pem
    
    if [ $? -ne 0 ]; then
        print_error "Failed to generate server certificate"
        return 1
    fi
    
    # Generate client key and certificate
    print_info "Generating client key and certificate..."
    openssl req -newkey rsa:2048 -days 3650 -nodes -keyout client-key.pem -out client-req.pem \
        -subj "/C=US/ST=State/L=City/O=Organization/OU=MySQL/CN=MySQL_Client"
    openssl rsa -in client-key.pem -out client-key.pem
    openssl x509 -req -in client-req.pem -days 3650 -CA ca-cert.pem -CAkey ca-key.pem -set_serial 02 -out client-cert.pem
    
    if [ $? -ne 0 ]; then
        print_error "Failed to generate client certificate"
        return 1
    fi
    
    # Clean up temporary files
    rm -f server-req.pem client-req.pem
    
    # Set proper permissions
    print_info "Setting proper permissions..."
    chmod 644 ca-cert.pem server-cert.pem client-cert.pem
    chmod 600 ca-key.pem server-key.pem client-key.pem
    
    # Verify certificates
    print_info "Verifying certificates..."
    openssl verify -CAfile ca-cert.pem server-cert.pem client-cert.pem
    
    if [ $? -eq 0 ]; then
        print_info "✓ SSL certificates generated successfully!"
        print_info ""
        print_info "Generated files in $SSL_DIR:"
        ls -lh "$SSL_DIR"/*.pem
        print_info ""
        print_info "Next steps:"
        print_info "1. Run './mange.sh start' to use these certificates"
        print_info "2. Certificates are valid for 10 years (3650 days)"
    else
        print_error "Certificate verification failed"
        return 1
    fi
}

# Main execution
generate_certificates
