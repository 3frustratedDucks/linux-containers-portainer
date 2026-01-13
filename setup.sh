#!/bin/bash
# Setup script for Portainer Docker container
# This script creates a complete Portainer setup for either server or agent installation

# Prevent script from being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script is being run directly
    :
else
    echo "This script should not be sourced. Please run it directly:"
    echo "./setup.sh"
    return 1
fi

# Get the project root directory based on the script location
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$SCRIPT_DIR"

# Configuration variables
CONTAINER_NAME_SERVER="portainer"
CONTAINER_NAME_AGENT="portainer-agent"
HOST_PORT_SERVER=9000
HOST_PORT_AGENT=9001
DATA_DIR="$PROJECT_ROOT/data"

# Color output for better readability
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting Portainer setup...${NC}"
echo -e "${GREEN}Project root: $PROJECT_ROOT${NC}"

# Prompt for installation type
echo ""
echo -e "${BLUE}What type of installation is this?${NC}"
echo -e "${YELLOW}1) Main Portainer Server (for RPI or main machine)${NC}"
echo -e "${YELLOW}2) Portainer Agent (for laptops/remote machines)${NC}"
echo ""
read -p "Enter your choice (1 or 2): " INSTALL_TYPE

if [[ "$INSTALL_TYPE" != "1" && "$INSTALL_TYPE" != "2" ]]; then
    echo -e "${RED}Invalid choice. Please run the script again and enter 1 or 2.${NC}"
    exit 1
fi

if [[ "$INSTALL_TYPE" == "1" ]]; then
    INSTALL_MODE="server"
    echo -e "${GREEN}Installing Portainer Server...${NC}"
else
    INSTALL_MODE="agent"
    echo -e "${GREEN}Installing Portainer Agent...${NC}"
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker not found. Installing Docker...${NC}"
    
    # Detect system type
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VERSION=$VERSION_ID
    else
        echo -e "${RED}Could not detect OS type. Please install Docker manually.${NC}"
        exit 1
    fi

    # Update package lists
    sudo apt-get update
    
    # Install common prerequisites
    sudo apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release

    if [[ "$OS" == *"Ubuntu"* ]]; then
        echo -e "${GREEN}Detected Ubuntu system. Installing Docker using Ubuntu repository...${NC}"
        # Add Docker's official GPG key
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

        # Add Docker repository for Ubuntu
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
          $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    elif [[ "$OS" == *"Raspberry Pi"* ]] || [[ "$OS" == *"Debian"* ]]; then
        echo -e "${GREEN}Detected Raspberry Pi OS/Debian system. Installing Docker using Debian repository...${NC}"
        # Add Docker's official GPG key
        curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

        # Add Docker repository for Debian
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \
          $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    else
        echo -e "${YELLOW}Unknown OS type. Attempting to install Docker using get.docker.com script...${NC}"
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        rm get-docker.sh
    fi

    # Update package lists again
    sudo apt-get update

    # Install Docker Engine
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io

    # Create docker group if it doesn't exist
    if ! getent group docker > /dev/null; then
        sudo groupadd docker
    fi

    # Add current user to docker group
    sudo usermod -aG docker $USER

    # Enable and start Docker service
    echo -e "${GREEN}Enabling Docker to start on boot...${NC}"
    sudo systemctl enable docker
    sudo systemctl start docker

    echo -e "${GREEN}Docker installed successfully. You may need to log out and back in for group changes to take effect.${NC}"
else
    echo -e "${GREEN}Docker is already installed.${NC}"
    # Ensure Docker is enabled to start on boot
    if ! systemctl is-enabled docker > /dev/null; then
        echo -e "${YELLOW}Enabling Docker to start on boot...${NC}"
        sudo systemctl enable docker
    fi
fi

# Check if Docker Compose is installed
if ! command -v docker compose &> /dev/null; then
    echo -e "${YELLOW}Docker Compose not found. Installing Docker Compose...${NC}"
    
    # Install Docker Compose plugin (modern method)
    sudo apt-get update
    sudo apt-get install -y docker-compose-plugin
    
    echo -e "${GREEN}Docker Compose installed successfully.${NC}"
