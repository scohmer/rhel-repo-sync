#!/bin/bash
#
# Repository Synchronization Script
# Syncs specified repositories and packages to local directory
#

set -e

# Configuration from environment variables
REPOS="${REPOS:-}"
PACKAGES="${PACKAGES:-}"
DOWNLOAD_DEPS="${DOWNLOAD_DEPS:-true}"
LOCAL_REPO_PATH="${LOCAL_REPO_PATH:-/var/local-repo}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run as root"
    exit 1
fi

# Create local repo directory
mkdir -p "$LOCAL_REPO_PATH"

# Function to register with RHSM if credentials provided
register_rhsm() {
    if [ -n "$RHSM_USERNAME" ] && [ -n "$RHSM_PASSWORD" ]; then
        log_info "Registering with Red Hat Subscription Manager..."
        subscription-manager register \
            --username="$RHSM_USERNAME" \
            --password="$RHSM_PASSWORD" \
            --auto-attach || log_warn "RHSM registration failed or already registered"
    else
        log_info "No RHSM credentials provided, skipping registration"
    fi
}

# Function to enable repositories
enable_repos() {
    if [ -z "$REPOS" ]; then
        log_warn "No repositories specified"
        return
    fi

    IFS=',' read -ra REPO_ARRAY <<< "$REPOS"
    for repo in "${REPO_ARRAY[@]}"; do
        repo=$(echo "$repo" | xargs) # Trim whitespace
        log_info "Enabling repository: $repo"
        subscription-manager repos --enable="$repo" || \
            dnf config-manager --enable "$repo" || \
            log_warn "Failed to enable repository: $repo"
    done
}

# Function to sync full repositories
sync_full_repos() {
    if [ -z "$REPOS" ]; then
        log_warn "No repositories to sync"
        return
    fi

    IFS=',' read -ra REPO_ARRAY <<< "$REPOS"
    for repo in "${REPO_ARRAY[@]}"; do
        repo=$(echo "$repo" | xargs)
        log_info "Syncing repository: $repo"
        
        REPO_DIR="$LOCAL_REPO_PATH/$repo"
        mkdir -p "$REPO_DIR"
        
        # Use reposync to download repository
        reposync \
            --repoid="$repo" \
            --download-path="$LOCAL_REPO_PATH" \
            --download-metadata \
            --newest-only \
            2>&1 | tee -a "$LOCAL_REPO_PATH/sync-$repo.log" || \
            log_warn "Repository sync failed for: $repo"
    done
}

# Function to download specific packages
download_packages() {
    if [ -z "$PACKAGES" ]; then
        log_info "No specific packages to download"
        return
    fi

    log_info "Downloading specified packages..."
    PACKAGES_DIR="$LOCAL_REPO_PATH/packages"
    mkdir -p "$PACKAGES_DIR"
    
    IFS=',' read -ra PKG_ARRAY <<< "$PACKAGES"
    for pkg in "${PKG_ARRAY[@]}"; do
        pkg=$(echo "$pkg" | xargs)
        log_info "Downloading package: $pkg"
        
        if [ "$DOWNLOAD_DEPS" == "true" ]; then
            dnf download \
                --resolve \
                --destdir="$PACKAGES_DIR" \
                "$pkg" || log_warn "Failed to download package: $pkg"
        else
            dnf download \
                --destdir="$PACKAGES_DIR" \
                "$pkg" || log_warn "Failed to download package: $pkg"
        fi
    done
}

# Function to create repository metadata
create_repo_metadata() {
    log_info "Creating repository metadata..."
    
    # Create metadata for each synced repo
    if [ -d "$LOCAL_REPO_PATH" ]; then
        for repo_dir in "$LOCAL_REPO_PATH"/*; do
            if [ -d "$repo_dir" ] && [ -n "$(ls -A "$repo_dir"/*.rpm 2>/dev/null)" ]; then
                log_info "Creating metadata for: $(basename "$repo_dir")"
                createrepo_c "$repo_dir" || log_warn "Failed to create metadata for: $repo_dir"
            fi
        done
    fi
    
    # Create metadata for packages directory
    if [ -d "$LOCAL_REPO_PATH/packages" ] && [ -n "$(ls -A "$LOCAL_REPO_PATH/packages"/*.rpm 2>/dev/null)" ]; then
        log_info "Creating metadata for packages directory"
        createrepo_c "$LOCAL_REPO_PATH/packages"
    fi
}

# Function to generate repo file
generate_repo_file() {
    log_info "Generating .repo configuration file..."
    REPO_FILE="$LOCAL_REPO_PATH/local-repo.repo"
    
    cat > "$REPO_FILE" << EOF
# Local Repository Configuration
# Generated: $(date)

[local-packages]
name=Local Package Repository
baseurl=file://$LOCAL_REPO_PATH/packages
enabled=1
gpgcheck=0
EOF

    if [ -n "$REPOS" ]; then
        IFS=',' read -ra REPO_ARRAY <<< "$REPOS"
        for repo in "${REPO_ARRAY[@]}"; do
            repo=$(echo "$repo" | xargs)
            cat >> "$REPO_FILE" << EOF

[local-$repo]
name=Local Mirror - $repo
baseurl=file://$LOCAL_REPO_PATH/$repo
enabled=1
gpgcheck=0
EOF
        done
    fi
    
    log_info "Repository file created: $REPO_FILE"
}

# Function to display summary
display_summary() {
    log_info "=== Repository Sync Summary ==="
    
    if [ -d "$LOCAL_REPO_PATH" ]; then
        total_size=$(du -sh "$LOCAL_REPO_PATH" | cut -f1)
        rpm_count=$(find "$LOCAL_REPO_PATH" -name "*.rpm" | wc -l)
        
        log_info "Total Size: $total_size"
        log_info "Total RPM Packages: $rpm_count"
        
        if [ -n "$REPOS" ]; then
            log_info "Synced Repositories: $REPOS"
        fi
        
        if [ -n "$PACKAGES" ]; then
            log_info "Downloaded Packages: $PACKAGES"
        fi
    fi
    
    log_info "Repository location: $LOCAL_REPO_PATH"
}

# Main execution
main() {
    log_info "Starting repository synchronization..."
    log_info "Target directory: $LOCAL_REPO_PATH"
    
    # Register with RHSM if needed
    register_rhsm
    
    # Enable repositories
    enable_repos
    
    # Sync repositories
    sync_full_repos
    
    # Download specific packages
    download_packages
    
    # Create repository metadata
    create_repo_metadata
    
    # Generate repo configuration file
    generate_repo_file
    
    # Display summary
    display_summary
    
    log_info "Repository synchronization completed!"
}

# Execute main function
main "$@"
