# check_aim
Nagios plugin for Dante Domain Manager
Uses SNMP. MIB available at 
 - https://www.audinate.com/support/dante-domain-manager

## Author
Toni Comerma

## Usage
```
check_ddm.sh -H host -C <community> [-s | -h | -d <domain>]  
    -s : Check services running 
    -h : Check high availability 
    -d <domain> : Check status of a domain  
```
## Requirements
It needs MIBS Audinate-MIB and DanteDomain-MIB in MIB path or in the same dir as script

## Limitations

# TODO
test, test, test..