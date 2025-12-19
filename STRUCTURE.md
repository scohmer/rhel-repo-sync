# Project Structure

```
rhel-repo-sync/
├── README.md                          # Comprehensive documentation
├── QUICKSTART.md                      # Quick start guide
├── .gitignore                         # Git ignore rules
├── Makefile                           # Convenience commands
├── repo-sync.sh                       # Main wrapper script
│
├── ansible.cfg                        # Ansible configuration
├── inventory                          # Ansible inventory (localhost)
├── requirements.yml                   # Ansible collection requirements
│
├── rhel-repo-sync.yml                # Main playbook
├── cleanup.yml                        # Cleanup playbook
│
├── vars/
│   ├── repo_config.yml               # Main configuration file
│   └── repo_config_airgapped_example.yml  # Example for airgapped env
│
├── templates/
│   └── local-repo.repo.j2            # Repository config template
│
└── dockerfiles/
    ├── Dockerfile.rhel8               # RHEL 8 UBI container
    ├── Dockerfile.rhel9               # RHEL 9 UBI container
    ├── Dockerfile.rhel10              # RHEL 10 UBI container
    └── scripts/
        └── sync-repos.sh              # Repository sync script
```

## File Descriptions

### Root Level Files

**README.md**
- Complete documentation
- Usage instructions
- Troubleshooting guide
- Best practices

**QUICKSTART.md**
- 5-minute setup guide
- Common tasks
- Quick reference

**Makefile**
- Convenience commands
- Build targets
- Testing shortcuts

**repo-sync.sh**
- Main execution wrapper
- User-friendly interface
- Command shortcuts

### Configuration Files

**ansible.cfg**
- Ansible settings
- Inventory location
- Privilege escalation

**inventory**
- Localhost definition
- Connection settings

**requirements.yml**
- Required Ansible collections
- containers.podman
- community.general

### Playbooks

**rhel-repo-sync.yml**
- Main orchestration playbook
- Container build and management
- Repository synchronization
- Metadata creation

**cleanup.yml**
- Container cleanup
- Image removal
- Data cleanup options

### Variables

**vars/repo_config.yml**
- Repository selection
- Package lists
- RHSM credentials
- Mirror settings
- Proxy configuration

**vars/repo_config_airgapped_example.yml**
- Example for disconnected environments
- Comprehensive package lists
- Advanced options

### Templates

**templates/local-repo.repo.j2**
- YUM/DNF repository configuration
- Generated per RHEL version
- File:// protocol URLs

### Dockerfiles

**dockerfiles/Dockerfile.rhel{8,9,10}**
- Based on official UBI images
- Installs sync tools
- Creates directory structure
- Copies sync script

**dockerfiles/scripts/sync-repos.sh**
- Repository synchronization logic
- RHSM registration
- Package download
- Metadata creation
- Error handling

## Data Flow

```
User Configuration (vars/repo_config.yml)
    ↓
Ansible Playbook (rhel-repo-sync.yml)
    ↓
Docker Build → Container Images (rhel{8,9,10}-repo-sync)
    ↓
Container Start → Mounts local directory
    ↓
Sync Script → Downloads packages and metadata
    ↓
Local Repository (/var/local-repos/rhel{8,9,10}/)
    ↓
Repository Config Files (*.repo)
    ↓
Target Systems (via HTTP or file://)
```

## Directory Creation

The playbook automatically creates:

```
/var/local-repos/                 # Base repository path
├── rhel8/                        # RHEL 8 repositories
│   ├── packages/                 # Downloaded packages
│   │   └── repodata/            # Repository metadata
│   ├── rhel-8-for-x86_64-baseos-rpms/
│   ├── rhel-8-for-x86_64-appstream-rpms/
│   └── local-rhel8.repo         # Repo config file
│
├── rhel9/                        # RHEL 9 repositories
│   ├── packages/
│   ├── rhel-9-for-x86_64-baseos-rpms/
│   └── local-rhel9.repo
│
├── rhel10/                       # RHEL 10 repositories (future)
│   └── local-rhel10.repo
│
└── dockerfiles/                  # Build context
    ├── Dockerfile.rhel8
    ├── Dockerfile.rhel9
    └── Dockerfile.rhel10
```

## Container Architecture

Each RHEL version has its own container:

```
Container: rhel8-repo-sync
├── Base Image: registry.access.redhat.com/ubi8/ubi:latest
├── Tools Installed:
│   ├── dnf-plugins-core
│   ├── createrepo_c
│   ├── yum-utils
│   ├── subscription-manager
│   └── sync-repos.sh
├── Volume Mount: /var/local-repos/rhel8:/var/local-repo
└── Environment:
    ├── REPOS="repo1,repo2"
    └── PACKAGES="pkg1,pkg2"
```

## Customization Points

1. **vars/repo_config.yml**
   - Enable/disable RHEL versions
   - Select repositories
   - Choose packages
   - Set credentials

2. **dockerfiles/scripts/sync-repos.sh**
   - Modify sync logic
   - Add custom repositories
   - Change metadata options
   - Add verification steps

3. **templates/local-repo.repo.j2**
   - Customize repo file format
   - Add GPG keys
   - Set priorities
   - Add excludes

4. **rhel-repo-sync.yml**
   - Add pre/post tasks
   - Integrate notifications
   - Add validation steps
   - Schedule updates

## Extension Points

### Adding Custom Repositories

1. Update `vars/repo_config.yml`:
```yaml
rhel_versions:
  "8":
    repos:
      - your-custom-repo
```

2. Ensure repo is enabled in container

### Adding Custom Packages

1. Update `vars/repo_config.yml`:
```yaml
rhel_versions:
  "8":
    packages:
      - your-package-name
```

2. Packages are auto-downloaded with dependencies

### Using with Red Hat Satellite

1. Configure Satellite URLs in repo definitions
2. Use activation keys instead of RHSM credentials
3. Update sync script for Satellite API

### Creating ISO Images

1. Install genisoimage: `dnf install genisoimage`
2. Add task to playbook:
```yaml
- name: Create ISO
  command: >
    genisoimage -o /tmp/rhel8-repo.iso
    -V "RHEL8-REPO" -R -J
    /var/local-repos/rhel8/
```

## Monitoring and Logging

**Container Logs:**
```bash
podman logs rhel8-repo-sync
```

**Sync Logs:**
```bash
cat /var/local-repos/rhel8/sync-*.log
```

**System Logs:**
```bash
journalctl -u podman
```

**Ansible Output:**
Stored in terminal output or:
```bash
ansible-playbook rhel-repo-sync.yml > sync-output.log 2>&1
```

## Security Considerations

1. **Credentials Storage**
   - Use ansible-vault for sensitive data
   - Restrict file permissions
   - Use environment variables

2. **Container Security**
   - Runs as root (required for subscription-manager)
   - SELinux labels on volumes (:Z)
   - No exposed network ports

3. **Repository Security**
   - GPG checking (optional)
   - HTTPS for remote repos
   - File permission management

4. **Network Security**
   - Firewall rules for HTTP serving
   - Access control lists
   - Proxy support
