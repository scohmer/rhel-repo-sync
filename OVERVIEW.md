# RHEL Repository Sync - Project Overview

## What This Does

This project provides a complete, automated solution for creating local offline RHEL repositories using:
- **Red Hat Universal Base Images (UBI)** - Official container images
- **Podman** - Container runtime
- **Ansible** - Infrastructure automation

You can sync repositories for RHEL 8, 9, and 10, specifying exactly which repos and packages you need.

## Key Features

✅ **Multi-Version Support** - Handle RHEL 8, 9, and 10 simultaneously
✅ **Flexible Configuration** - YAML-based repo and package selection
✅ **Automated Container Management** - Build, start, sync, all automated
✅ **Offline Repository Creation** - Perfect for air-gapped environments
✅ **Dependency Resolution** - Automatically downloads dependencies
✅ **Repository Metadata** - Creates proper YUM/DNF metadata
✅ **Easy Distribution** - Generate .repo files for client systems

## Quick Start (30 seconds)

```bash
# 1. Install dependencies
ansible-galaxy collection install -r requirements.yml

# 2. Make scripts executable (already done if using this package)
chmod +x repo-sync.sh dockerfiles/scripts/sync-repos.sh

# 3. Configure (edit vars/repo_config.yml)
vim vars/repo_config.yml

# 4. Run!
./repo-sync.sh sync
```

## Three Ways to Run

### 1. Wrapper Script (Easiest)
```bash
./repo-sync.sh sync
./repo-sync.sh status
./repo-sync.sh logs
```

### 2. Ansible Directly (Most Control)
```bash
ansible-playbook rhel-repo-sync.yml
ansible-playbook rhel-repo-sync.yml --rhel8-only
```

### 3. Make (Quick Commands)
```bash
make sync
make status
make clean
```

## File Locations

**Configuration**: `vars/repo_config.yml`
**Synced Repos**: `/var/local-repos/rhel{8,9,10}/`
**Repo Configs**: `/var/local-repos/rhel{8,9,10}/*.repo`
**Container Logs**: `podman logs rhel8-repo-sync`

## Architecture

```
┌─────────────────────┐
│  Ansible Playbook   │
└──────────┬──────────┘
           │
           ├─► Build UBI Containers (rhel8, rhel9, rhel10)
           │
           ├─► Start Containers with Volume Mounts
           │
           ├─► Execute sync-repos.sh in each container
           │   ├─► Register with RHSM (if credentials provided)
           │   ├─► Enable repositories
           │   ├─► Download repos/packages
           │   └─► Create repository metadata
           │
           └─► Generate .repo configuration files
```

## Use Cases

### 1. Air-Gapped Environment
Sync repos on internet-connected system, transfer to isolated network:
```bash
# On connected system
./repo-sync.sh sync

# Create archive
tar czf rhel-repos.tar.gz /var/local-repos/

# Transfer to air-gapped system
# Extract and use
```

### 2. Local Development Mirror
Faster package installs, consistent versions:
```bash
# Sync once
./repo-sync.sh sync

# Serve via HTTP
sudo systemctl start httpd
sudo ln -s /var/local-repos /var/www/html/repos
```

### 3. Custom Package Collections
Pre-download specific tools for deployment:
```bash
# In vars/repo_config.yml
packages:
  - kubernetes
  - docker-ce
  - gitlab-runner
  - jenkins
```

### 4. Disaster Recovery
Keep local copies of critical packages:
```bash
# Regular sync schedule
0 2 * * 0 /path/to/repo-sync.sh sync
```

## Common Scenarios

### Scenario 1: First Time Setup with RHEL Subscription

1. Edit `vars/repo_config.yml`:
```yaml
rhsm_username: "me@company.com"
rhsm_password: "mypassword"

rhel_versions:
  "8":
    enabled: true
    repos:
      - rhel-8-for-x86_64-baseos-rpms
      - rhel-8-for-x86_64-appstream-rpms
```

2. Run sync:
```bash
./repo-sync.sh sync
```

### Scenario 2: UBI-Only (No Subscription)

1. Keep credentials empty in `vars/repo_config.yml`:
```yaml
rhsm_username: ""
rhsm_password: ""

rhel_versions:
  "8":
    enabled: true
    repos: []  # UBI repos are default
    packages:
      - vim
      - git
```

2. Run sync:
```bash
./repo-sync.sh sync
```

### Scenario 3: Specific Packages Only

1. Configure packages without full repo sync:
```yaml
rhel_versions:
  "8":
    repos: []  # Don't sync entire repos
    packages:
      - ansible
      - podman
      - git
      - vim
    download_dependencies: true
```

2. Run sync:
```bash
./repo-sync.sh sync
```

## What Gets Created

After successful sync:

