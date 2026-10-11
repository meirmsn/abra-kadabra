# W10.1.2b — the WHOLE cloud environment setup script. Only the token is UI-held; all logic is in
# bootstrap.sh at the devshop repo root (default branch). Works once PR #46 is merged.
git clone -q --bare https://x-access-token:PASTE_TOKEN_HERE@github.com/meirmsn/abra-kadabra.git /opt/devshop.git > /tmp/devshop-clone.log 2>&1 || true
git --git-dir=/opt/devshop.git show HEAD:bootstrap.sh | bash || true