else
    echo -e "${GREEN}Docker Compose is already installed.${NC}"
fi

# Create necessary directories
echo -e "${YELLOW}Creating directory structure...${NC}"
mkdir -p "$DATA_DIR"
mkdir -p "$PROJECT_ROOT/scripts"

# Create docker-compose.yml based on installation type
echo -e "${YELLOW}Creating docker-compose.yml...${NC}"

# Check if docker-compose.yml already exists
if [ -f "$PROJECT_ROOT/docker-compose.yml" ]; then
    echo -e "${YELLOW}Warning: docker-compose.yml already exists!${NC}"
    echo -e "${YELLOW}Running setup.sh will OVERWRITE your existing configuration.${NC}"
    echo -e "${YELLOW}Any customizations or comments will be lost.${NC}"
    echo ""
    read -p "Do you want to continue and overwrite it? (y/N): " OVERWRITE_CONFIRM
    if [[ ! "$OVERWRITE_CONFIRM" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Setup cancelled. Your existing docker-compose.yml is unchanged.${NC}"
        exit 0
    fi
    
    # Create backup before overwriting
    BACKUP_FILE="$PROJECT_ROOT/docker-compose.yml.backup.$(date +%Y%m%d-%H%M%S)"
    cp "$PROJECT_ROOT/docker-compose.yml" "$BACKUP_FILE"
    echo -e "${GREEN}Backup created: $BACKUP_FILE${NC}"
fi

if [[ "$INSTALL_MODE" == "server" ]]; then
    # Portainer Server configuration
    cat > "$PROJECT_ROOT/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  portainer:
    container_name: portainer
    image: portainer/portainer-ce:latest
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./data:/data
    ports:
      - "9000:9000"
      - "8000:8000"  # Edge agent communication (optional)
    # healthcheck:
    #   test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:9000/api/status"]
    #   interval: 30s
    #   timeout: 10s
    #   retries: 3
    #   start_period: 40s

networks:
  default:
    driver: bridge
EOF
    echo -e "${GREEN}Created docker-compose.yml for Portainer Server${NC}"
else
    # Portainer Agent configuration
    echo ""
    echo -e "${YELLOW}To connect this agent to your Portainer server, you'll need:${NC}"
    echo -e "${BLUE}1. The IP address or hostname of your Portainer server${NC}"
    echo -e "${BLUE}2. The agent key (generated in Portainer UI when adding an environment)${NC}"
    echo ""
    read -p "Enter Portainer server address (e.g., 192.168.1.100 or portainer.example.com): " SERVER_ADDRESS
    
    if [ -z "$SERVER_ADDRESS" ]; then
        echo -e "${YELLOW}No server address provided. You can configure it later in the docker-compose.yml file.${NC}"
        SERVER_ADDRESS="CHANGE_ME"
    fi
    
    cat > "$PROJECT_ROOT/docker-compose.yml" << EOF
version: '3.8'

services:
  portainer-agent:
    container_name: portainer-agent
    image: portainer/agent:latest
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /var/lib/docker/volumes:/var/lib/docker/volumes
      - /:/host:ro
    ports:
      - "9001:9001"
    environment:
      # Portainer server address
      - AGENT_CLUSTER_ADDR=${SERVER_ADDRESS}
    command:
      - --server-addr=${SERVER_ADDRESS}:8000
    # healthcheck:
    #   test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:9001/ping"]
    #   interval: 30s
    #   timeout: 10s
    #   retries: 3
    #   start_period: 40s

networks:
  default:
    driver: bridge
EOF
    echo -e "${GREEN}Created docker-compose.yml for Portainer Agent${NC}"
    echo -e "${YELLOW}Note: You may need to update the server address and add the agent key in Portainer UI.${NC}"
fi

# Create a management script
echo -e "${YELLOW}Creating management scripts...${NC}"
cat > "$PROJECT_ROOT/scripts/manage.sh" << 'EOF'
#!/bin/bash
# Portainer management script

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Detect installation type
if grep -q "portainer-ce" "$PROJECT_ROOT/docker-compose.yml"; then
    INSTALL_TYPE="server"
    CONTAINER_NAME="portainer"
    PORT=9000
else
    INSTALL_TYPE="agent"
    CONTAINER_NAME="portainer-agent"
    PORT=9001
fi

show_help() {
    echo "Portainer Management Script"
    echo ""
    echo "Installation type: $INSTALL_TYPE"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  start           Start Portainer"
    echo "  stop            Stop Portainer"
    echo "  restart         Restart Portainer"
    echo "  logs            Show Portainer logs"
    echo "  status          Show container status"
    echo "  update          Update Portainer to latest version"
    echo "  backup          Create a backup of data (server only)"
    echo "  restore [file]  Restore data from backup (server only)"
    echo "  shell           Access Portainer container shell"
    echo "  help            Show this help message"
    echo ""
}

start_portainer() {
    echo -e "${YELLOW}Starting Portainer $INSTALL_TYPE...${NC}"
    cd "$PROJECT_ROOT"
    docker compose up -d
    echo -e "${GREEN}Portainer $INSTALL_TYPE started successfully!${NC}"
    if [[ "$INSTALL_TYPE" == "server" ]]; then
        IP_ADDRESS=$(hostname -I | awk '{print $1}')
        echo -e "${BLUE}Access it at: http://${IP_ADDRESS}:9000${NC}"
    else
        echo -e "${BLUE}Agent is running on port 9001${NC}"
        echo -e "${YELLOW}Make sure it's connected to your Portainer server.${NC}"
    fi
}

stop_portainer() {
    echo -e "${YELLOW}Stopping Portainer $INSTALL_TYPE...${NC}"
    cd "$PROJECT_ROOT"
    docker compose down
    echo -e "${GREEN}Portainer $INSTALL_TYPE stopped successfully!${NC}"
}

restart_portainer() {
    echo -e "${YELLOW}Restarting Portainer $INSTALL_TYPE...${NC}"
    cd "$PROJECT_ROOT"
    docker compose restart
    echo -e "${GREEN}Portainer $INSTALL_TYPE restarted successfully!${NC}"
}

show_logs() {
    echo -e "${YELLOW}Showing Portainer logs (Ctrl+C to exit)...${NC}"
    cd "$PROJECT_ROOT"
    docker compose logs -f
}

show_status() {
    echo -e "${YELLOW}Container Status:${NC}"
    cd "$PROJECT_ROOT"
    docker compose ps
    echo ""
    echo -e "${YELLOW}System Resources:${NC}"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"
}

update_portainer() {
    echo -e "${YELLOW}Updating Portainer...${NC}"
    cd "$PROJECT_ROOT"
    docker compose pull
    docker compose up -d
    echo -e "${GREEN}Portainer updated successfully!${NC}"
}

backup_data() {
    if [[ "$INSTALL_TYPE" != "server" ]]; then
        echo -e "${RED}Backup is only available for Portainer Server installations.${NC}"
        exit 1
    fi
    
    BACKUP_DIR="$PROJECT_ROOT/backups"
    mkdir -p "$BACKUP_DIR"
    BACKUP_FILE="$BACKUP_DIR/portainer-data-$(date +%Y%m%d-%H%M%S).tar.gz"
    
    echo -e "${YELLOW}Creating backup...${NC}"
    tar -czf "$BACKUP_FILE" -C "$PROJECT_ROOT" data
    echo -e "${GREEN}Backup created: $BACKUP_FILE${NC}"
}

restore_data() {
    if [[ "$INSTALL_TYPE" != "server" ]]; then
        echo -e "${RED}Restore is only available for Portainer Server installations.${NC}"
        exit 1
    fi
    
    if [ -z "$1" ]; then
        echo -e "${RED}Please specify backup file to restore${NC}"
        echo "Usage: $0 restore /path/to/backup.tar.gz"
        exit 1
    fi
    
    if [ ! -f "$1" ]; then
        echo -e "${RED}Backup file not found: $1${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}Restoring data from $1...${NC}"
    echo -e "${RED}This will overwrite current data. Continue? (y/N)${NC}"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        stop_portainer
        tar -xzf "$1" -C "$PROJECT_ROOT"
        start_portainer
        echo -e "${GREEN}Data restored successfully!${NC}"
    else
        echo -e "${YELLOW}Restore cancelled${NC}"
    fi
}

access_shell() {
    echo -e "${YELLOW}Accessing Portainer container shell...${NC}"
    cd "$PROJECT_ROOT"
    docker compose exec "$CONTAINER_NAME" /bin/sh
}

case "$1" in
    start)
        start_portainer
        ;;
    stop)
        stop_portainer
        ;;
    restart)
        restart_portainer
        ;;
    logs)
        show_logs
        ;;
    status)
        show_status
        ;;
    update)
        update_portainer
        ;;
    backup)
        backup_data
        ;;
    restore)
        restore_data "$2"
        ;;
    shell)
        access_shell
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        show_help
        exit 1
        ;;
