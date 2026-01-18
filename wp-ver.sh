#!/bin/bash
# wp_version_detector.sh
# Detect WordPress version with multiple methods

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log() { echo -e "${BLUE}[*]${NC} $1"; }
success() { echo -e "${GREEN}[+]${NC} $1"; }
warning() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[-]${NC} $1"; }
info() { echo -e "${CYAN}[i]${NC} $1"; }
version() { echo -e "${PURPLE}[v]${NC} $1"; }

# Banner
echo -e "${CYAN}"
cat << "EOF"
 __      __      __      __   __      ___      __        __  ___  __  
/__`    |__)    /__`    |__) /__`    |__  \_/ |__)  /\  |__)  |  /__` 
.__/    |  \    .__/    |__) .__/    |___ / \ |  \ /~~\ |  \  |  .__/ 
                                                                      
EOF
echo -e "${NC}"
echo "WordPress Version Detector"
echo "==========================="

# Check dependencies
check_deps() {
    log "Checking dependencies..."
    local deps=("curl" "grep" "sed" "awk")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        error "Missing dependencies: ${missing[*]}"
        exit 1
    fi
    
    # Check optional tools
    if ! command -v wpscan &> /dev/null; then
        warning "wpscan not found (optional, for advanced detection)"
    fi
    
    success "Dependencies OK"
}

# Clean URL
clean_url() {
    local url="$1"
    
    # Remove protocol
    url="${url#http://}"
    url="${url#https://}"
    
    # Remove trailing slash
    url="${url%/}"
    
    # Remove path after domain
    url="${url%%/*}"
    
    echo "$url"
}

# Get accessible URL
get_accessible_url() {
    local url="$1"
    
    # Try HTTPS first
    https_code=$(curl -s -o /dev/null -w "%{http_code}" -L --max-time 10 "https://$url" 2>/dev/null || echo "000")
    
    if [ "$https_code" = "200" ] || [ "$https_code" = "301" ] || [ "$https_code" = "302" ]; then
        echo "https://$url"
        return 0
    fi
    
    # Try HTTP
    http_code=$(curl -s -o /dev/null -w "%{http_code}" -L --max-time 10 "http://$url" 2>/dev/null || echo "000")
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "301" ] || [ "$http_code" = "302" ]; then
        echo "http://$url"
        return 0
    fi
    
    error "Could not access $url"
    return 1
}

# Method 1: Check readme.html
method_readme() {
    local base_url="$1"
    log "Method 1: Checking readme.html..."
    
    readme_url="${base_url}/readme.html"
    readme_content=$(curl -s -L --max-time 10 "$readme_url" 2>/dev/null || true)
    
    if [ -n "$readme_content" ]; then
        # Look for version in readme
        if echo "$readme_content" | grep -q -i "wordpress.*[0-9]"; then
            version=$(echo "$readme_content" | grep -o -E "WordPress [0-9]+\.[0-9]+(\.[0-9]+)?" | head -1 | awk '{print $2}')
            if [ -n "$version" ]; then
                version "Found in readme.html: WordPress $version"
                echo "$version"
                return 0
            fi
        fi
        
        # Alternative pattern in readme
        version=$(echo "$readme_content" | grep -o -E "Version [0-9]+\.[0-9]+(\.[0-9]+)?" | head -1 | awk '{print $2}')
        if [ -n "$version" ]; then
            version "Found in readme.html: Version $version"
            echo "$version"
            return 0
        fi
    fi
    
    warning "readme.html not found or no version"
    return 1
}

