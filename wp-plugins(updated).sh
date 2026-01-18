#!/bin/bash
URL="http://wordpress.local"
PLUGINS_FILE="plugins_comprehensive.txt"

# Create COMPREHENSIVE plugin wordlist
cat > $PLUGINS_FILE << 'EOF'
# Most Common WordPress Plugins
akismet
contact-form-7
jetpack
wordpress-seo
yoast-seo
all-in-one-seo-pack
google-analytics-for-wordpress
google-analytics-dashboard
wp-super-cache
w3-total-cache
wp-rocket
autoptimize
duplicator
duplicator-pro
updraftplus
backwpup
backupbuddy
all-in-one-wp-migration
wordfence
wordfence-assistant
sucuri-scanner
ithemes-security
bulletproof-security
formidable
formidable-forms
gravityforms
ninja-forms
wpforms
caldera-forms
nextgen-gallery
envira-gallery
revslider
layerslider
smart-slider
metaslider
woocommerce
wp-ecommerce
easy-digital-downloads
memberpress
paid-memberships-pro
buddypress
bbpress
simple-press
elementor
beaver-builder
siteorigin-panels
visual-composer
wpbakery-page-builder
divi-builder
thrive-visual-editor
advanced-custom-fields
types
pods
toolset-types
wpml
polylang
translatepress
redirection
simple-301-redirects
really-simple-ssl
better-wp-security
limit-login-attempts
login-lockdown
wp-mail-smtp
contact-form-7-to-database-extension
flamingo
postman-smtp
broken-link-checker
wp-optimize
ewww-image-optimizer
smush
imagify
shortcodes-ultimate
tablepress
wp-pagenavi
breadcrumb-navxt
wp-polls
wp-postratings
yet-another-related-posts-plugin
disqus-comment-system
facebook-comments-plugin
wp-ulike
social-warfare
add-to-any
shareaholic
cookie-notice
cookie-law-info
wp-fastest-cache
hummingbird-performance
complianz
mailchimp-for-wp
newsletter
subscribe-to-comments-reloaded
wp-rss-aggregator
events-manager
the-events-calendar
wp-slimstat
google-maps
wp-google-maps
table-of-contents-plus
wp-pagenavi
breadcrumb-navxt
fancybox-for-wordpress
lightbox-plus
simple-tags
wp-recaptcha
captcha
math-captcha
antispam-bee
stop-spammer-registrations-plugin
broken-link-checker
redirection
simple-history
query-monitor
wp-security-audit-log
user-role-editor
members
advanced-custom-fields
pods
types
toolset-types
wpide
file-manager-advanced
wp-file-manager
aryo-activity-log
user-switching
wp-cerber
all-in-one-wp-security-and-firewall
better-search-replace
wp-dbmanager
wp-migrate-db
404-redirected
404-to-301
automatic-youtube-video-posts
youtube-embed-plus
embedplus
wp-youtube-lyte
amp
wp-amp
accelerated-mobile-pages
seo-by-rank-math
seopress
the-seo-framework
schema
schema-and-structured-data-for-wp
wp-job-manager
simple-job-board
business-directory-plugin
restaurant-reservations
bookly
appointment-booking-calendar
give
easy-paypal-donation
stripe
authorize-net
paypal
shopping-cart
wp-easycart
wp-invoice
invoicing
estatik
realhomes
propertyhive
wp-property
geo-my-wp
wp-geo
map-multi-marker
leaflet-maps-marker
wp-google-maps
map-press
mp3-jplayer
video-embed-thumbnail-generator
contus-video-gallery
wp-video-lightbox
wp-symposium
wp-forum
dw-question-answer
anspress
knowledgebase
weblizar
helpdesk
awesome-support
wp-support-plus-responsive-ticket-system
tickera
event-tickets
rsvp
rsvpmaker
quiz-master-next
wp-pro-quiz
hugeit-slider
smart-slider-3
master-slider
slideshow
ml-slider
ultimate-responsive-image-slider
awesome-filterable-portfolio
portfolio-post-type
picatic
sell-media
download-monitor
easy-digital-downloads
wp-downloadmanager
download-manager
wp-simple-downloads
loginizer
wp-limit-login-attempts
rename-wp-login
wps-hide-login
theme-my-login
user-registration
wp-members
ultimate-member
profile-builder
paid-memberships-pro
memberpress
s2member
woocommerce-memberships
mycred
badgeos
gamipress
user-pro
pie-register
wp-user-frontend
front-end-pm
private-messages-for-wordpress
email-users
wp-email
newsletter
mailpoet
sendpress
wp-mailinglist
subscribe2
wp-symposium
bbpress
simple-press
wpforo
asgaros-forum
dw-question-answer
anspress
knowledgebase
weblizar
helpdesk
awesome-support
wp-support-plus-responsive-ticket-system
tickera
event-tickets
rsvp
rsvpmaker
quiz-master-next
wp-pro-quiz
hugeit-slider
smart-slider-3
master-slider
slideshow
ml-slider
ultimate-responsive-image-slider
EOF

echo "[*] Scanning for WordPress plugins..."
echo "====================================="
echo "Target: $URL"
echo "Wordlist: $PLUGINS_FILE ($(wc -l < $PLUGINS_FILE) plugins)"
echo ""

