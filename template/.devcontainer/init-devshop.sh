#!/usr/bin/env bash
# Thin forwarder — delegates to devshop injection script if mounted.
[ -f /devshop/.devshop/scripts/init-devshop.sh ] && exec bash /devshop/.devshop/scripts/init-devshop.sh
