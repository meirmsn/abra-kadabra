#!/usr/bin/env bash
# Thin forwarder — delegates to tooling injection script if mounted.
[ -f /devshop/kit/scripts/init-devshop.sh ] && exec bash /devshop/kit/scripts/init-devshop.sh
