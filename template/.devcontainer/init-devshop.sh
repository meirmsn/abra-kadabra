#!/usr/bin/env bash
# Forwarder - delegates to mounted injection script if available.
[ -f /devshop/kit/scripts/init-devshop.sh ] && exec bash /devshop/kit/scripts/init-devshop.sh
