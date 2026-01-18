#!/usr/bin/env python3
# version_parser.py - Parse and analyze version information

import re
import json
import csv
from datetime import datetime
import xml.etree.ElementTree as ET

class VersionParser:
    def __init__(self):
        self.versions = {}
        self.cve_db = self.load_cve_db()
    
    def parse_nmap_xml(self, xml_file):
        """Parse Nmap XML output for version information"""
        tree = ET.parse(xml_file)
        root = tree.getroot()
        
        for host in root.findall('host'):
            ip = host.find('address').get('addr')
            self.versions[ip] = {}
            
            for port in host.findall('.//port'):
                portid = port.get('portid')
                service = port.find('service')
                
                if service is not None:
                    version_info = {
                        'name': service.get('name', ''),
                        'product': service.get('product', ''),
                        'version': service.get('version', ''),
                        'extrainfo': service.get('extrainfo', ''),
                        'cpe': service.get('cpe', '')
                    }
                    self.versions[ip][portid] = version_info
        
        return self.versions
    
    def check_vulnerabilities(self):
        """Check versions against known vulnerabilities"""
        vulnerable_services = []
        
        for ip, ports in self.versions.items():
            for port, info in ports.items():
                if info['version']:
                    # Check against CVE database (simplified)
                    for cve in self.cve_db:
                        if (cve['product'] in info['product'] and 
                            self.compare_versions(info['version'], cve['affected_version'])):
                            vulnerable_services.append({
                                'ip': ip,
                                'port': port,
                                'service': info['product'],
                                'version': info['version'],
                                'cve': cve['id'],
                                'severity': cve['severity']
                            })
        
        return vulnerable_services
    
    def compare_versions(self, version1, version2_pattern):
        """Compare version strings (simplified)"""
        # This is a simplified version comparison
        # In production, use proper version comparison library
        try:
            v1_parts = re.findall(r'\d+', version1)
            v2_parts = re.findall(r'\d+', version2_pattern)
            
            if len(v1_parts) > 0 and len(v2_parts) > 0:
                return v1_parts[0] == v2_parts[0]  # Only compare major version
        except:
            pass
        return False
    
    def load_cve_db(self):
        """Load CVE database (simplified example)"""
        # In production, load from actual CVE database
        return [
            {'id': 'CVE-2021-44228', 'product': 'Apache Log4j', 
             'affected_version': '2.0-beta9 to 2.14.1', 'severity': 'CRITICAL'},
            {'id': 'CVE-2017-0144', 'product': 'Windows SMB', 
             'affected_version': 'Windows XP to Windows 8.1', 'severity': 'CRITICAL'}
        ]
    
    def generate_report(self, output_format='json'):
        """Generate version analysis report"""
        report = {
            'scan_date': datetime.now().isoformat(),
            'hosts': len(self.versions),
            'services': sum(len(ports) for ports in self.versions.values()),
            'vulnerabilities': self.check_vulnerabilities(),
            'version_details': self.versions
        }
        
        if output_format == 'json':
            with open('version_report.json', 'w') as f:
                json.dump(report, f, indent=2)
        elif output_format == 'csv':
            self.generate_csv(report)
        
        return report
    
    def generate_csv(self, report):
        """Generate CSV report"""
        with open('version_report.csv', 'w', newline='') as csvfile:
            writer = csv.writer(csvfile)
            writer.writerow(['IP', 'Port', 'Service', 'Version', 'CPE', 'Vulnerable'])
            
            for ip, ports in report['version_details'].items():
                for port, info in ports.items():
                    vulnerable = any(
                        vuln['ip'] == ip and vuln['port'] == port 
                        for vuln in report['vulnerabilities']
                    )
                    writer.writerow([
                        ip, port, info['product'], 
                        info['version'], info['cpe'], 
                        'YES' if vulnerable else 'NO'
                    ])

# Usage
if __name__ == "__main__":
    parser = VersionParser()
    
    # Parse Nmap XML output
    versions = parser.parse_nmap_xml('scan.xml')
    
    # Generate reports
    report = parser.generate_report('json')
    parser.generate_report('csv')
    
    print(f"Scan complete. Found {report['hosts']} hosts with {report['services']} services.")
    print(f"Identified {len(report['vulnerabilities'])} potential vulnerabilities.")