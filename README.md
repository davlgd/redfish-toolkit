
# 🚀 Redfish Toolkit

A collection of utilities geared towards enhancing and simplifying interactions with the Redfish API. Whether you're an administrator looking to manage lots of servers or a developer eager to dive deep into Redfish-enabled systems, this toolkit should help you.

## 🛠 Technologies

- **Go (Golang)**: Leveraged for performance, ease of distribution, and platform independence.
- **Bash Scripting**: For flexible automation and utility creation.
- **Redfish API**: A modern standard for data center and systems management that stands as a powerful successor to IPMI and other legacy tools.
- **OpenSSL**: Used for secure password encryption and decryption.
- **cURL**: A foundational command-line tool for making HTTP requests.

## 🌟 Key Components

1. **redfish-cli**: A robust command-line interface tool meticulously crafted in Go. It simplifies Redfish API interactions, offering features like member exploration, pretty JSON outputs, and concurrent requests. [Learn More](#redfish-cli)

2. **Batch BMC Pass Changer**: A bash-scripted tool that automates BMC password updates across multiple servers via the Redfish API. With features like automatic password generation and optional encryption, it's a must-have for administrators. [Learn More](#Batch-BMC-Pass-Changer)

3. **decrypt**: This utility, embedded with OpenSSL capabilities, ensures your passwords remain confidential. Safeguard your data by decrypting passwords securely. [Learn More](#decrypt)

4. **attributor4**: IP address identification and password matching are made seamless with Attributor. Aimed at pinpointing security weak points, it integrates with the Redfish API for compatibility. [Learn More](#attributor)

---

### redfish-cli

**redfish-cli** is your command-line companion for Redfish API interactions. With its user-friendly interface, it's geared to enhance productivity for both system administrators and developers.

🎯 **Objectives**:
- Streamline RedFish API interactions from the terminal.
- Advanced features like JSON member exploration.
- Elegant error handling for clear, actionable feedback.

💡 **Usage**:
Navigate to the directory and start making requests:
```bash
./redfish-cli -ip 192.168.x.x -u user:pass -e Systems/Self
```
For a deeper dive, invoke the built-in help:
```bash
./redfish-cli --help
```

---

### Batch BMC Pass Changer

**batch-bmc-pass-changer.sh** stands as a testament to the power of automation. Update passwords across servers, generate strong passwords automatically, and even encrypt them for an added layer of security.

🚀 **Features**:
- Dry-run mode to visualize changes without committing them.
- Output saved passwords for future reference.

💡 **Usage**:
For quick execution with defaults:
```bash
./passchanger.sh
```
For a tailored approach:
```bash
./passchanger.sh -u myuser -i 2 -m openssl -l 24 --dry-run --encrypt -o output.txt
```

---

### decrypt

**decrypt** is your guardian against unauthorized data access. With OpenSSL at its heart, it guarantees the confidentiality of your passwords.

💡 **Usage**:
Make sure you have your decryption key, and simply run:
```bash
./decrypt.sh
```

---

### attributor

**attributor4** is the brainchild of a need to match IP addresses with potential passwords. While it's powerful, it comes with a plea: use ethically.

💡 **Usage**:
Kick off with a basic command:
```bash
./attributor.sh
```
Or specify an IP range:
```bash
./attributor.sh --ip-range=192.168.1.1-50
```

---

## 📜 License

The Redfish Toolkit and its components are licensed under the MIT License. Dive into the `LICENSE` file for more insights.

## 🤝 Contribute

To all seasoned developers out there, your expertise can make this toolkit even grander. We're all ears for pull requests and issues on our GitHub repository. Let's elevate the Redfish Toolkit together!