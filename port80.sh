#!/bin/bash
# quick_port80_check.sh

target=$1
if [ -z "$target" ]; then
    echo "Usage: $0 <ip_or_hostname>"
    exit 1
fi

echo "Checking $target:80..."

# Check if port is open
if timeout 2 nc -z -w1 "$target" 80 2>/dev/null; then
    echo "✓ Port 80 is OPEN"
    
    # Check if it's a web server
    response=$(timeout 3 curl -s -I "http://$target" 2>/dev/null | head -1)
    
    if echo "$response" | grep -q "HTTP"; then
        echo "✓ Running web server: $response"
        
        # Get server type
        server=$(curl -s -I "http://$target" 2>/dev/null | grep -i "^Server:" | head -1)
        if [ -n "$server" ]; then
            echo "  Server: $server"
        fi
        
        # Get page title
        title=$(curl -s -L "http://$target" 2>/dev/null | grep -i "<title>" | head -1 | sed 's/<[^>]*>//g')
        if [ -n "$title" ]; then
            echo "  Title: $title"
        fi
    else
        echo "✗ Port open but not responding as web server"
    fi
else
    echo "✗ Port 80 is CLOSED or filtered"
fi