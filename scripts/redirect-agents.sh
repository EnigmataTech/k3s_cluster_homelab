#!/bin/bash
# redirect-agents.sh — Update Wazuh agent manager IP on all monitored hosts
# Run AFTER the Wazuh manager StatefulSet is Running and agents service LoadBalancer IP is 192.168.1.242
#
# Agent list:
#   001 Kreation         100.91.40.71  (Windows — manual update needed)
#   004 StingerVPS       100.99.226.7  (Ubuntu, SSH)
#   006 MonitorLizard    100.81.46.87  (Ubuntu, SSH — runs ntfy/wazuh Docker)
#   010 PVE-Proxmox      192.168.1.56  (Proxmox, SSH as root)

set -e

NEW_MANAGER_IP="192.168.1.242"
OSSEC_CONF="/var/ossec/etc/ossec.conf"

update_agent() {
    local HOST=$1
    local USER=$2
    local DESC=$3
    echo ""
    echo "==> Updating $DESC ($HOST)..."
    ssh "${USER}@${HOST}" "
        sudo sed -i 's|<address>.*</address>|<address>${NEW_MANAGER_IP}</address>|' ${OSSEC_CONF} &&
        sudo grep '<address>' ${OSSEC_CONF} &&
        sudo systemctl restart wazuh-agent &&
        sleep 3 &&
        sudo systemctl status wazuh-agent --no-pager | grep -E 'Active:|Loaded:'
    "
    echo "Done: $DESC"
}

echo "Redirecting Wazuh agents to new manager IP: $NEW_MANAGER_IP"
echo "============================================================"

# StingerVPS (Ubuntu, enigma user)
# NOTE: StingerVPS needs --accept-routes enabled for Tailscale to reach 192.168.1.242
# Run on StingerVPS first: sudo tailscale set --accept-routes
update_agent "100.99.226.7" "enigma" "StingerVPS"

# MonitorLizard — update its local agent (it monitors itself)
update_agent "100.81.46.87" "enigma" "MonitorLizard"

# PVE-Proxmox (root SSH)
update_agent "192.168.1.56" "root" "PVE-Proxmox"

echo ""
echo "============================================================"
echo "Manual step required for Kreation (Windows):"
echo "  1. RDP/connect to Kreation"
echo "  2. Edit C:\\Program Files (x86)\\ossec-agent\\ossec.conf"
echo "  3. Change <address> to $NEW_MANAGER_IP"
echo "  4. Restart Wazuh service: net stop WazuhSvc && net start WazuhSvc"
echo ""
echo "Verify all agents in Wazuh dashboard or with:"
echo "  kubectl exec -n wazuh statefulset/wazuh-manager -- /var/ossec/bin/agent_control -l"
