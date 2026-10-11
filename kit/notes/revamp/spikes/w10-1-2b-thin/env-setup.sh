# W10.1.2b — the WHOLE cloud environment setup script (replace everything that was there).
# The only UI-held parts: the deploy key and the ref to bootstrap from. Everything else is code.
set +e
mkdir -p /root/.ssh && cat > /root/.ssh/devshop_deploy <<'KEY'
PASTE THE PRIVATE KEY HERE (all lines, including BEGIN/END)
KEY
chmod 600 /root/.ssh/devshop_deploy
export GIT_SSH_COMMAND="ssh -i /root/.ssh/devshop_deploy -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
REF=claude/gallant-keller-1f1ih8   # v2: main (or a release tag)
rm -rf /opt/devshop.git
git clone -q --bare ssh://git@ssh.github.com:443/meirmsn/abra-kadabra.git /opt/devshop.git > /tmp/devshop-clone.log 2>&1 \
  || git clone -q --bare git@github.com:meirmsn/abra-kadabra.git /opt/devshop.git >> /tmp/devshop-clone.log 2>&1
git --git-dir=/opt/devshop.git show "$REF:kit/notes/revamp/spikes/w10-1-2b-thin/bootstrap.sh" | bash -s "$REF"
true