esac
EOF

chmod +x "$PROJECT_ROOT/scripts/manage.sh"

# Create .gitignore file
echo -e "${YELLOW}Creating .gitignore file...${NC}"
cat > "$PROJECT_ROOT/.gitignore" << 'EOF'
# Ignore everything
*

# But track these essential files
!setup.sh
!README.md
!docker-compose.yml
EOF

# Create README.md
echo -e "${YELLOW}Creating README.md with usage instructions...${NC}"
cat > "$PROJECT_ROOT/README.md" << 'EOF'
# Portainer Docker Setup

A complete Docker-based Portainer setup with support for both server and agent installations.

## Features

- **Portainer Server** - Full Portainer CE installation for managing Docker environments
- **Portainer Agent** - Lightweight agent for remote Docker hosts
- **Unified Setup Script** - Single script that works for both server and agent installations
- **Management Scripts** - Easy-to-use scripts for common operations
- **Backup & Restore** - Built-in backup and restore functionality (server only)
- **Security** - Proper security configurations and best practices

## Quick Start

### Prerequisites

- Docker and Docker Compose installed
- Linux system (tested on Ubuntu/Debian/Raspberry Pi OS)
- Network access for downloading Docker images

### Installation

1. **Clone or download this repository:**
   ```bash
   git clone <repository-url>
   cd portainer
   ```

