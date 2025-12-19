# Quick Start Guide

Get up and running with RHEL repository synchronization in minutes.

## Prerequisites Check

```bash
# Check if Podman is installed
podman --version

# Check if Ansible is installed
ansible --version

# If not installed, install them:
sudo dnf install -y podman ansible-core
```

## 5-Minute Setup

### 1. Install Ansible Collections

```bash
ansible-galaxy collection install -r requirements.yml
```

### 2. Configure Your Environment

Edit `vars/repo_config.yml`:

```yaml
# Minimal configuration for testing
base_repo_path: /var/local-repos

rhel_versions:
  "8":
    enabled: true
    repos:
      - rhel-8-for-x86_64-baseos-rpms
    packages:
      - vim
      - git
    download_dependencies: true
  "9":
    enabled: false
  "10":
    enabled: false
```

**Note**: For UBI-only repos (no RHEL subscription needed), this works as-is!

### 3. Make Scripts Executable

```bash
chmod +x repo-sync.sh
chmod +x dockerfiles/scripts/sync-repos.sh
```

### 4. Run the Sync

**Option A: Using the wrapper script (recommended)**
```bash
./repo-sync.sh install  # First time only
./repo-sync.sh sync     # Run synchronization
```

**Option B: Using Ansible directly**
```bash
ansible-playbook rhel-repo-sync.yml
```

**Option C: Using Make**
```bash
make install  # First time only
make sync     # Run synchronization
```

## Verify Success

```bash
# Check container status
podman ps -a

# View logs
podman logs rhel8-repo-sync

# Check synced files
ls -lh /var/local-repos/rhel8/

# Check repository configuration
cat /var/local-repos/rhel8/local-rhel8.repo
```

## Common First-Time Tasks

### Sync Only RHEL 8

```bash
./repo-sync.sh sync --rhel8-only
```

### Sync Only RHEL 9

First, enable RHEL 9 in `vars/repo_config.yml`:
```yaml
rhel_versions:
  "9":
    enabled: true
```

Then sync:
```bash
./repo-sync.sh sync --rhel9-only
```

### Add More Packages

Edit `vars/repo_config.yml`:
```yaml
rhel_versions:
  "8":
    packages:
      - vim
      - git
      - httpd        # Add web server
      - postgresql   # Add database
      - ansible      # Add automation
```

Run sync again:
```bash
./repo-sync.sh sync
```

### Using With Red Hat Subscription

Edit `vars/repo_config.yml`:
```yaml
rhsm_username: "your-username@redhat.com"
rhsm_password: "your-password"

rhel_versions:
  "8":
    enabled: true
    repos:
      - rhel-8-for-x86_64-baseos-rpms
      - rhel-8-for-x86_64-appstream-rpms
      - rhel-8-for-x86_64-supplementary-rpms
```

Then sync:
```bash
./repo-sync.sh sync
```

## Test the Repository

### On the Same Host

```bash
# Copy repo file
sudo cp /var/local-repos/rhel8/local-rhel8.repo /etc/yum.repos.d/

# Clean and test
sudo dnf clean all
sudo dnf repolist

# Try installing a package
sudo dnf install vim
```

### Serve via HTTP (for other systems)

```bash
# Install and start httpd
sudo dnf install -y httpd
sudo systemctl start httpd
sudo firewall-cmd --add-service=http --permanent
sudo firewall-cmd --reload

# Create symlink
sudo ln -s /var/local-repos /var/www/html/repos

# Test access
curl http://localhost/repos/rhel8/
```

On client systems:
```bash
# Create repo file
sudo tee /etc/yum.repos.d/local-mirror.repo << EOF
[local-rhel8]
name=Local RHEL 8 Mirror
baseurl=http://YOUR_SERVER_IP/repos/rhel8/packages
enabled=1
gpgcheck=0
EOF

# Test
sudo dnf clean all
sudo dnf install vim
```

## Troubleshooting

### Container Won't Start
```bash
# Check logs
podman logs rhel8-repo-sync

# Rebuild container
podman rm -f rhel8-repo-sync
ansible-playbook rhel-repo-sync.yml
```

### Permission Denied Errors
```bash
# Fix SELinux contexts
sudo restorecon -Rv /var/local-repos/
```

### Disk Space Issues
```bash
# Check available space
df -h /var

# Minimum recommended: 50GB per RHEL version
```

### Sync Fails
```bash
# Check sync logs
podman exec rhel8-repo-sync cat /var/local-repo/sync-*.log

# Verify network connectivity
podman exec rhel8-repo-sync ping -c 3 cdn.redhat.com
```

## Next Steps

1. **Add More Repositories**
   - Review available repos: `subscription-manager repos --list`
   - Add to `vars/repo_config.yml`

2. **Schedule Regular Syncs**
   ```bash
   # Add to crontab
   0 2 * * 0 /path/to/repo-sync.sh sync > /var/log/repo-sync.log 2>&1
   ```

3. **Set Up for Production**
   - Use `ansible-vault` for credentials
   - Configure firewall rules
   - Set up monitoring
   - Document your package lists

4. **Enable More RHEL Versions**
   - Set `enabled: true` for RHEL 9
   - Adjust disk space accordingly

## Useful Commands

```bash
# Show container status
./repo-sync.sh status

# View recent logs
./repo-sync.sh logs

# Clean up containers
./repo-sync.sh clean

# Full cleanup (including images)
./repo-sync.sh cleanup

# Sync specific version
./repo-sync.sh sync --rhel8-only

# View help
./repo-sync.sh help
```

## Getting Help

1. Check the full [README.md](README.md) for detailed documentation
2. Review [vars/repo_config_airgapped_example.yml](vars/repo_config_airgapped_example.yml) for advanced configuration
3. Check container logs: `podman logs rhel8-repo-sync`
4. Verify playbook syntax: `ansible-playbook rhel-repo-sync.yml --syntax-check`

## Resources

- [Red Hat Container Registry](https://catalog.redhat.com/software/containers/explore)
- [RHEL Documentation](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/)
- [Podman Documentation](https://docs.podman.io/)
- [Ansible Documentation](https://docs.ansible.com/)