```
/var/local-repos/
└── rhel8/
    ├── packages/                    # Downloaded packages
    │   ├── vim-8.0.1763-15.el8.rpm
    │   ├── git-2.27.0-1.el8.rpm
    │   └── repodata/                # Repository metadata
    ├── rhel-8-for-x86_64-baseos-rpms/
    │   └── repodata/
    ├── rhel-8-for-x86_64-appstream-rpms/
    │   └── repodata/
    └── local-rhel8.repo             # YUM/DNF config file
```

## Client System Setup

### Method 1: File Mount
```bash
# Mount the repository directory
sudo mount -o ro server:/var/local-repos /mnt/repos

# Copy repo file
sudo cp /mnt/repos/rhel8/local-rhel8.repo /etc/yum.repos.d/

# Use it
sudo dnf install vim
```

### Method 2: HTTP Server
```bash
# On repository server
sudo dnf install -y httpd
sudo systemctl start httpd
sudo ln -s /var/local-repos /var/www/html/repos

# On client
sudo tee /etc/yum.repos.d/mirror.repo << EOF
[local-mirror]
name=Local Mirror
baseurl=http://repo-server/repos/rhel8/packages
enabled=1
gpgcheck=0
EOF

sudo dnf install vim
```

### Method 3: NFS Share
```bash
# On repository server
sudo dnf install -y nfs-utils
echo "/var/local-repos *(ro,sync)" | sudo tee -a /etc/exports
sudo systemctl start nfs-server

# On client
sudo mount repo-server:/var/local-repos /mnt/repos
```

## Monitoring & Maintenance

### Check Container Status
```bash
./repo-sync.sh status
# or
podman ps -a --filter "name=repo-sync"
```

### View Sync Logs
```bash
./repo-sync.sh logs
# or
podman logs rhel8-repo-sync
```

### Re-sync (Update)
```bash
./repo-sync.sh sync
```

### Cleanup
```bash
# Remove containers only
./repo-sync.sh clean

# Remove containers and images
./repo-sync.sh cleanup

# Remove everything including data
./repo-sync.sh cleanup --with-data
```

## Disk Space Requirements

Plan for these approximate sizes:

| Repository | Size (GB) | Notes |
|-----------|-----------|-------|
| RHEL 8 BaseOS | 5-8 | Core OS packages |
| RHEL 8 AppStream | 10-15 | Applications |
| RHEL 8 Supplementary | 2-5 | Additional packages |
| **Total per version** | **20-30** | With all repos |
| Custom packages | 1-5 | Depends on selection |

**Recommendation**: Allocate 50GB per RHEL version for safety.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Container won't start | Check logs: `podman logs rhel8-repo-sync` |
| Permission denied | Fix SELinux: `sudo restorecon -Rv /var/local-repos/` |
| Sync fails | Check network: `podman exec rhel8-repo-sync ping cdn.redhat.com` |
| Out of space | Check: `df -h /var`, expand or cleanup |
| RHSM registration fails | Verify credentials in `vars/repo_config.yml` |

## Security Best Practices

1. **Protect Credentials**
   ```bash
   ansible-vault encrypt vars/repo_config.yml
   ansible-playbook rhel-repo-sync.yml --ask-vault-pass
   ```

2. **Set Proper Permissions**
   ```bash
   chmod 600 vars/repo_config.yml
   chown root:root /var/local-repos
   ```

3. **Firewall Configuration**
   ```bash
   sudo firewall-cmd --add-service=http --permanent
   sudo firewall-cmd --reload
   ```

## Advanced Topics

### Using with Red Hat Satellite
See `vars/repo_config_airgapped_example.yml` for Satellite configuration.

### Creating ISO Images
Add this task to playbook for physical media transfer.

### Scheduled Syncs
```bash
# Add to crontab
0 2 * * 0 /path/to/repo-sync.sh sync >> /var/log/repo-sync.log 2>&1
```

### Multiple Architectures
Duplicate configuration for aarch64, ppc64le, etc.

## Resources

- **QUICKSTART.md** - Get started in 5 minutes
- **README.md** - Full documentation
- **STRUCTURE.md** - Project architecture
- **vars/repo_config_airgapped_example.yml** - Advanced config examples

## Support & Contributions

This is a complete, production-ready solution. Customize as needed:
- Add repositories in `vars/repo_config.yml`
- Modify sync logic in `dockerfiles/scripts/sync-repos.sh`
- Extend playbook in `rhel-repo-sync.yml`
- Adjust templates in `templates/`

## Summary

This project gives you everything needed to:
1. ✅ Build RHEL repository containers
2. ✅ Sync specific repositories and packages
3. ✅ Create offline mirrors
4. ✅ Distribute to client systems
5. ✅ Maintain and update regularly

All with simple commands:
```bash
./repo-sync.sh sync    # Run synchronization
./repo-sync.sh status  # Check status
./repo-sync.sh clean   # Cleanup
```

**You're ready to go!** 🚀