2. **Run the setup script:**
   ```bash
   chmod +x setup.sh
   ./setup.sh
   ```

3. **Choose installation type:**
   - Enter `1` for **Portainer Server** (main installation on RPI or main machine)
   - Enter `2` for **Portainer Agent** (for laptops/remote machines)

4. **Start Portainer:**
   ```bash
   ./scripts/manage.sh start
   ```

5. **Access Portainer Server:**
   - Open your web browser
   - Navigate to `http://YOUR-IP:9000`
   - Create your admin account on first launch

## Installation Types

### Portainer Server

The server installation is for your main machine (typically the RPI). It provides:
- Web UI for managing Docker environments
- Centralized management of all agents
- User management and access control
- Environment templates and stacks

**Ports:**
- `9000` - Web UI
- `8000` - Edge agent communication (optional)

### Portainer Agent

The agent installation is for remote machines (laptops, other servers) that you want to manage. It provides:
- Lightweight agent service
- Connection to Portainer server
- Docker socket access for management

**Ports:**
- `9001` - Agent communication

## Management

Use the management script for common operations:

```bash
# Start Portainer
./scripts/manage.sh start

# Stop Portainer
./scripts/manage.sh stop

# Restart Portainer
./scripts/manage.sh restart

# View logs
./scripts/manage.sh logs

# Check status
./scripts/manage.sh status

# Update to latest version
./scripts/manage.sh update

# Create backup (server only)
./scripts/manage.sh backup

# Restore from backup (server only)
./scripts/manage.sh restore /path/to/backup.tar.gz

# Access container shell
./scripts/manage.sh shell
```

## Connecting Agents to Server

After installing an agent, you need to connect it to your Portainer server:

