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

