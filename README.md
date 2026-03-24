# CUPS Docker Image

A Docker image for CUPS (Common Unix Printing System) print server, providing a complete printing solution in a containerized environment.

## Features

- Based on Debian Bookworm Slim for minimal footprint
- Includes complete CUPS installation with printer drivers
- Pre-configured with admin user and remote administration access
- Supports both USB and network printers
- Includes HPLIP for HP printer support
- Persistent configuration through volume mounting

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

### Volumes

| Path | Description |
|------|-------------|
| `/etc/cups` | CUPS configuration directory (persistent) |

### Ports

| Port | Protocol | Description |
|------|----------|-------------|
| 631 | TCP | CUPS web interface and print service |

## Usage Examples

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
version: '3.8'

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
docker-compose up -d
```

## Advanced Configuration

### Custom CUPS Configuration

To customize CUPS settings:

1. Stop the container
2. Edit the configuration files in your volume mount
3. Restart the container

```bash
docker stop cups-server
# Edit /path/to/cups-config/cupsd.conf
docker start cups-server
```

### Printer Drivers

The image includes the following driver packages:
- `foomatic-db-compressed-ppds` - Foomatic printer drivers
- `printer-driver-all` - All printer drivers
- `openprinting-ppds` - OpenPrinting PPD files
- `hplip` - HP printer drivers

### Adding Additional Drivers

If you need additional printer drivers, you can extend this image:

```dockerfile
FROM arembez/cups:latest

RUN apt-get update && \
    apt-get install -y \
    your-additional-driver-package && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
```

## Security Notes

- The container runs with `--privileged` flag to allow USB device access
- Default admin password should be changed in production
- Consider using HTTPS for remote access
- Restrict network access to trusted hosts when possible

## Troubleshooting

### Check CUPS Status

```bash
docker exec cups-server cupsctl
docker exec cups-server lpstat -t
```

### View Logs

```bash
# Container logs
docker logs cups-server

# CUPS error log
docker exec cups-server tail -f /var/log/cups/error_log
```

### USB Printer Not Detected

Ensure USB devices are passed through:

```bash
docker run -d \
  --name cups-server \
  --privileged \
  -v /dev/bus/usb:/dev/bus/usb \
  -p 631:631 \
  arembez/cups:latest
```

### Reset Admin Password

```bash
docker exec -it cups-server bash
passwd admin
# Enter new password
exit
```

## Building from Source

```bash
git clone your-repo-url
cd cups-docker
docker build -t cups:latest \
  --build-arg VCS_REF=$(git rev-parse --short HEAD) \
  --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  .
```

## License

This image is distributed under the MIT license.

## Contributing

Issues and pull requests are welcome!

## Support

For issues with this Docker image, please open an issue on GitHub.

For CUPS-related issues, refer to the [CUPS documentation](https://www.cups.org/documentation.html).
```