1. **Access Portainer Server UI:**
   - Navigate to `http://YOUR-SERVER-IP:9000`
   - Log in with your admin account

2. **Add Environment:**
   - Click on "Environments" in the left sidebar
   - Click "Add environment"
   - Select "Docker Standalone"
   - Choose "Agent" as the connection method

3. **Configure Agent:**
   - Portainer will generate an agent key
   - Copy the agent key or the full command
   - Update the `docker-compose.yml` on the agent machine with the server address
   - Ensure the agent can reach the server on port 8000

4. **Verify Connection:**
   - The agent should appear in your environments list
   - You can now manage that Docker host from Portainer

### Manual Agent Configuration

If you need to manually configure the agent connection, edit `docker-compose.yml`:

```yaml
environment:
  - AGENT_CLUSTER_ADDR=YOUR_SERVER_IP
command:
  - --server-addr=YOUR_SERVER_IP:8000
  - --agent-key=YOUR_AGENT_KEY  # Add this if provided by Portainer
```

## Directory Structure

```
./
├── docker-compose.yml          # Docker Compose configuration
├── setup.sh                   # Initial setup script
├── scripts/
│   └── manage.sh              # Management script
├── data/                      # Portainer data (server only)
└── backups/                   # Configuration backups (server only)
```

## Security

### Important Security Notes

1. **Network Security:**
   - Consider using HTTPS/SSL for Portainer server
   - Restrict access to trusted networks
   - Use firewall rules to limit access
   - Consider VPN for remote access

2. **Docker Socket Access:**
   - Agents have access to Docker socket (full Docker control)
   - Only install agents on trusted machines
   - Use proper authentication in Portainer

3. **Updates:**
   - Regularly update Portainer: `./scripts/manage.sh update`
   - Monitor security advisories
   - Keep Docker host system updated

### SSL/HTTPS Setup

To enable HTTPS for Portainer server:

