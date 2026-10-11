# W10.1.2b — the WHOLE cloud environment setup script. Only the token is UI-held; all logic is in bootstrap.sh.
git clone -q --bare https://x-access-token:PASTE_TOKEN_HERE@github.com/meirmsn/abra-kadabra.git /opt/devshop.git > /tmp/devshop-clone.log 2>&1
git --git-dir=/opt/devshop.git show claude/gallant-keller-1f1ih8:kit/notes/revamp/spikes/w10-1-2b-thin/bootstrap.sh | bash -s claude/gallant-keller-1f1ih8
