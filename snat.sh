#!/bin/bash

# Unique comment for both IPv4 and IPv6 rules
unique_comment="Docker SNAT"

# Variable for the IPv4 subnet
ipv4_subnet=

# Variable for the IPv6 subnet
ipv6_subnet=

# Variable for the IPv4 SNAT address
ipv4_snat_address=

# Variable for the IPv6 SNAT address
ipv6_snat_address=

# Function to display usage information
usage() {
    echo "Usage: $0 [-h] [-r] [-i seconds] [-q]"
    echo "  -h    Display this help message"
    echo "  -r    Repeat"
    echo "  -i    Set the interval in seconds between each rerun (default: 1)"
    echo "  -q    Run in quiet mode"
    exit 1
}

# Parse command-line options
single_shot=true
interval=1
quiet=false

while getopts "hri:q" opt; do
  case $opt in
    h)
      usage
      ;;
    r)
      single_shot=false
      ;;
    i)
      interval="$OPTARG"
      ;;
    q)
      quiet=true
      ;;
    *)
      usage
      ;;
  esac
done

# Function to log messages
log() {
    if ! $quiet; then
        printf "%s\n" "$@"
    fi
}

# Check if the script is run as root, unless the -h option was provided
if [ "$EUID" -ne 0 ]; then
  log "This script must be run as root. Exiting."
  exit 1
fi

# Check for IPv4 support
if ! command -v iptables &> /dev/null; then
  log "iptables command not found. IPv4 support is not available."
  disable_ipv4=true
else
  disable_ipv4=false
fi

# Check for IPv6 support
if ! command -v ip6tables &> /dev/null; then
  log "ip6tables command not found. IPv6 support is not available."
  disable_ipv6=true
else
  disable_ipv6=false
fi

# Function to insert SNAT rules
insert_rules() {
    local table=$1
    local subnet=$2
    local snat_address=$3
    log "Inserting $table SNAT rule..."
    if ! $table -t nat -I POSTROUTING 1 -p all -s $subnet -j SNAT --to-source $snat_address -m comment --comment "$unique_comment"; then
        log "Failed to insert $table SNAT rule."
    fi
}

# Function to delete SNAT rules
delete_rules() {
    local table=$1
    local pos=$2
    log "Deleting $table SNAT rule at position $pos..."
    if ! $table -t nat -D POSTROUTING $pos; then
        log "Failed to delete $table SNAT rule at position $pos."
    fi
}

# Function to check and manage SNAT rules
check_and_manage_snat_rules() {
    if ! $disable_ipv4; then
        # Check and manage IPv4 rules
        pos_v4=$(iptables -t nat -L POSTROUTING -v -n --line-numbers | grep "$unique_comment" | awk '{ print $1 }')
        if [ "$pos_v4" == "" ]; then
            log "IPv4 rule does not exist; adding it."
            insert_rules iptables $ipv4_subnet $ipv4_snat_address
        elif [ "$pos_v4" != "1" ]; then
            log "IPv4 rule is not in the first position; re-inserting it."
            insert_rules iptables $ipv4_subnet $ipv4_snat_address
            delete_rules iptables $pos_v4
        else
            log "IPv4 rule is already in the first position."
        fi
    fi

    if ! $disable_ipv6; then
        # Check and manage IPv6 rules
        pos_v6=$(ip6tables -t nat -L POSTROUTING -v -n --line-numbers | grep "$unique_comment" | awk '{ print $1 }')
        if [ "$pos_v6" == "" ]; then
            log "IPv6 rule does not exist; adding it."
            insert_rules ip6tables $ipv6_subnet $ipv6_snat_address
        elif [ "$pos_v6" != "1" ]; then
            log "IPv6 rule is not in the first position; re-inserting it."
            insert_rules ip6tables $ipv6_subnet $ipv6_snat_address
            delete_rules ip6tables $pos_v6
        else
            log "IPv6 rule is already in the first position."
        fi
    fi
}

# Infinite loop to check and manage SNAT rules every $interval seconds
if ! $single_shot; then
    while true; do
        check_and_manage_snat_rules
        # Wait for the specified interval before repeating the loop
        log "Waiting for $interval seconds before repeating the loop..."
        sleep $interval
    done
else
    check_and_manage_snat_rules
    log "Script execution completed."
fi