# Method 2: Check generator meta tag
method_meta_generator() {
    local base_url="$1"
    log "Method 2: Checking generator meta tag..."
    
    homepage=$(curl -s -L --max-time 10 "$base_url/" 2>/dev/null || true)
    
    if [ -n "$homepage" ]; then
        # Look for WordPress generator meta tag
        generator=$(echo "$homepage" | grep -i 'meta.*name="generator"' | grep -i wordpress)
        
        if [ -n "$generator" ]; then
            # Extract version
            version=$(echo "$generator" | grep -o -E '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
            
            if [ -n "$version" ]; then
                version "Found in generator meta: WordPress $version"
                echo "$version"
                return 0
            else
                version "WordPress detected (no version in generator)"
                echo "unknown"
                return 0
            fi
        fi
    fi
    
    warning "Generator meta tag not found"
    return 1
}

# Method 3: Check CSS/JS version parameters
method_assets() {
    local base_url="$1"
    log "Method 3: Checking CSS/JS asset versions..."
    
    homepage=$(curl -s -L --max-time 10 "$base_url/" 2>/dev/null || true)
    
    if [ -n "$homepage" ]; then
        # Look for version parameters in CSS/JS links
        versions=$(echo "$homepage" | grep -o -E '(wp-content/.*\.(css|js))\?ver=([0-9]+\.[0-9]+(\.[0-9]+)?)' | sed 's/.*ver=//')
        
        # Also check for version in inline script tags
        inline_versions=$(echo "$homepage" | grep -o -E 'var.*wp_version.*=.*"([0-9]+\.[0-9]+(\.[0-9]+)?)"' | grep -o -E '[0-9]+\.[0-9]+(\.[0-9]+)?')
        
        # Combine all found versions
        all_versions=$(echo -e "$versions\n$inline_versions" | grep -v '^$' | sort -u)
        
        if [ -n "$all_versions" ]; then
            # Try to identify the WordPress version (often looks like x.x or x.x.x)
            for ver in $all_versions; do
                # WordPress versions typically match pattern x.x or x.x.x
                if [[ "$ver" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
                    # Check if it looks like a WordPress version
                    major=$(echo "$ver" | cut -d. -f1)
                    minor=$(echo "$ver" | cut -d. -f2)
                    
                    if [ "$major" -ge 2 ] && [ "$major" -le 6 ] && [ "$minor" -le 9 ]; then
                        version "Found in assets: WordPress $ver"
                        echo "$ver"
                        return 0
                    fi
                fi
            done
            
            # If no pattern matched, return the first version found
            first_ver=$(echo "$all_versions" | head -1)
            info "Found asset version: $first_ver (might not be WordPress core)"
            echo "$first_ver"
            return 0
        fi
    fi
    
    warning "No version found in assets"
    return 1
}

# Method 4: Check RSS/Atom feeds
method_feeds() {
    local base_url="$1"
    log "Method 4: Checking RSS/Atom feeds..."
    
    # Try various feed URLs
    feeds=(
        "/feed/"
        "/feed/rss/"
        "/feed/rss2/"
        "/feed/atom/"
        "/?feed=rss"
        "/?feed=rss2"
        "/?feed=atom"
    )
    
    for feed in "${feeds[@]}"; do
        feed_url="${base_url}${feed}"
        feed_content=$(curl -s -L --max-time 10 "$feed_url" 2>/dev/null | head -100 || true)
        
        if [ -n "$feed_content" ]; then
            # Look for WordPress version in feed
            if echo "$feed_content" | grep -q -i "wordpress"; then
                # Try to extract version
                version=$(echo "$feed_content" | grep -o -E 'wordpress.*[0-9]+\.[0-9]+(\.[0-9]+)?' | grep -o -E '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
                
                if [ -n "$version" ]; then
                    version "Found in feed ($feed): WordPress $version"
                    echo "$version"
                    return 0
                fi
            fi
        fi
    done
    
    warning "No version found in feeds"
    return 1
}

# Method 5: Check login page
method_login() {
    local base_url="$1"
    log "Method 5: Checking login page..."
    
    login_url="${base_url}/wp-login.php"
    login_content=$(curl -s -L --max-time 10 "$login_url" 2>/dev/null || true)
    
    if [ -n "$login_content" ]; then
        # Check if it's a WordPress login page
        if echo "$login_content" | grep -q -i "wordpress"; then
            # Look for version in page
            version=$(echo "$login_content" | grep -o -E 'WordPress.*[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 | grep -o -E '[0-9]+\.[0-9]+(\.[0-9]+)?')
            
            if [ -n "$version" ]; then
                version "Found in login page: WordPress $version"
                echo "$version"
                return 0
            else
                version "WordPress login page detected (no version visible)"
                echo "unknown"
                return 0
            fi
        fi
    fi
    
    warning "Login page not accessible or not WordPress"
    return 1
}

# Method 6: Check REST API
method_rest_api() {
    local base_url="$1"
    log "Method 6: Checking REST API..."
    
    api_url="${base_url}/wp-json/"
    api_content=$(curl -s -L --max-time 10 "$api_url" 2>/dev/null || true)
    
    if [ -n "$api_content" ]; then
        if echo "$api_content" | grep -q -i "wordpress"; then
            # Try to get version from API response
            version=$(echo "$api_content" | grep -o -E '"version":"[0-9]+\.[0-9]+(\.[0-9]+)?"' | head -1 | cut -d'"' -f4)
            
            if [ -n "$version" ]; then
                version "Found in REST API: WordPress $version"
                echo "$version"
                return 0
            fi
            
            # Try the /wp/v2 endpoint
            api_v2="${base_url}/wp-json/wp/v2/"
            api_v2_content=$(curl -s -L --max-time 10 "$api_v2" 2>/dev/null || true)
            
            if [ -n "$api_v2_content" ]; then
                namespace=$(echo "$api_v2_content" | grep -o -E '"namespace":"[^"]+"' | head -1 | cut -d'"' -f4)
                if [[ "$namespace" == *"wp/v2"* ]]; then
                    info "WordPress REST API v2 detected"
                    echo ">=4.7"  # WP REST API v2 introduced in 4.7
                    return 0
                fi
            fi
        fi
    fi
    
    warning "REST API not accessible or not WordPress"
    return 1
}

# Method 7: Check version file (advanced)
method_version_file() {
    local base_url="$1"
    log "Method 7: Checking version files..."
    
    # Check for version.php in includes
    version_url="${base_url}/wp-includes/version.php"
    version_content=$(curl -s -L --max-time 10 "$version_url" 2>/dev/null || true)
    
    if [ -n "$version_content" ]; then
        # Extract version from PHP file
        version=$(echo "$version_content" | grep -o -E '\$wp_version.*=.*["'"'"'][0-9]+\.[0-9]+(\.[0-9]+)?' | grep -o -E '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
        
        if [ -n "$version" ]; then
            version "Found in version.php: WordPress $version"
            echo "$version"
            return 0
        fi
    fi
    
    warning "Version file not accessible"
    return 1
}

# Method 8: Check sitemap
method_sitemap() {
    local base_url="$1"
    log "Method 8: Checking sitemap..."
    
    sitemap_url="${base_url}/wp-sitemap.xml"
    sitemap_content=$(curl -s -L --max-time 10 "$sitemap_url" 2>/dev/null | head -50 || true)
    
    if [ -n "$sitemap_content" ]; then
        if echo "$sitemap_content" | grep -q -i "wordpress"; then
            info "WordPress sitemap detected (introduced in WP 5.5)"
            echo ">=5.5"
            return 0
        fi
    fi
    
    # Try old sitemap
    old_sitemap="${base_url}/sitemap.xml"
    old_content=$(curl -s -L --max-time 10 "$old_sitemap" 2>/dev/null | head -50 || true)
    
    if [ -n "$old_content" ]; then
        if echo "$old_content" | grep -q -i "generator.*wordpress"; then
            version=$(echo "$old_content" | grep -o -E 'wordpress.*[0-9]+\.[0-9]+(\.[0-9]+)?' | grep -o -E '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
            
            if [ -n "$version" ]; then
                version "Found in sitemap.xml: WordPress $version"
                echo "$version"
                return 0
            fi
        fi
    fi
    
    warning "Sitemap not found or no version"
    return 1
}

# Method 9: Check wp-admin/css files
method_admin_css() {
    local base_url="$1"
    log "Method 9: Checking admin CSS..."
    
    # Check common admin CSS files that contain version info
    css_files=(
        "/wp-admin/css/common.css"
        "/wp-admin/css/dashboard.css"
        "/wp-admin/css/login.css"
    )
    
    for css in "${css_files[@]}"; do
        css_url="${base_url}${css}"
        css_content=$(curl -s -L --max-time 10 "$css_url" 2>/dev/null | head -20 || true)
        
        if [ -n "$css_content" ]; then
            # Look for version comment in CSS
            version=$(echo "$css_content" | grep -o -E 'Version:.*[0-9]+\.[0-9]+(\.[0-9]+)?' | grep -o -E '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
            
            if [ -n "$version" ]; then
                version "Found in $css: WordPress $version"
                echo "$version"
                return 0
            fi
        fi
    done
    
    warning "No version found in admin CSS"
    return 1
}

# Method 10: Use wpscan if available
method_wpscan() {
    local url="$1"
    
    if command -v wpscan &> /dev/null; then
        log "Method 10: Using wpscan..."
        
        # Run wpscan in quiet mode just for version detection
        wpscan_output=$(wpscan --url "$url" --no-update --disable-tls-checks 2>/dev/null | grep -i "wordpress version" || true)
        
        if [ -n "$wpscan_output" ]; then
            version=$(echo "$wpscan_output" | grep -o -E '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
            version "wpscan detected: WordPress $version"
            echo "$version"
            return 0
        fi
    fi
    
    return 1
}

# Method 11: Check for specific version indicators
method_indicators() {
    local base_url="$1"
    log "Method 11: Checking version indicators..."
    
    homepage=$(curl -s -L --max-time 10 "$base_url/" 2>/dev/null || true)
    
    if [ -n "$homepage" ]; then
        # Check for Gutenberg block editor (WP 5.0+)
        if echo "$homepage" | grep -q -i "wp-block-"; then
            info "Gutenberg block editor detected (WP 5.0+)"
            echo ">=5.0"
            return 0
        fi
        
        # Check for jQuery version (clue about WP version)
        jquery=$(echo "$homepage" | grep -o -E 'jquery.*\.js\?ver=[0-9]+\.[0-9]+(\.[0-9]+)?' | sed 's/.*ver=//')
        
        if [ -n "$jquery" ]; then
            # WordPress bundles specific jQuery versions
            case "$jquery" in
                "1.12.4")
                    info "jQuery 1.12.4 detected (WP 4.5+)"
                    echo ">=4.5"
                    return 0
                    ;;
                "1.12.4-wp")
                    info "jQuery 1.12.4-wp detected (WP 5.6+)"
                    echo ">=5.6"
                    return 0
                    ;;
                "3.6.0")
                    info "jQuery 3.6.0 detected (WP 5.7+)"
                    echo ">=5.7"
                    return 0
                    ;;
            esac
        fi
    fi
    
    return 1
}

# Main detection function
detect_version() {
    local url="$1"
    local detected_versions=()
    
    log "Starting WordPress version detection for: $url"
    echo ""
    
    # Clean and get accessible URL
    clean_url=$(clean_url "$url")
    base_url=$(get_accessible_url "$clean_url")
    
    if [ -z "$base_url" ]; then
        error "Could not access the site"
        return 1
    fi
    
    info "Using: $base_url"
    echo ""
    
    # Try all methods
    methods=(
        "method_readme"
        "method_meta_generator"
        "method_assets"
        "method_feeds"
        "method_login"
        "method_rest_api"
        "method_version_file"
        "method_sitemap"
        "method_admin_css"
        "method_indicators"
        "method_wpscan"
    )
    
    # Array to store found versions
    declare -A version_counts
    
    # Try each method
    for method in "${methods[@]}"; do
        if version_result=$($method "$base_url" 2>/dev/null); then
            if [ -n "$version_result" ] && [ "$version_result" != "unknown" ]; then
                # Add to array
                detected_versions+=("$version_result")
                
                # Count occurrences
                if [ -z "${version_counts[$version_result]}" ]; then
                    version_counts[$version_result]=1
                else
                    version_counts[$version_result]=$((${version_counts[$version_result]} + 1))
                fi
            fi
        fi
        sleep 0.5  # Small delay between requests
    done
    
    echo ""
    echo "========================================"
    
    # Analyze results
    if [ ${#detected_versions[@]} -eq 0 ]; then
        error "Could not detect WordPress version"
        echo "Possible reasons:"
        echo "  - Site is not WordPress"
        echo "  - Version information is hidden"
        echo "  - Site has security measures"
        return 1
    fi
    
    # Show all found versions
    success "Version detection results:"
    printf "%-15s %s\n" "Version" "Confidence"
    printf "%-15s %s\n" "-------" "----------"
    
    for version in "${!version_counts[@]}"; do
        count=${version_counts[$version]}
        confidence=$((count * 100 / ${#methods[@]}))
        printf "%-15s %d%% (%d/%d)\n" "$version" "$confidence" "$count" "${#methods[@]}"
    done
    
    # Determine most likely version
    most_likely=""
    highest_count=0
    
    for version in "${!version_counts[@]}"; do
        if [ "${version_counts[$version]}" -gt "$highest_count" ]; then
            highest_count=${version_counts[$version]}
            most_likely="$version"
        fi
    done
    
    echo ""
    
    if [ -n "$most_likely" ]; then
        confidence=$((highest_count * 100 / ${#methods[@]}))
        
        if [ "$confidence" -ge 50 ]; then
            success "Most likely version: WordPress $most_likely (${confidence}% confidence)"
            
            # Show version details
            echo ""
            info "Version Information:"
            echo "-------------------"
            
            # Parse version components
            major=$(echo "$most_likely" | cut -d. -f1)
            minor=$(echo "$most_likely" | cut -d. -f2)
            patch=$(echo "$most_likely" | cut -d. -f3)
            
            # Release date estimation (approximate)
            case "$major" in
                6)
                    case "$minor" in
                        0) echo "Released: May 2022" ;;
                        1) echo "Released: Nov 2022" ;;
                        2) echo "Released: Mar 2023" ;;
                        3) echo "Released: Aug 2023" ;;
                        4) echo "Released: Nov 2023" ;;
                        5) echo "Released: Apr 2024" ;;
                        *) echo "Future release" ;;
                    esac
                    ;;
                5)
                    case "$minor" in
                        0) echo "Released: Dec 2018" ;;
                        1) echo "Released: Feb 2019" ;;
                        2) echo "Released: May 2019" ;;
                        3) echo "Released: Nov 2019" ;;
                        4) echo "Released: Mar 2020" ;;
                        5) echo "Released: Aug 2020" ;;
                        6) echo "Released: Dec 2020" ;;
                        7) echo "Released: Mar 2021" ;;
                        8) echo "Released: Jul 2021" ;;
                        9) echo "Released: Jan 2022" ;;
                        *) echo "Older version" ;;
                    esac
                    ;;
                *)
                    echo "Version: $most_likely"
                    ;;
            esac
            
            # Check if version is outdated
            if [ "$major" -lt 5 ] || { [ "$major" -eq 5 ] && [ "$minor" -lt 9 ]; }; then
                warning "This version is outdated and may have security vulnerabilities!"
            fi
            
        else
            warning "Low confidence detection: WordPress $most_likely (${confidence}% confidence)"
            info "Consider manual verification"
        fi
    else
        error "Could not determine version with confidence"
    fi
    
    echo "========================================"
}

