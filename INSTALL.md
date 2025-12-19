# Installation and Setup Instructions

## Prerequisites

Ensure your system has:
- RHEL/CentOS/Fedora (or compatible)
- Podman installed
- Ansible 2.9+ installed
- 50+ GB free disk space per RHEL version
- Internet connection (for initial sync)

## Step-by-Step Installation

### 1. Extract the Project

```bash
# If you downloaded as archive
tar xzf rhel-repo-sync.tar.gz
cd rhel-repo-sync

# Or if cloned from git
cd rhel-repo-sync
```

### 2. Install System Dependencies

```bash
# Install Podman
sudo dnf install -y podman

# Install Ansible
sudo dnf install -y ansible-core

# Verify installations
podman --version
ansible --version
```

### 3. Install Ansible Collections

```bash
# Install required collections
ansible-galaxy collection install -r requirements.yml
```

### 4. Verify File Permissions

```bash
# Ensure scripts are executable
chmod +x repo-sync.sh
chmod +x dockerfiles/scripts/sync-repos.sh

# Verify
ls -l repo-sync.sh dockerfiles/scripts/sync-repos.sh
```

### 5. Configure Your Environment

Edit the configuration file:

```bash
vim vars/repo_config.yml
```

**Minimal Configuration:**
```yaml
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
```

**For RHEL Subscription Access:**
```yaml
rhsm_username: "your-email@company.com"
rhsm_password: "your-password"
```

### 6. Create Repository Directory

```bash
# Create base directory
sudo mkdir -p /var/local-repos

# Set permissions (if needed)
sudo chown -R $USER:$USER /var/local-repos
```

### 7. Test the Setup

```bash
# Validate Ansible playbook syntax
ansible-playbook rhel-repo-sync.yml --syntax-check

# Should output: "playbook: rhel-repo-sync.yml"
```

### 8. Run First Sync

```bash
# Using the wrapper script (recommended)
./repo-sync.sh sync

# Or using Ansible directly
ansible-playbook rhel-repo-sync.yml

# Or using Make
make sync
```

### 9. Monitor Progress

```bash
# Watch container status
watch podman ps -a

# View logs in real-time
podman logs -f rhel8-repo-sync

# Check sync progress
./repo-sync.sh logs
```

### 10. Verify Success

```bash
# Check container status
./repo-sync.sh status

# Verify files were created
ls -lh /var/local-repos/rhel8/

# Check repository metadata
ls -lh /var/local-repos/rhel8/packages/repodata/

# View repo configuration
cat /var/local-repos/rhel8/local-rhel8.repo
```

## Quick Reference Commands

```bash
# Check what will be synced
cat vars/repo_config.yml

# Run synchronization
./repo-sync.sh sync

# Check status
./repo-sync.sh status

# View logs
./repo-sync.sh logs

# Clean up
./repo-sync.sh clean
```

## Troubleshooting Installation

### Issue: "ansible-galaxy: command not found"

**Solution:**
```bash
sudo dnf install -y ansible-core
# or
pip3 install --user ansible
```

### Issue: "podman: command not found"

**Solution:**
```bash
sudo dnf install -y podman
```

### Issue: Collection installation fails

**Solution:**
```bash
# Try with force
ansible-galaxy collection install -r requirements.yml --force

# Or install manually
ansible-galaxy collection install containers.podman
ansible-galaxy collection install community.general
```

### Issue: Permission denied on /var/local-repos

**Solution:**
```bash
sudo chown -R $USER:$USER /var/local-repos
# or
sudo chmod 755 /var/local-repos
```

### Issue: Container fails to start

**Solution:**
```bash
# Check Podman service
systemctl --user status podman.socket

# Check SELinux
getenforce
# If enforcing, check contexts:
ls -Z /var/local-repos
sudo restorecon -Rv /var/local-repos
```

### Issue: Sync script not executable

**Solution:**
```bash
chmod +x repo-sync.sh
chmod +x dockerfiles/scripts/sync-repos.sh
```

## Post-Installation

### Set Up HTTP Server (Optional)

```bash
# Install httpd
sudo dnf install -y httpd

# Create symlink
sudo ln -s /var/local-repos /var/www/html/repos

# Start service
sudo systemctl start httpd
sudo systemctl enable httpd

# Configure firewall
sudo firewall-cmd --add-service=http --permanent
sudo firewall-cmd --reload

# Test
curl http://localhost/repos/rhel8/
```

### Schedule Regular Syncs (Optional)

```bash
# Edit crontab
crontab -e

# Add weekly sync (Sundays at 2 AM)
0 2 * * 0 /path/to/rhel-repo-sync/repo-sync.sh sync >> /var/log/repo-sync.log 2>&1
```

### Secure Credentials (Recommended)

```bash
# Encrypt configuration with ansible-vault
ansible-vault encrypt vars/repo_config.yml

# Run playbook with vault password
ansible-playbook rhel-repo-sync.yml --ask-vault-pass

# Or use password file
echo "your-vault-password" > .vault_pass
chmod 600 .vault_pass
ansible-playbook rhel-repo-sync.yml --vault-password-file .vault_pass
```

## Next Steps

1. **Read Documentation**
   - OVERVIEW.md - Project overview
   - QUICKSTART.md - Quick start guide
   - README.md - Comprehensive documentation
   - STRUCTURE.md - Architecture details

2. **Customize Configuration**
   - Add more repositories
   - Add more packages
   - Enable multiple RHEL versions

3. **Set Up Distribution**
   - Configure HTTP/NFS sharing
   - Create client .repo files
   - Test on client systems

4. **Implement Automation**
   - Schedule regular syncs
   - Add monitoring
   - Set up notifications

## Support

For help with installation:
1. Check error messages carefully
2. Review log files
3. Verify prerequisites are met
4. Check file permissions
5. Test individual components

## File Checklist

Ensure all these files are present:

- [ ] README.md
- [ ] QUICKSTART.md
- [ ] OVERVIEW.md
- [ ] STRUCTURE.md
- [ ] Makefile
- [ ] repo-sync.sh
- [ ] ansible.cfg
- [ ] inventory
- [ ] requirements.yml
- [ ] rhel-repo-sync.yml
- [ ] cleanup.yml
- [ ] vars/repo_config.yml
- [ ] vars/repo_config_airgapped_example.yml
- [ ] templates/local-repo.repo.j2
- [ ] dockerfiles/Dockerfile.rhel8
- [ ] dockerfiles/Dockerfile.rhel9
- [ ] dockerfiles/Dockerfile.rhel10
- [ ] dockerfiles/scripts/sync-repos.sh

All files present? You're ready to go! 🚀

Run: `./repo-sync.sh sync`
