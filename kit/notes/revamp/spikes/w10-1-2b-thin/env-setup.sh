# W10.1.2b — the WHOLE cloud environment setup script (replace everything that was there).
# The only UI-held parts: a read-only token and the ref to bootstrap from. Everything else is code.
# SSH is not an option: the image has no ssh client and the network policy blocks SSH (run 2).
set +e
DEVSHOP_READ_TOKEN=PASTE_TOKEN_HERE   # fine-grained, abra-kadabra only, Contents: read-only
REF=claude/gallant-keller-1f1ih8      # v2: main (or a release tag)
auth=$(printf 'x-access-token:%s' "$DEVSHOP_READ_TOKEN" | base64 -w0)
rm -rf /opt/devshop.git
git -c http.extraHeader="Authorization: Basic $auth" \
  clone -q --bare https://github.com/meirmsn/abra-kadabra.git /opt/devshop.git > /tmp/devshop-clone.log 2>&1
git --git-dir=/opt/devshop.git show "$REF:kit/notes/revamp/spikes/w10-1-2b-thin/bootstrap.sh" | bash -s "$REF"
true
