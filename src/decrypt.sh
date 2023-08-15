#!/bin/bash

# Check if openssl is installed
command -v openssl &> /dev/null || { echo "Error: openssl is not installed."; exit 1; }

# Ask the user to provide the passphrase for decryption
echo -n "Enter the encryption 🔐: "
read -rs ENCRYPTION_KEY
echo

# Read the pass.crypt file line by line
while IFS= read -r line; do
    # Retrieve the IP and encrypted password from the line
    IP=$(echo "$line" | cut -d ':' -f 1)
    ENCRYPTED_PASSWORD=$(echo "$line" | cut -d ':' -f 2-)

    # Use openssl to decrypt the password
    DECRYPTED_PASSWORD=$(echo "$ENCRYPTED_PASSWORD" | openssl enc -aes-256-cbc -d -a -pbkdf2 -pass pass:"$ENCRYPTION_KEY" 2>/dev/null)

    # Check if decryption failed
    [ $? -ne 0 ] && { echo "Error decrypting the line: $line"; continue; }

    # Display the IP and the plain password
    echo "$IP:$DECRYPTED_PASSWORD"

    # Clear decrypted data from the environment
    unset DECRYPTED_PASSWORD

done < pass.crypt

# Clear the encryption key from the environment
unset ENCRYPTION_KEY