# Remove comments from wordlist
grep -v '^#' $PLUGINS_FILE | grep -v '^$' > plugins_clean.txt

# Method 1: Directory brute force (MAIN SCAN)
echo "[1] Directory brute force scan..."
echo "---------------------------------"
found_count=0

while read plugin; do
    response=$(curl -s -o /dev/null -w "%{http_code}" $URL/wp-content/plugins/$plugin/ 2>/dev/null)
    
    if [ "$response" == "200" ] || [ "$response" == "403" ] || [ "$response" == "301" ] || [ "$response" == "302" ]; then
        echo "[+] FOUND: $plugin (HTTP $response)"
        found_count=$((found_count + 1))
        
        # Check for readme.txt
        readme_content=$(curl -s $URL/wp-content/plugins/$plugin/readme.txt 2>/dev/null)
        if echo "$readme_content" | grep -qi "stable tag\|version"; then
            echo "    Version: $(echo "$readme_content" | grep -i "stable tag\|version" | head -2 | tr '\n' ' ')"
        fi
        
        # Check for special vulnerabilities
        case $plugin in
            *duplicator*)
                echo "    WARNING: Check installer.php for database credentials"
                ;;
            *migration*)
                echo "    WARNING: May contain backup files with passwords"
                ;;
            *revslider*|*layerslider*)
                echo "    WARNING: Known file upload vulnerabilities"
                ;;
            *backup*)
                echo "    WARNING: May contain database backups"
                ;;
        esac
    fi
    
    # Add small delay to avoid overwhelming server
    sleep 0.1
    
done < plugins_clean.txt

echo ""
echo "[*] Found $found_count plugins via directory scan"
echo ""

# Method 2: Check page source
echo "[2] Checking page source for plugins..."
echo "---------------------------------------"
source_plugins=$(curl -s $URL | grep -o 'wp-content/plugins/[^/" ]*' | cut -d'/' -f3 | sort -u)

if [ -z "$source_plugins" ]; then
    echo "No plugins found in page source"
else
    echo "Plugins referenced in HTML:"
    for plugin in $source_plugins; do
        echo "  • $plugin"
    done
fi
echo ""

# Method 3: Check styles and scripts
echo "[3] Checking loaded scripts/CSS..."
echo "-----------------------------------"
script_plugins=$(curl -s $URL | grep -o 'plugins/[^/" ]*/[^" ]*\.\(js\|css\)' | cut -d'/' -f2 | sort -u)

if [ -z "$script_plugins" ]; then
    echo "No plugins found in scripts/CSS"
else
    echo "Plugins loaded via scripts/CSS:"
    for plugin in $script_plugins; do
        echo "  • $plugin"
    done
fi
echo ""

# Method 4: Direct directory listing
echo "[4] Checking plugins directory listing..."
echo "-----------------------------------------"
plugins_dir=$(curl -s $URL/wp-content/plugins/)

if echo "$plugins_dir" | grep -qi "index of"; then
    echo "[!] Directory listing ENABLED!"
    echo "$plugins_dir" | grep -o 'href="[^"]*"' | cut -d'"' -f2 | grep -v '^\.\.$' | while read item; do
        if [ "$item" != "./" ] && [ "$item" != "../" ]; then
            echo "  Directory: ${item%/}"
        fi
    done
else
    echo "Directory listing disabled or requires authentication"
fi
echo ""

# Method 5: Check for vulnerable/important plugins specifically
echo "[5] Checking for critical plugins..."
echo "-------------------------------------"
critical_plugins=("duplicator" "all-in-one-wp-migration" "revslider" "formidable" "gravityforms" "backupbuddy" "updraftplus")

for plugin in "${critical_plugins[@]}"; do
    response=$(curl -s -o /dev/null -w "%{http_code}" $URL/wp-content/plugins/$plugin/ 2>/dev/null)
    if [ "$response" == "200" ] || [ "$response" == "403" ] || [ "$response" == "301" ] || [ "$response" == "302" ]; then
        echo "[!] CRITICAL: $plugin found (HTTP $response)"
        
        # Special checks for each critical plugin
        case $plugin in
            duplicator)
                echo "     Check: $URL/wp-content/plugins/duplicator/installer.php"
                echo "     Check: $URL/wp-content/plugins/duplicator/installer-backup.php"
                ;;
            all-in-one-wp-migration)
                echo "     Check: $URL/wp-content/plugins/all-in-one-wp-migration/"
                echo "     Look for: .wpress backup files"
                ;;
            revslider)
                echo "     Known vulnerability: File upload via admin-ajax.php"
                echo "     Check searchsploit for exploits"
                ;;
        esac
    fi
done

# Summary
echo ""
echo "====================================="
echo "[*] SCAN COMPLETE"
echo "====================================="
echo "Total plugins checked: $(wc -l < plugins_clean.txt)"
echo "Plugins found via directory scan: $found_count"
echo ""
echo "Next steps:"
echo "1. Check each found plugin for known vulnerabilities"
echo "2. Look for readme.txt files for version disclosure"
echo "3. Search for exploits: searchsploit [plugin_name]"
echo "4. Check for configuration/backup files"

# Cleanup
rm -f plugins_clean.txt