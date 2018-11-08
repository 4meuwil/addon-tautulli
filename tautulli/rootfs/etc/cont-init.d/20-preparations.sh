#!/usr/bin/with-contenv bash
# ==============================================================================
# Community Hass.io Add-ons: Tautulli
# Preparing configuration for Tautulli
# ==============================================================================
# shellcheck disable=SC1091
source /usr/lib/hassio-addons/base.sh

readonly ADDON=/data/addon.ini
readonly CONFIG=/data/config.ini
readonly DATABASE=/share/tautulli/tautulli.db
readonly SHARE=/share/tautulli

# If config.ini does not exist, create it.
if ! hass.file_exists "/data/config.ini"; then
    hass.log.info "Creating default configuration..."
    crudini --set "$CONFIG" General first_run_complete 0
    crudini --set "$CONFIG" General update_show_changelog 0
    crudini --set "$CONFIG" Advanced system_analytics 0
    crudini --set "$ADDON" Addon version "$TAUTULLI_VERSION"
fi

hass.log.info "Updating running configuration..."

# Temporrary changing config.ini to be valid during additions
## This has to be done because Tautulli added a ini header with [[header]]
sed -i "s/\\[\\[get_file_sizes_hold\\]\\]/\\[get_file_sizes_hold\\]/" "$CONFIG"

# Set spesific config if an upgrade
if ! hass.file_exists "/data/addon.ini"; then
    crudini --set "$ADDON" Addon version "0"
fi
CURRENT_VERSION=$(crudini --get "$ADDON" Addon version)
if [ "$CURRENT_VERSION" != "$TAUTULLI_VERSION" ]; then
    hass.log.debug "This is an upgrade..."
    crudini --set "$CONFIG" General update_show_changelog 1
else
    hass.log.debug "This is not an upgrade..."
    crudini --set "$CONFIG" General update_show_changelog 0
fi

# Ensure config
crudini --set "$ADDON" Addon version "$TAUTULLI_VERSION"
crudini --set "$CONFIG" General check_github 0
crudini --set "$CONFIG" General check_github_on_startup 0

# Update SSL info in configuration
if hass.config.true 'ssl'; then
    hass.log.info "Ensure SSL is active in the configuration..."
    crudini --set "$CONFIG" General enable_https 1
    crudini --set "$CONFIG" General https_cert_chain "\"/ssl/$(hass.config.get 'certfile')\""
    crudini --set "$CONFIG" General https_cert "\"/ssl/$(hass.config.get 'certfile')\""
    crudini --set "$CONFIG" General https_key "\"/ssl/$(hass.config.get 'keyfile')\""
else
    hass.log.info "Ensure SSL is not active in the configuration..."
    crudini --set "$CONFIG" General enable_https 0
    crudini --set "$CONFIG" General https_cert_chain "\"\""
    crudini --set "$CONFIG" General https_cert "\"\""
    crudini --set "$CONFIG" General https_key "\"\""
fi

# Enable Plex authentication
if hass.config.true 'plex_auth'; then
    hass.log.info "Enabling Plex authentication..."
    crudini --set "$CONFIG" General http_plex_admin 1
else
    crudini --set "$CONFIG" General http_plex_admin 0
fi

if hass.config.has_value 'username' && hass.config.has_value 'password'; then
    crudini --set "$CONFIG" General http_username "\"$(hass.config.get 'username')\""
    crudini --set "$CONFIG" General http_password "\"$(hass.config.get 'password')\""
else
    if hass.config.true 'plex_auth'; then
        hass.log.info "Generating random username and password."
        crudini --set "$CONFIG" General http_username "$RANDOM""$RANDOM""$RANDOM""$RANDOM""$RANDOM""$RANDOM"
        crudini --set "$CONFIG" General http_password "$RANDOM""$RANDOM""$RANDOM""$RANDOM""$RANDOM""$RANDOM"
    else
        crudini --set "$CONFIG" General http_username ""
        crudini --set "$CONFIG" General http_password ""
    fi
fi

# Changing config.ini back.
## This has to be done because Tautulli added a ini header with [[header]]
sed -i "s/\\[get_file_sizes_hold\\]/\\[\\[get_file_sizes_hold\\]\\]/" "$CONFIG"

# Create /share/tautulli if it does not exist.
if ! hass.directory_exists "$SHARE"; then
    mkdir "$SHARE"
fi

# Use databasefile from /share/tautulli if it exist.
if hass.file_exists "$DATABASE"; then
    hass.log.info "Using database from $DATABASE"
    ln -sf "$DATABASE" /data/tautulli.db
fi
