#!/bin/bash
# save as db_scanner.sh
# chmod +x db_scanner.sh

TARGET_SUBNET="10.0.100.0/24"
OUTPUT_DIR="database_scan_$(date +%Y%m%d_%H%M%S)"
DATABASE_PORTS="1433,1434,1521,3306,5432,27017,6379,9200,5984,50000,9042,8086"

echo "[*] Starting database server scan of $TARGET_SUBNET"
echo "[*] Output directory: $OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# Create log file
LOG_FILE="$OUTPUT_DIR/scan.log"
exec 2>&1 | tee -a "$LOG_FILE"

# Step 1: Initial port discovery
echo "[1/4] Scanning for open database ports..."
nmap -Pn -p $DATABASE_PORTS --open -sS -T4 "$TARGET_SUBNET" -oA "$OUTPUT_DIR/initial_scan" > /dev/null

# Extract hosts with open database ports
grep "Nmap scan report" "$OUTPUT_DIR/initial_scan.nmap" | awk '{print $5}' > "$OUTPUT_DIR/db_hosts.txt"
DB_HOST_COUNT=$(wc -l < "$OUTPUT_DIR/db_hosts.txt")
echo "[+] Found $DB_HOST_COUNT hosts with database ports open"

if [ $DB_HOST_COUNT -eq 0 ]; then
    echo "[-] No database servers found. Exiting."
    exit 0
fi

# Step 2: Service and version detection
echo "[2/4] Performing service version detection..."
nmap -sV -p $DATABASE_PORTS --version-intensity 7 -iL "$OUTPUT_DIR/db_hosts.txt" -oA "$OUTPUT_DIR/version_detection" > /dev/null

# Step 3: Database-specific enumeration
echo "[3/4] Running database-specific scripts..."
for host in $(cat "$OUTPUT_DIR/db_hosts.txt"); do
    echo "  Processing $host..."
    
    # Check each port for specific database types
    OPEN_PORTS=$(grep -B2 -A1 "Nmap scan report for $host" "$OUTPUT_DIR/initial_scan.nmap" | grep "/tcp.*open" | awk -F/ '{print $1}')
    
    for port in $OPEN_PORTS; do
        case $port in
            1433)
                echo "    MSSQL on port $port"
                nmap -p 1433 --script ms-sql-info,ms-sql-empty-password "$host" -oN "$OUTPUT_DIR/mssql_$host.txt" > /dev/null 2>&1
                ;;
            1521)
                echo "    Oracle on port $port"
                nmap -p 1521 --script oracle-tns-version "$host" -oN "$OUTPUT_DIR/oracle_$host.txt" > /dev/null 2>&1
                ;;
            3306)
                echo "    MySQL on port $port"
                nmap -p 3306 --script mysql-info,mysql-empty-password "$host" -oN "$OUTPUT_DIR/mysql_$host.txt" > /dev/null 2>&1
                ;;
            5432)
                echo "    PostgreSQL on port $port"
                nmap -p 5432 --script pgsql-info "$host" -oN "$OUTPUT_DIR/pgsql_$host.txt" > /dev/null 2>&1
                ;;
            27017)
                echo "    MongoDB on port $port"
                nmap -p 27017 --script mongodb-info "$host" -oN "$OUTPUT_DIR/mongodb_$host.txt" > /dev/null 2>&1
                ;;
            6379)
                echo "    Redis on port $port"
                nmap -p 6379 --script redis-info "$host" -oN "$OUTPUT_DIR/redis_$host.txt" > /dev/null 2>&1
                ;;
            9200)
                echo "    Elasticsearch on port $port"
                nmap -p 9200 --script http-elasticsearch-info "$host" -oN "$OUTPUT_DIR/elasticsearch_$host.txt" > /dev/null 2>&1
                ;;
        esac
    done
done

# Step 4: Generate summary report
echo "[4/4] Generating summary report..."
{
    echo "DATABASE SERVER SCAN REPORT"
    echo "============================"
    echo "Scan Date: $(date)"
    echo "Target Network: $TARGET_SUBNET"
    echo "Total Database Servers Found: $DB_HOST_COUNT"
    echo ""
    echo "DETAILED FINDINGS:"
    echo "=================="
    
    while read host; do
        echo ""
        echo "Host: $host"
        echo "----------------------------------------"
        
        # Get service info from version detection
        SERVICE_INFO=$(grep -A20 "Nmap scan report for $host" "$OUTPUT_DIR/version_detection.nmap" | grep -E "^[0-9]+/tcp|^[0-9]+/udp")
        
        if [ -n "$SERVICE_INFO" ]; then
            echo "Open Database Ports:"
            echo "$SERVICE_INFO" | while read line; do
                echo "  $line"
            done
        else
            echo "  No detailed service information available"
        fi
        
        # Check for specific findings
        for db_type in mssql oracle mysql pgsql mongodb redis elasticsearch; do
            if [ -f "$OUTPUT_DIR/${db_type}_${host}.txt" ]; then
                echo ""
                echo "  $db_type findings:"
                grep -E "VULNERABLE|CVE|weak|empty|anonymous" "$OUTPUT_DIR/${db_type}_${host}.txt" || echo "    No critical issues detected"
            fi
        done
        
    done < "$OUTPUT_DIR/db_hosts.txt"
    
    echo ""
    echo "RECOMMENDATIONS:"
    echo "================"
    echo "1. Review authentication settings on all databases"
    echo "2. Ensure databases are not exposed to public networks"
    echo "3. Check for default/weak credentials"
    echo "4. Verify encryption is enabled"
    echo "5. Review firewall rules limiting database access"
    
} > "$OUTPUT_DIR/database_scan_summary.txt"

echo "[+] Scan complete! Results saved in $OUTPUT_DIR/"
echo "[+] Summary report: $OUTPUT_DIR/database_scan_summary.txt"