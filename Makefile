.PHONY: help install setup build sync clean clean-all status logs

help:
	@echo "RHEL Repository Sync - Available Commands"
	@echo "=========================================="
	@echo "install      - Install Ansible collections"
	@echo "setup        - Setup directory structure"
	@echo "build        - Build container images"
	@echo "sync         - Run repository synchronization"
	@echo "clean        - Stop and remove containers"
	@echo "clean-all    - Remove containers and images"
	@echo "status       - Show container status"
	@echo "logs         - Show container logs"
	@echo ""
	@echo "Usage: make <command>"

install:
	@echo "Installing Ansible collections..."
	ansible-galaxy collection install -r requirements.yml

setup:
	@echo "Setting up directory structure..."
	mkdir -p vars templates dockerfiles/scripts
	@echo "Directory structure created"

build:
	@echo "Building container images..."
	ansible-playbook rhel-repo-sync.yml --tags build

sync:
	@echo "Running repository synchronization..."
	ansible-playbook rhel-repo-sync.yml

clean:
	@echo "Stopping and removing containers..."
	podman stop rhel8-repo-sync rhel9-repo-sync rhel10-repo-sync 2>/dev/null || true
	podman rm rhel8-repo-sync rhel9-repo-sync rhel10-repo-sync 2>/dev/null || true

clean-all: clean
	@echo "Removing container images..."
	podman rmi rhel8-repo-sync:latest rhel9-repo-sync:latest rhel10-repo-sync:latest 2>/dev/null || true

status:
	@echo "Container Status:"
	@podman ps -a --filter "name=repo-sync"

logs:
	@echo "Container Logs (RHEL 8):"
	@podman logs rhel8-repo-sync 2>/dev/null || echo "Container not running"
	@echo ""
	@echo "Container Logs (RHEL 9):"
	@podman logs rhel9-repo-sync 2>/dev/null || echo "Container not running"

# Validation targets
validate-config:
	@echo "Validating configuration..."
	@ansible-playbook rhel-repo-sync.yml --syntax-check
	@echo "Configuration is valid"

test-rhel8:
	@echo "Testing RHEL 8 sync..."
	ansible-playbook rhel-repo-sync.yml -e "rhel_versions={'8':{'enabled':true},'9':{'enabled':false},'10':{'enabled':false}}"

test-rhel9:
	@echo "Testing RHEL 9 sync..."
	ansible-playbook rhel-repo-sync.yml -e "rhel_versions={'8':{'enabled':false},'9':{'enabled':true},'10':{'enabled':false}}"
