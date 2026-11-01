#!/bin/sh
set -eu

theme_source=/opt/glpi-theme/soc_ops.scss
theme_dir="${GLPI_THEMES_DIR:-${GLPI_VAR_DIR:-/var/glpi/files}/_themes}"
theme_target="$theme_dir/soc_ops.scss"

mkdir -p "$theme_dir"
if ! cmp -s "$theme_source" "$theme_target"; then
    cp "$theme_source" "$theme_target"
fi

touch "$theme_target"
exec gosu www-data /opt/glpi/entrypoint.sh "$@"
