#!/bin/bash

# Attributor v0.1
echo -ne '\033]0;Attributor v0.1\007'
echo "Attributor v0.1"

display_help() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  --ip-range=A.B.C.D-E  Specify IP range for scan. No default value."
    echo "  --file-ip=FILENAME    Specify the IP file. Default is 'ip.txt'. Ignored if --ip-range is set."
    echo "  --max-tries=N         Specify maximum number of tries. Default is 10."
    echo "  --delay=N             Specify delay between each round in seconds. Default is 60."
    echo "  --endpoint=PATH       Specify the endpoint path. Default is '/redfish/v1/Systems'"
    echo "  --username=NAME       Specify the username for authentication. Default is 'admin'"
    echo "  --help                Display this help and exit."
    echo
}

# Defaults
FILE_IP="ip.txt"
MAX_TRIES=10
DELAY=60
ENDPOINT_PATH="/redfish/v1/Systems"
USERNAME="admin"

# No arguments case
if [[ $# -eq 0 ]]; then
    display_help
    exit 0
fi

# Argument Parsing for --help
for arg in "$@"; do
    case $arg in
        --help)
        display_help
        exit 0
        ;;
    esac
done

# Argument Parsing for other arguments
for key in "$@"; do
    case $key in
        --ip-range=*)
        IP_RANGE="${key#*=}"
        ;;
        --file-ip=*)
        FILE_IP="${key#*=}"
        ;;
        --max-tries=*)
        MAX_TRIES="${key#*=}"
        ;;
        --delay=*)
        DELAY="${key#*=}"
        ;;
        --endpoint=*)
        ENDPOINT_PATH="${key#*=}"
        ;;
        --username=*)
        USERNAME="${key#*=}"
        ;;
        *)
        echo "Unknown argument: $key"
        exit 1
        ;;
    esac
done

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
    if command -v xclip >/dev/null 2>&1; then
        PASSWORDS=$(xclip -selection clipboard -o)
    elif command -v pbpaste >/dev/null 2>&1; then
        PASSWORDS=$(pbpaste)
    elif command -v clip.exe >/dev/null 2>&1; then
        PASSWORDS=$(clip.exe)
    else
        echo "Error: No clipboard utility detected. Install xclip, pbpaste, or clip.exe."
        exit 1
    fi

    # Transform the clipboard data into an array
    IFS=$'\n' read -d '' -r -a PASSWORD_ARRAY <<< "$PASSWORDS"
}

detect_passwords

while true; do
    NUM_PASSWORDS=${#PASSWORD_ARRAY[@]}
    echo -ne "$NUM_PASSWORDS 🔐 detected. Do you want to continue, detect again, or exit (y/n/d)? "
    read -r choice

    case "$choice" in
      y|Y ) break;;
      n|N ) echo "Exiting..."; exit 1;;
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

while [[ ${#IPs[@]} -gt 0 && ${#PASSWORD_ARRAY[@]} -gt 0 && $try_count -lt $MAX_TRIES ]]; do
    for ip_idx in "${!IPs[@]}"; do
        ip=${IPs[$ip_idx]}
        for pass_idx in "${!PASSWORD_ARRAY[@]}"; do
            password=${PASSWORD_ARRAY[$pass_idx]}
            
            # Skip empty passwords
            if [[ -z "$password" ]]; then
                continue
            fi
 
            ENDPOINT="https://$ip$ENDPOINT_PATH"
            response=$(curl -k -s -o /dev/null -w "%{http_code}" --connect-timeout 1 -X GET $ENDPOINT \
                -H "Content-Type: application/json" \
                -u $USERNAME:$password)

            if [ "$response" == "200" ]; then
                echo "$ip:$password"
                
                unset IPs[$ip_idx]
                unset PASSWORD_ARRAY[$pass_idx]
                break
            fi
           
            if [ "$response" == "000" ]; then
                unset IPs[$ip_idx]
                break
            fi
        done
    done
    sleep $DELAY
    try_count=$((try_count + 1))
done