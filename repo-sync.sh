#!/bin/bash
#
# RHEL Repository Sync Wrapper Script
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/vars/repo_config.yml"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_banner() {
    echo -e "${GREEN}"
    echo "=========================================="
    echo "  RHEL Repository Synchronization Tool"
    echo "=========================================="
    echo -e "${NC}"
}

check_prerequisites() {
    echo -e "${YELLOW}Checking prerequisites...${NC}"
    
    # Check for Podman
    if ! command -v podman &> /dev/null; then
        echo -e "${RED}Error: Podman is not installed${NC}"
        echo "Install with: sudo dnf install -y podman"
        exit 1
    fi
    
    # Check for Ansible
    if ! command -v ansible-playbook &> /dev/null; then
        echo -e "${RED}Error: Ansible is not installed${NC}"
        echo "Install with: sudo dnf install -y ansible-core"
        exit 1
    fi
    
    # Check for configuration file
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}Error: Configuration file not found: $CONFIG_FILE${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ All prerequisites met${NC}"
}

install_collections() {
    echo -e "${YELLOW}Installing Ansible collections...${NC}"
    ansible-galaxy collection install -r "${SCRIPT_DIR}/requirements.yml"
    echo -e "${GREEN}✓ Collections installed${NC}"
}

show_usage() {
    cat << EOF
Usage: $0 [command] [options]

Commands:
    install     - Install Ansible collections
    sync        - Run repository synchronization
    status      - Show container status
    logs        - Show container logs
    clean       - Stop and remove containers
    cleanup     - Run cleanup playbook
    help        - Show this help message

Options:
    --rhel8-only    - Sync only RHEL 8 repositories
    --rhel9-only    - Sync only RHEL 9 repositories
    --no-images     - Don't remove images during cleanup
    --with-data     - Remove repository data during cleanup

Examples:
    $0 install                  # Install dependencies
    $0 sync                     # Sync all enabled versions
    $0 sync --rhel8-only        # Sync only RHEL 8
    $0 status                   # Check container status
    $0 clean                    # Remove containers
    $0 cleanup --with-data      # Full cleanup including data

EOF
}

run_sync() {
    local extra_args=""
    
    if [ "$1" == "--rhel8-only" ]; then
        extra_args="-e '{\"rhel_versions\":{\"8\":{\"enabled\":true},\"9\":{\"enabled\":false},\"10\":{\"enabled\":false}}}'"
    elif [ "$1" == "--rhel9-only" ]; then
        extra_args="-e '{\"rhel_versions\":{\"8\":{\"enabled\":false},\"9\":{\"enabled\":true},\"10\":{\"enabled\":false}}}'"
    fi
    
    echo -e "${YELLOW}Running repository synchronization...${NC}"
    cd "$SCRIPT_DIR"
    
    if [ -n "$extra_args" ]; then
        eval "ansible-playbook rhel-repo-sync.yml $extra_args"
    else
        ansible-playbook rhel-repo-sync.yml
    fi
    
    echo -e "${GREEN}✓ Synchronization complete${NC}"
}

show_status() {
    echo -e "${YELLOW}Container Status:${NC}"
    podman ps -a --filter "name=repo-sync" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
}

show_logs() {
    echo -e "${YELLOW}Recent logs from containers:${NC}"
    for container in rhel8-repo-sync rhel9-repo-sync rhel10-repo-sync; do
        if podman ps -a --format "{{.Names}}" | grep -q "$container"; then
            echo -e "\n${GREEN}=== $container ===${NC}"
            podman logs --tail 20 "$container" 2>/dev/null || echo "No logs available"
        fi
    done
}

run_clean() {
    echo -e "${YELLOW}Stopping and removing containers...${NC}"
    podman stop rhel8-repo-sync rhel9-repo-sync rhel10-repo-sync 2>/dev/null || true
    podman rm rhel8-repo-sync rhel9-repo-sync rhel10-repo-sync 2>/dev/null || true
    echo -e "${GREEN}✓ Containers removed${NC}"
}

run_cleanup() {
    local extra_args=""
    
    if [[ "$@" == *"--no-images"* ]]; then
        extra_args="$extra_args -e cleanup_images=false"
    else
        extra_args="$extra_args -e cleanup_images=true"
    fi
    
    if [[ "$@" == *"--with-data"* ]]; then
        extra_args="$extra_args -e cleanup_data=true"
    fi
    
    echo -e "${YELLOW}Running cleanup playbook...${NC}"
    cd "$SCRIPT_DIR"
    ansible-playbook cleanup.yml $extra_args
    echo -e "${GREEN}✓ Cleanup complete${NC}"
}

# Main execution
print_banner

case "${1:-help}" in
    install)
        check_prerequisites
        install_collections
        ;;
    sync)
        check_prerequisites
        run_sync "$2"
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs
        ;;
    clean)
        run_clean
        ;;
    cleanup)
        check_prerequisites
        run_cleanup "$@"
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo ""
        show_usage
        exit 1
        ;;
esac
