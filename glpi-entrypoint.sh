#!/usr/bin/env bash
set -euo pipefail

# Keep generated private keys restrictive on the mounted Azure Files share.
umask 0077

# Install and activate the first-party SOC workspace once. The plugin uses
# existing GLPI ticket tables only; it does not create or migrate ticket data.
socops_marker=/var/glpi/files/.socops-plugin-enabled
if [[ "${GLPI_SOCOPS_PLUGIN_BOOTSTRAP:-false}" == "true" && ! -f "$socops_marker" ]]; then
  mkdir -p /var/glpi/files
  /opt/glpi/entrypoint/wait-for-db.sh socops-plugin
  cd /var/www/glpi
  if ! php bin/console glpi:plugin:install socops --username=glpi --no-interaction; then
    echo "GLPI SOC plugin install command reported no change; checking activation."
  fi
  if php bin/console glpi:plugin:activate socops --no-interaction; then
    : > "$socops_marker"
    echo "GLPI SOC analyst workspace plugin is installed and active."
  else
    echo "GLPI SOC analyst workspace plugin bootstrap did not complete; GLPI will continue starting."
  fi
fi

# Run the initial account hardening from inside the app after the database has
# been installed. The marker is persisted with the GLPI files so this only runs
# once, even when the container app restarts.
bootstrap_marker=/var/glpi/files/.default-users-hardened
if [[ "${GLPI_BOOTSTRAP_DEFAULT_USERS:-false}" == "true" && ! -f "$bootstrap_marker" ]]; then
  mkdir -p /var/glpi/files
  /opt/glpi/entrypoint/wait-for-db.sh account-hardening
  for username in tech normal post-only; do
    php /var/www/glpi/bin/console user:disable --no-interaction "$username"
  done
  : > "$bootstrap_marker"
  echo "GLPI default account hardening completed."
fi

exec /opt/glpi/entrypoint.sh "$@"
