# CUPS Docker Image

A Docker image for CUPS (Common Unix Printing System) print server, providing a complete printing solution in a containerized environment. Includes Kubernetes deployment automation for easy container orchestration.

## Features

- Based on Debian Bookworm Slim for minimal footprint
- Includes complete CUPS installation with printer drivers
- Pre-configured with admin user and remote administration access
- Supports both USB and network printers
- Includes HPLIP for HP printer support
- Persistent configuration through volume mounting
- Kubernetes deployment with automated installation

## Quick Start

### Pull the Image

```bash
docker pull arembez/cups:latest
```

### Run the Container

```bash
docker run -d \
  --name cups-server \
  --privileged \
  -p 631:631 \
  -v ./config:/etc/cups \
  arembez/cups:latest
```

### Access CUPS Web Interface

Open your browser and navigate to:
```
http://localhost:631
```

**Default Credentials:**
- Username: `admin`
- Password: `admin`

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `ADMIN_PASSWORD` | Admin user password | `admin` |
| `NAMESPACE` | Kubernetes namespace | `cups` |
| `APP_NAME` | Application name | `cups` |

### Volumes

| Path | Description |
|------|-------------|
| `/etc/cups` | CUPS configuration directory (persistent) |

### Ports

| Port | Protocol | Description |
|------|----------|-------------|
| 631 | TCP | CUPS web interface and print service |

## Docker Usage Examples

### Basic Usage

```bash
# Run with custom admin password
docker run -d \
  --name cups-server \
  --privileged \
  -p 631:631 \
  -e ADMIN_PASSWORD=mysecretpassword \
  -v cups-config:/etc/cups \
  arembez/cups:latest

# Run with custom configuration volume
docker run -d \
  --name cups-server \
  --privileged \
  -p 631:631 \
  -v /path/to/cups-config:/etc/cups \
  arembez/cups:latest
```

### Connect Printers

1. Access the CUPS web interface at `http://localhost:631`
2. Navigate to "Administration" tab
3. Click "Add Printer"
4. Follow the wizard to configure your printer

### Using with Docker Compose

Create a `docker-compose.yml`:

```yaml
services:
  cups:
    build: .
    container_name: cups-server
    privileged: true
    ports:
      - "631:631"
    environment:
      - ADMIN_PASSWORD=admin
    volumes:
      - cups-config:/etc/cups
    restart: unless-stopped

volumes:
  cups-config:
```

Then run:
```bash
docker compose up -d
```

## Kubernetes Deployment

This project includes automated Kubernetes deployment with a comprehensive Makefile. The deployment creates:
- Namespace (configurable via `NAMESPACE`)
- Persistent Volume Claim for CUPS configuration
- Service with LoadBalancer for external access
- Deployment with CUPS container
- Secret for admin credentials

### Prerequisites

- Kubernetes cluster (v1.19+)
- `kubectl` configured with cluster access
- Default StorageClass for PVC
- LoadBalancer support (or use port-forwarding)

### Quick Kubernetes Deployment

```bash
# Clone the repository
git clone https://github.com/arembez/cups.git
cd k8s

# Deploy with default settings
make install

# OR Deploy with custom namespace and app name
# make install NAMESPACE=printing APP_NAME=cups-server
```

The installation process will:
1. Check Kubernetes prerequisites
2. Create the namespace
3. Generate or prompt for admin password
4. Apply all manifests
5. Wait for deployment readiness
6. Copy custom CUPS configuration (if available)
7. Display access information

### Deployment Commands

| Command | Description |
|---------|-------------|
| `make install` | Full installation with prerequisites check |
| `make update` | Update/Re-deploy all manifests |
| `make clean` | Remove everything (requires confirmation) |
| `make logs` | Show CUPS logs |
| `make shell` | Open shell in CUPS pod |
| `make status` | Show deployment status |

### Environment Variables for Make

You can customize the deployment by setting some variables or create a `.env` file:

```env
NAMESPACE=printing
APP_NAME=cups-server
ADMIN_PASSWORD=mysecurepassword
```

### Accessing the CUPS Web Interface in Kubernetes

After deployment, you can access the CUPS web interface:

**If LoadBalancer is available:**
```
http://<loadbalancer-ip>:631
```

**If LoadBalancer is not available:**
```bash
# Port-forward to access locally
kubectl port-forward -n cups svc/cups 631:631

# Then access at http://localhost:631
```

### Custom CUPS Configuration

To apply custom CUPS configuration during deployment:

1. Create a `cupsd.conf` file in the same directory as the Makefile
2. The installation process will automatically copy it to the pod
3. CUPS will be reloaded to apply the configuration

## Advanced Configuration

### Printer Drivers

The image includes the following driver packages:
- `foomatic-db-compressed-ppds` - Foomatic printer drivers
- `printer-driver-all` - All printer drivers
- `openprinting-ppds` - OpenPrinting PPD files
- `hplip` - HP printer drivers

## Security Notes

- Default admin password should be changed in production
- Consider using HTTPS for remote access
- Restrict network access to trusted hosts when possible

## Reset Admin Password

```bash
# Docker
docker exec -it cups-server bash -c passwd admin

# Kubernetes
kubectl exec -it -n cups deployment/cups -- bash -c passwd admin
```

## License

This image is distributed under the MIT license.

## Contributing

Issues and pull requests are welcome!

## Support

For issues with this Docker image, please open an issue on GitHub.

For CUPS-related issues, refer to the [CUPS documentation](https://www.cups.org/documentation.html).