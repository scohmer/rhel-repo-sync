# RHEL Repository Synchronization with Podman and Ansible

This project provides an automated solution for creating offline RHEL repositories using Universal Base Images (UBI) with Podman and Ansible.

## Features

- **Multi-Version Support**: RHEL 8, 9, and 10 (when available)
- **Containerized**: Uses official Red Hat UBI images
- **Podman-Based**: Leverages Podman for container management
- **Ansible Automation**: Automated build and sync process
- **Flexible Configuration**: Specify repositories and packages via YAML
- **Offline Repository Creation**: Create local mirrors for air-gapped environments

## Prerequisites

### System Requirements
- RHEL/CentOS/Fedora host system
- Podman installed and configured
- Ansible 2.9+ installed
- Sufficient disk space (varies by repository size)

### Software Installation

```bash
# Install Podman
sudo dnf install -y podman

# Install Ansible
sudo dnf install -y ansible-core

# Install Ansible collections
ansible-galaxy collection install -r requirements.yml
```

### Red Hat Subscription (Optional)
For syncing official Red Hat repositories, you need:
- Valid Red Hat subscription
- RHSM credentials OR
- Access to Red Hat Satellite/Capsule

## Project Structure

```
.
├── ansible.cfg                 # Ansible configuration
├── inventory                   # Ansible inventory
├── requirements.yml            # Ansible collection requirements
├── rhel-repo-sync.yml         # Main playbook
├── vars/
│   └── repo_config.yml        # Repository configuration
├── dockerfiles/
│   ├── Dockerfile.rhel8       # RHEL 8 UBI Dockerfile
│   ├── Dockerfile.rhel9       # RHEL 9 UBI Dockerfile
│   ├── Dockerfile.rhel10      # RHEL 10 UBI Dockerfile
│   └── scripts/
│       └── sync-repos.sh      # Repository sync script
└── templates/
    └── local-repo.repo.j2     # Repository config template
```

## Configuration

### 1. Edit Repository Configuration

Edit `vars/repo_config.yml` to specify:

```yaml
# Base path for repository storage
base_repo_path: /var/local-repos

# RHEL Subscription credentials (if using official repos)
rhsm_username: "your-username"
rhsm_password: "your-password"

# RHEL version configurations
rhel_versions:
  "8":
    enabled: true
    repos:
      - rhel-8-for-x86_64-baseos-rpms
      - rhel-8-for-x86_64-appstream-rpms
    packages:
      - vim
      - git
      - wget
    download_dependencies: true
```

### 2. Customize for Your Environment

**For UBI-only (no subscription required):**
- Leave `rhsm_username` and `rhsm_password` empty
- UBI repos are freely available

**For official RHEL repos:**
- Provide RHSM credentials
- List specific repository IDs

**For Satellite/Capsule:**
- Configure repos to point to your Satellite
- Adjust credentials accordingly

## Usage

### Quick Start

```bash
# Install dependencies
ansible-galaxy collection install -r requirements.yml

# Run the playbook
ansible-playbook rhel-repo-sync.yml

# Check container status
podman ps

# View logs
podman logs rhel8-repo-sync
```

### Customizing Repository Sync

#### Enable/Disable RHEL Versions

In `vars/repo_config.yml`:

```yaml
rhel_versions:
  "8":
    enabled: true   # Enable RHEL 8
  "9":
    enabled: false  # Disable RHEL 9
  "10":
    enabled: false  # Disable RHEL 10
```

#### Specify Repositories

```yaml
rhel_versions:
  "8":
    repos:
      - rhel-8-for-x86_64-baseos-rpms
      - rhel-8-for-x86_64-appstream-rpms
      - codeready-builder-for-rhel-8-x86_64-rpms
```

#### Specify Packages

```yaml
rhel_versions:
  "8":
    packages:
      - httpd
      - nginx
      - postgresql-server
      - mariadb-server
    download_dependencies: true  # Include all dependencies
```

### Advanced Usage

#### Manual Container Management

```bash
# Build specific version
podman build -t rhel8-repo-sync:latest \
  -f dockerfiles/Dockerfile.rhel8 \
  dockerfiles/

# Run container manually
podman run -d --name rhel8-repo-sync \
  -v /var/local-repos/rhel8:/var/local-repo:Z \
  -e REPOS="rhel-8-for-x86_64-baseos-rpms" \
  -e PACKAGES="vim,git,wget" \
  rhel8-repo-sync:latest

# Execute sync
podman exec rhel8-repo-sync /usr/local/bin/sync-repos.sh

# Stop and remove
podman stop rhel8-repo-sync
podman rm rhel8-repo-sync
```

#### Using the Synced Repository

After sync completes, repository files are in `/var/local-repos/rhel{8,9,10}/`

**Option 1: Copy repo file to target system**

