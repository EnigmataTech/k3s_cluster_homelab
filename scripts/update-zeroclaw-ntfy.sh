#!/bin/bash
# update-zeroclaw-ntfy.sh — Update zeroclaw config to use new ntfy endpoint
# Run on the phone (PRoot) after ntfy is verified on k8s

ZEROCLAW_CONFIG="/home/enigma/.zeroclaw/config.toml"
OLD_URL="http://100.81.46.87:8080"
NEW_URL="http://ntfy.enigmata.local"

echo "Current ntfy URL in zeroclaw config:"
grep -i ntfy "$ZEROCLAW_CONFIG" || grep "http.*8080" "$ZEROCLAW_CONFIG" || echo "(not found — check config manually)"

echo ""
echo "To update, run:"
echo "  sed -i 's|${OLD_URL}|${NEW_URL}|g' $ZEROCLAW_CONFIG"
echo ""
echo "NOTE: ntfy.enigmata.local requires /etc/hosts entry on the phone:"
echo "  192.168.1.241  ntfy.enigmata.local"
echo ""
echo "Add it with (as root in proot):"
echo "  echo '192.168.1.241  ntfy.enigmata.local' >> /etc/hosts"
echo ""
echo "Or use the cluster IP directly (avoids DNS):"
echo "  NEW_URL=http://192.168.1.241  (then configure via Host header, not ideal)"
echo ""
echo "Alternatively, add ntfy to the zeroclaw cron wazuh_alert_monitor.sh script."

# Show zeroclaw config ntfy section if it exists
echo ""
echo "Zeroclaw config ntfy references:"
grep -n -i "ntfy\|8080\|100.81.46.87" "$ZEROCLAW_CONFIG" 2>/dev/null || echo "(none found)"
