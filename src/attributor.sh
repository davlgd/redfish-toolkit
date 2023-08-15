#!/bin/bash

echo -ne '\033]0;Attributor v0.1\007'

# Check for required tools
command -v curl >/dev/null 2>&1 || { echo >&2 "curl is not installed. Exiting."; exit 1; }
command -v xclip >/dev/null 2>&1 || command -v pbpaste >/dev/null 2>&1 || command -v gpaste >/dev/null 2>&1 || { echo >&2 "Clipboard tools (xclip, pbpaste, gpaste) are not available. Exiting."; exit 1; }

# Show helper
helper() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  --ip-range=A.B.C.D-E  Specify IP range for scan. No default value."
    echo "  --file-ip=FILENAME    Specify the IP file. Default is 'ip.txt'. Ignored if --ip-range is set."
    echo "  --max-tries=N         Specify maximum number of tries. Default is 10."
    echo "  --delay=N             Specify delay between each round in seconds. Default is 60."
    echo "  --endpoint=PATH       Specify the endpoint path. Default is '/redfish/v1/Chassis'"
    echo "  --username=NAME       Specify the username for authentication. Default is 'admin'"
    echo "  --encrypt             Encrypt the passwords in the output using a AES and a passphrase"
    echo "  --help                Display this help and exit."
    echo
}

# Defaults
FILE_IP="ip.txt"
OUTPUT_FILE="auth.crypt"
ENCRYPT=false
MAX_TRIES=10
DELAY=60
ENDPOINT_PATH="/redfish/v1/Chassis"
USERNAME="admin"

# Handle arguments
while [ "$#" -gt 0 ]; do
    case $1 in
        --help)
            helper
            exit 0
            ;;
        --encrypt)
            ENCRYPT=true
            shift
            ;;
        --ip-range=*)
            IP_RANGE="${1#*=}"
            shift
            ;;
        --file-ip=*)
            FILE_IP="${1#*=}"
            shift
            ;;
        --max-tries=*)
            MAX_TRIES="${1#*=}"
            shift
            ;;
        --delay=*)
            DELAY="${1#*=}"
            shift
            ;;
        --endpoint=*)
            ENDPOINT_PATH="${1#*=}"
            shift
            ;;
        --username=*)
            USERNAME="${1#*=}"
            shift
            ;;
        *)
            echo "Unrecognized option: $1"
            helper
            exit 1
            ;;
    esac
done

if $ENCRYPT; then
    echo -n "Enter an encryption 🔐: "
    read -rs ENCRYPTION_PASSPHRASE
    echo
    > $OUTPUT_FILE
fi

# IP List Creation
if [[ -n $IP_RANGE ]]; then
    IFS='-' read -ra ADDR <<< "$IP_RANGE"
    START_IP="${ADDR[0]}"
    END_NUM="${ADDR[1]}"
    BASE_IP=$(echo $START_IP | cut -d '.' -f 1-3)
    
    if [[ ! $START_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] || [[ ! $END_NUM =~ ^[0-9]{1,3}$ ]]; then
        echo "Invalid IP range format. Expected format is A.B.C.D-E"
        exit 1
    fi
    
    START_NUM=$(echo $START_IP | cut -d '.' -f 4)
    
    if ((START_NUM > END_NUM || START_NUM < 0 || START_NUM > 254 || END_NUM < 1 || END_NUM > 254)); then
        echo "Invalid start or end value for IP range."
        exit 1
    fi
    
    IPs=()
    for i in $(seq $START_NUM $END_NUM); do
        IPs+=("$BASE_IP.$i")
    done
else
    while IFS= read -r line; do
        IPs+=("$line")
    done < "$FILE_IP"
fi

function detect_passwords {
    # Check clipboard utilities
    # TODO : Redundant, to simplify  
    if command -v xclip >/dev/null 2>&1; then
        PASSWORDS=$(xclip -selection clipboard -o)
    elif command -v pbpaste >/dev/null 2>&1; then
        PASSWORDS=$(pbpaste)
    elif command -v gpaste >/dev/null 2>&1; then
        PASSWORDS=$(gpaste)
    else
        echo "Error: No clipboard utility detected. Install Gpaste, pbpaste, or xxlip."
        exit 1
    fi

    # Transform the clipboard data into an array
    IFS=$'\n' read -d '' -r -a PASSWORD_ARRAY <<< "$PASSWORDS"

    # Clear the previous line
    echo -ne "\033[1A" # Move to the previous line
    echo -ne "\033[K"  # Clear the current line
}

detect_passwords

while true; do
    NUM_PASSWORDS=${#PASSWORD_ARRAY[@]}
    echo -ne "$NUM_PASSWORDS 🔐 detected in your clipboard. Do you want to continue, detect again, or exit (c/d/e)? "
    read -r choice

    case "$choice" in
      c|C ) break;;
      e|E ) echo "Exiting..."; exit 1;;
      d|D ) 
            echo -ne "\033[2K\r" # Clear the current line
            detect_passwords
            continue
            ;;
      * ) echo "Invalid input";;
    esac
done

# Process initiation
echo "Starting the process to find matching IP:password pairs..."

try_count=0

# Simple encryption using OpenSSL with AES-256 encryption with the passphrase provided by the user
function encrypt_password {
    echo "$1" | openssl enc -aes-256-cbc -salt -pbkdf2 -a -pass pass:$ENCRYPTION_PASSPHRASE
}

while [[ ${#IPs[@]} -gt 0 && 
${#PASSWORD_ARRAY[@]} -gt 0 && $try_count -lt $MAX_TRIES ]]; do
    for ip_idx in "${!IPs[@]}"; do
        ip=${IPs[$ip_idx]}
        for pass_idx in "${!PASSWORD_ARRAY[@]}"; do
            password=${PASSWORD_ARRAY[$pass_idx]}
            
            # Skip empty passwords
            if [[ -z "$password" ]]; then
                continue
            fi

            ENDPOINT="https://$ip$ENDPOINT_PATH"
            response=$(curl -k -s -o /dev/null -w "%{http_code}" -X GET $ENDPOINT \
                -u $USERNAME:$password)

            if [ "$response" == "200" ]; then
                if $ENCRYPT; then
                    echo "$ip:✅"   
                    echo "$ip:$(encrypt_password $password)" >> $OUTPUT_
                FILE
                else
                    echo "$ip:$password"
                fi

                unset IPs[$ip_idx]
                unset PASSWORD_ARRAY[$pass_idx]
                break
            fi
        done
    done
    sleep $DELAY
    try_count=$((try_count + 1))
done