```bash
# Copy the .repo file
sudo cp /var/local-repos/rhel8/local-rhel8.repo /etc/yum.repos.d/

# Update and test
sudo dnf clean all
sudo dnf repolist
```

**Option 2: Serve via HTTP**

```bash
# Install httpd
sudo dnf install -y httpd

# Create symlink
sudo ln -s /var/local-repos /var/www/html/repos

# Start httpd
sudo systemctl start httpd

# Configure firewall
sudo firewall-cmd --add-service=http --permanent
sudo firewall-cmd --reload
```

Then on client systems:

```bash
# Create repo file
cat << EOF | sudo tee /etc/yum.repos.d/local-mirror.repo
[local-rhel8-baseos]
name=Local RHEL 8 BaseOS Mirror
baseurl=http://your-server/repos/rhel8/rhel-8-for-x86_64-baseos-rpms
enabled=1
gpgcheck=0
EOF

sudo dnf clean all
sudo dnf repolist
```

## Repository Types

### BaseOS Repository
Core operating system packages

```yaml
repos:
  - rhel-8-for-x86_64-baseos-rpms
```

### AppStream Repository
Application streams and additional software

```yaml
repos:
  - rhel-8-for-x86_64-appstream-rpms
```

### Supplementary Repository
Additional packages not in BaseOS/AppStream

```yaml
repos:
  - rhel-8-for-x86_64-supplementary-rpms
```

### CodeReady Builder (CRB)
Development tools and libraries

```yaml
repos:
  - codeready-builder-for-rhel-8-x86_64-rpms  # RHEL 8
  - codeready-builder-for-rhel-9-x86_64-rpms  # RHEL 9
```

## Troubleshooting

### Container Won't Start

```bash
# Check Podman status
podman ps -a

# View container logs
podman logs rhel8-repo-sync

# Inspect container
podman inspect rhel8-repo-sync
```

### Repository Sync Fails

```bash
# Check sync logs in container
podman exec rhel8-repo-sync cat /var/local-repo/sync-*.log

# Verify RHSM registration
podman exec rhel8-repo-sync subscription-manager status

# Check enabled repos
podman exec rhel8-repo-sync dnf repolist
```

### Permission Issues

```bash
# Verify SELinux contexts
ls -Z /var/local-repos/

# Relabel if needed
sudo restorecon -Rv /var/local-repos/

# Check volume mounts
podman inspect rhel8-repo-sync | grep -A 5 Mounts
```

### Disk Space Issues

```bash
# Check disk usage
df -h /var/local-repos

# Check repository size
du -sh /var/local-repos/*

# Clean old metadata
find /var/local-repos -name "*.old" -delete
```

## Best Practices

1. **Disk Space Planning**
   - BaseOS: ~5-10 GB
   - AppStream: ~10-20 GB
   - Plan for 30-50 GB per RHEL version minimum

2. **Regular Updates**
   - Schedule periodic syncs (weekly/monthly)
   - Keep local mirrors up to date

3. **Network Bandwidth**
   - Initial sync is bandwidth-intensive
   - Consider off-peak hours for first sync

4. **Security**
   - Protect RHSM credentials
   - Use vault for sensitive data:
     ```bash
     ansible-vault create vars/secrets.yml
     ansible-vault encrypt vars/repo_config.yml
     ```

5. **Version Management**
   - Test new RHEL versions separately
   - Maintain separate directories per version

## Performance Tuning

### Speed Up Downloads

In `vars/repo_config.yml`:

```yaml
mirror_settings:
  download_metadata: true
  download_source: false      # Skip source RPMs
  download_debuginfo: false   # Skip debug packages
  newest_only: true           # Only latest versions
```

### Parallel Downloads

Modify `sync-repos.sh`:

```bash
reposync \
  --repoid="$repo" \
  --download-path="$LOCAL_REPO_PATH" \
  --newest-only \
  --norepopath \
  --download-metadata \
  --parallel=4  # Add parallel downloads
```

## Maintenance

### Update Repositories

```bash
# Re-run the playbook
ansible-playbook rhel-repo-sync.yml

# Or sync specific version
ansible-playbook rhel-repo-sync.yml -e "rhel_versions={'8':{'enabled':true}}"
```

### Clean Old Packages

```bash
# Remove old package versions
repomanage --old /var/local-repos/rhel8/packages | xargs rm -f

# Recreate metadata
createrepo_c --update /var/local-repos/rhel8/packages
```

## License

This project is provided as-is for educational and operational purposes.

## Support

For issues and questions:
1. Check container logs: `podman logs <container-name>`
2. Review sync script output in `/var/local-repo/sync-*.log`
3. Verify configuration in `vars/repo_config.yml`

## Contributing

Contributions welcome! Areas for improvement:
- Additional repository sources
- Enhanced error handling
- Progress indicators
- Incremental sync support
- Web UI for repository browsing
