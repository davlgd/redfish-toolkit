#!/bin/bash

echo -ne '\033]0;Batch BMC Pass Changer v0.1\007'

# Check for required tools
command -v curl >/dev/null 2>&1 || { echo >&2 "curl is not installed. Exiting."; exit 1; }
command -v xclip >/dev/null 2>&1 || command -v pbpaste >/dev/null 2>&1 || command -v gpaste >/dev/null 2>&1 || { echo >&2 "Clipboard tools (xclip, pbpaste, gpaste) are not available. Exiting."; exit 1; }

# Default values
USER="admin"
ID="1"
HEADERS="-H 'Content-Type: application/json' -H 'If-None-Match:\"\"'"
REQUEST_TYPE="PATCH"
MODE="gpg"
LENGTH=32
DRY_RUN=false
ENCRYPT=false
OUTPUT_FILE="newpass.crypt"

# Helper function to display usage
helper() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -u, --user      Target user (default: admin)"
    echo "  -i, --id        User ID (default: 1)"
    echo "  -H              Headers (default: Content-Type: application/json and If-None-Match:\"\"')"
    echo "  -X              Request type (default: PATCH)"
    echo "  -m, --mode      Password generation mode (gpg or openssl, default: gpg)"
    echo "  -l, --length    Password length (default: 32, min: 16)"
    echo "  --dry-run       Display the curl command without executing it"
    echo "  --encrypt       Encrypt the password for display and in output file"
    echo "  -o, --output    Output file name (default: newpass.crypt)"
    echo "  --help          Display this help and exit"
    echo
}

# Handle arguments
while [ "$#" -gt 0 ]; do
    case "$1" in
        -u|--user)
            USER="$2"
            shift 2
            ;;
        -i|--id)
            ID="$2"
            shift 2
            ;;
        -H)
            HEADERS="$2"
            shift 2
            ;;
        -X)
            REQUEST_TYPE="$2"
            shift 2
            ;;
        -m|--mode)
            MODE="$2"
            shift 2
            ;;
        -l|--length)
            LENGTH="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --encrypt)
            ENCRYPT=true
            shift
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --help)
            helper
            exit 0
            ;;
        *)
            echo "Unknown argument: $1"
            helper
            exit 1
            ;;
    esac
done

# Get the list of servers from clipboard
# TODO : Redundant, to simplify  
if command -v xclip >/dev/null 2>&1; then
    SERVER_LIST=$(xclip -o -selection clipboard)
elif command -v pbpaste >/dev/null 2>&1; then
    SERVER_LIST=$(pbpaste)
elif command -v gpaste >/dev/null 2>&1; then
    SERVER_LIST=$(gpaste)
fi

# Ask the user for encryption passphrase if --encrypt is used
if $ENCRYPT; then
    echo -n "Enter an encryption 🔐: "
    read -rs ENCRYPTION_PASSPHRASE
    echo
    > $OUTPUT_FILE
fi

# Encrypt password function
encrypt_password() {
    echo "$1" | openssl enc -aes-256-cbc -salt -pbkdf2 -a -pass pass:$ENCRYPTION_PASSPHRASE
}

# Function to generate a new password
generate_password() {
    local length="$1"
    if [ "$MODE" == "openssl" ]; then
        openssl rand -base64 48 | cut -c1-"$length"
    elif [ "$MODE" == "gpg" ]; then
        gpg --gen-random --armor 1 48 | cut -c1-"$length"
    fi
}

# Function to perform the curl request
execute_request() {
    local ip="$1"
    local current_pass="$2"
    local new_pass="$3"
    
    CURL_CMD="curl -s -o /dev/null -w \"%{http_code}\" -u \"$USER:$current_pass\" -X $REQUEST_TYPE \"https://$ip/redfish/v1/AccountService/Accounts/$ID\" $HEADERS -d \"{\\\"Password\\\": \\\"$new_pass\\\"}\""
    
    # Execute and clear CURL_CMD immediately after use
    if $DRY_RUN; then
        echo $CURL_CMD
    else
        RESPONSE=$(eval $CURL_CMD)
        display_result "$RESPONSE" "$ip" "$new_pass"
    fi
    unset CURL_CMD
}

# Function to display and record results
display_result() {
    local response="$1"
    local ip="$2"
    local pass="$3"
    
    # Display results based on response
    if [ "$response" == "204" ]; then
        echo "✅ $ip:$pass"
    else
        echo "❌ ($response) $ip:$pass"
    fi
    
    # Record the final password (encrypted or plaintext) into the file
    echo "$ip:$pass" >> "$OUTPUT_FILE"
}

# Loop to process each server
IFS=$'\n'
for SERVER in $SERVER_LIST; do
    IP=$(echo $SERVER | cut -d':' -f1)
    CURRENT_PASS=$(echo $SERVER | cut -d':' -f2)

    # Generate new password
    NEWPASS=$(generate_password $LENGTH)

    # Determine if password needs to be encrypted
    final_pass="$NEWPASS"
    if $ENCRYPT; then
        final_pass=$(encrypt_password "$NEWPASS")
    fi
    
    execute_request "$IP" "$CURRENT_PASS" "$final_pass"
    
    # Clear variables after they've been used
    unset IP CURRENT_PASS final_pass NEWPASS
done