# Batch processing
batch_process() {
    local file="$1"
    
    if [ ! -f "$file" ]; then
        error "File not found: $file"
        return 1
    fi
    
    log "Batch processing URLs from: $file"
    
    # Create output file
    output_file="wp_versions_$(date +%Y%m%d_%H%M%S).csv"
    echo "URL,Version,Confidence,Detection Method" > "$output_file"
    
    count=0
    total=$(grep -v "^#" "$file" | grep -v "^$" | wc -l)
    
    while IFS= read -r url || [[ -n "$url" ]]; do
        [[ "$url" =~ ^#.*$ ]] || [ -z "$url" ] && continue
        
        count=$((count + 1))
        echo ""
        echo "========================================"
        echo " Processing URL $count of $total"
        echo "========================================"
        
        # Detect version
        echo "$url" >> "$output_file"
        
        # We'll do a simpler detection for batch mode
        clean_url=$(clean_url "$url")
        base_url=$(get_accessible_url "$clean_url" 2>/dev/null || true)
        
        if [ -n "$base_url" ]; then
            # Try quick methods
            version=""
            
            # Method 1: readme.html
            readme_content=$(curl -s -L --max-time 5 "${base_url}/readme.html" 2>/dev/null || true)
            if [ -n "$readme_content" ]; then
                version=$(echo "$readme_content" | grep -o -E "WordPress [0-9]+\.[0-9]+(\.[0-9]+)?" | head -1 | awk '{print $2}')
                if [ -n "$version" ]; then
                    echo "$url,$version,High,readme.html" >> "$output_file"
                    continue
                fi
            fi
            
            # Method 2: meta generator
            homepage=$(curl -s -L --max-time 5 "${base_url}/" 2>/dev/null || true)
            if [ -n "$homepage" ]; then
                version=$(echo "$homepage" | grep -i 'meta.*name="generator"' | grep -o -E '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
                if [ -n "$version" ]; then
                    echo "$url,$version,Medium,generator meta" >> "$output_file"
                    continue
                fi
            fi
            
            echo "$url,Not detected,Low,multiple methods" >> "$output_file"
        else
            echo "$url,Inaccessible,N/A,N/A" >> "$output_file"
        fi
        
        sleep 1
        
    done < "$file"
    
    success "Batch processing complete"
    info "Results saved to: $output_file"
}

# Show help
show_help() {
    echo "WordPress Version Detector"
    echo ""
    echo "Usage: $0 [OPTIONS] [URL]"
    echo ""
    echo "Options:"
    echo "  -u, --url URL        Detect version for single URL"
    echo "  -f, --file FILE      Batch process URLs from file"
    echo "  -q, --quick          Quick scan (fewer methods)"
    echo "  -v, --verbose        Verbose output"
    echo "  -h, --help           Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 https://example.com"
    echo "  $0 --url example.com"
    echo "  $0 --file urls.txt"
    echo ""
    echo "Detection Methods:"
    echo "  1. readme.html file"
    echo "  2. Generator meta tag"
    echo "  3. CSS/JS asset versions"
    echo "  4. RSS/Atom feeds"
    echo "  5. Login page"
    echo "  6. REST API"
    echo "  7. version.php file"
    echo "  8. Sitemap"
    echo "  9. Admin CSS files"
    echo "  10. Version indicators"
    echo "  11. wpscan (if available)"
}

# Main function
main() {
    # Check dependencies
    check_deps
    
    # Parse arguments
    local url=""
    local file=""
    local quick_mode=false
    local verbose=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -u|--url)
                url="$2"
                shift 2
                ;;
            -f|--file)
                file="$2"
                shift 2
                ;;
            -q|--quick)
                quick_mode=true
                shift
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -*)
                error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                if [ -z "$url" ]; then
                    url="$1"
                fi
                shift
                ;;
        esac
    done
    
    # Run appropriate mode
    if [ -n "$file" ]; then
        batch_process "$file"
    elif [ -n "$url" ]; then
        detect_version "$url"
    else
        error "No URL specified"
        show_help
        exit 1
    fi
}

# Run main
main "$@"