1. Obtain SSL certificates (Let's Encrypt recommended)
2. Use a reverse proxy (nginx, Traefik, etc.)
3. Configure Portainer to work behind the proxy
4. Update firewall rules accordingly

## Backup and Restore

### Automatic Backups (Server Only)

Create regular backups:

```bash
# Create backup
./scripts/manage.sh backup

# Backups are stored in ./backups/ directory
```

### Restore Configuration (Server Only)

```bash
# Restore from backup
./scripts/manage.sh restore ./backups/portainer-data-20231201-120000.tar.gz
```

**Note:** Restoring will overwrite your current Portainer data. Make sure to backup first!

## Troubleshooting

### Common Issues

1. **Container won't start:**
   ```bash
   # Check logs
   ./scripts/manage.sh logs
   
   # Check Docker status
   sudo systemctl status docker
   ```

2. **Agent can't connect to server:**
   - Verify server address in `docker-compose.yml`
   - Check firewall rules (port 8000 must be open)
   - Ensure agent can reach server: `ping YOUR_SERVER_IP`
   - Check server logs for connection attempts

3. **Permission issues:**
   ```bash
   # Fix Docker socket permissions
   sudo chmod 666 /var/run/docker.sock
   
   # Or add user to docker group (requires logout/login)
   sudo usermod -aG docker $USER
   ```

4. **Port conflicts:**
   - Change ports in `docker-compose.yml`
   - Update firewall rules if needed
   - Check what's using the port: `sudo netstat -tulpn | grep :9000`

### Getting Help

- **Portainer Documentation:** https://docs.portainer.io/
- **Portainer Community:** https://github.com/portainer/portainer/discussions
- **Portainer GitHub:** https://github.com/portainer/portainer

## Advanced Configuration

### Custom Ports

Edit `docker-compose.yml` to change ports:

```yaml
ports:
  - "CUSTOM_PORT:9000"  # For server
  - "CUSTOM_PORT:9001"  # For agent
```

### Resource Limits

Add resource limits to `docker-compose.yml`:

```yaml
deploy:
  resources:
    limits:
      cpus: '0.5'
      memory: 512M
    reservations:
      cpus: '0.25'
      memory: 256M
```

### Multiple Agents

You can install multiple agents on different machines. Each agent needs:
- Unique container name (or let Docker Compose handle it)
- Access to the Portainer server
- Proper network configuration

## Updates and Maintenance

### Regular Maintenance

1. **Monthly:**
   - Update Portainer: `./scripts/manage.sh update`
   - Create backup: `./scripts/manage.sh backup`
   - Review logs for errors

2. **Quarterly:**
   - Review user access and permissions
   - Clean up unused environments
   - Check disk space usage

3. **Annually:**
   - Review security settings
   - Audit user accounts
   - Update SSL certificates if using HTTPS

### Version Management

- Portainer follows semantic versioning
- Breaking changes are announced in release notes
- Test updates in a development environment when possible
- Keep agents and server on compatible versions

## Contributing

Feel free to submit issues and enhancement requests!

## License

This project is licensed under the MIT License - see the LICENSE file for details.
EOF

# Create backups directory (for server)
if [[ "$INSTALL_MODE" == "server" ]]; then
    mkdir -p "$PROJECT_ROOT/backups"
fi

# Set proper permissions
echo -e "${YELLOW}Setting proper permissions...${NC}"
chmod +x "$PROJECT_ROOT/scripts/manage.sh"
chmod 755 "$DATA_DIR" 2>/dev/null || true

# Get the IP address
IP_ADDRESS=$(hostname -I | awk '{print $1}')

# Display completion information
echo ""
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}Portainer setup completed!${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""

if [[ "$INSTALL_MODE" == "server" ]]; then
    echo -e "${BLUE}Next steps:${NC}"
    echo -e "${YELLOW}1. Start Portainer Server:${NC}"
    echo -e "   ./scripts/manage.sh start"
    echo ""
    echo -e "${YELLOW}2. Access Portainer:${NC}"
    echo -e "   http://${IP_ADDRESS}:9000"
    echo ""
    echo -e "${YELLOW}3. Create your admin account on first launch${NC}"
    echo ""
    echo -e "${BLUE}Portainer management commands:${NC}"
    echo -e "${YELLOW}* Start:    ./scripts/manage.sh start${NC}"
    echo -e "${YELLOW}* Stop:     ./scripts/manage.sh stop${NC}"
    echo -e "${YELLOW}* Logs:     ./scripts/manage.sh logs${NC}"
    echo -e "${YELLOW}* Status:   ./scripts/manage.sh status${NC}"
    echo -e "${YELLOW}* Update:   ./scripts/manage.sh update${NC}"
    echo -e "${YELLOW}* Backup:   ./scripts/manage.sh backup${NC}"
    echo -e "${YELLOW}* Help:     ./scripts/manage.sh help${NC}"
else
    echo -e "${BLUE}Next steps:${NC}"
    echo -e "${YELLOW}1. Start Portainer Agent:${NC}"
    echo -e "   ./scripts/manage.sh start"
    echo ""
    echo -e "${YELLOW}2. Connect agent to Portainer Server:${NC}"
    echo -e "   - Access your Portainer server UI"
    echo -e "   - Go to Environments > Add Environment"
    echo -e "   - Select 'Docker Standalone' > 'Agent'"
    echo -e "   - Follow the instructions to connect"
    echo ""
    echo -e "${YELLOW}3. Verify connection in Portainer server${NC}"
    echo ""
    echo -e "${BLUE}Agent management commands:${NC}"
    echo -e "${YELLOW}* Start:    ./scripts/manage.sh start${NC}"
    echo -e "${YELLOW}* Stop:     ./scripts/manage.sh stop${NC}"
    echo -e "${YELLOW}* Logs:     ./scripts/manage.sh logs${NC}"
    echo -e "${YELLOW}* Status:   ./scripts/manage.sh status${NC}"
    echo -e "${YELLOW}* Update:   ./scripts/manage.sh update${NC}"
    echo -e "${YELLOW}* Help:     ./scripts/manage.sh help${NC}"
fi

echo ""
echo -e "${GREEN}For detailed instructions, see README.md${NC}"
echo -e "${GREEN}=====================================${NC}"

