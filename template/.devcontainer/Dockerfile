FROM mcr.microsoft.com/devcontainers/javascript-node:20

ARG TZ
ENV TZ="$TZ"

ARG CLAUDE_CODE_VERSION
ARG GIT_DELTA_VERSION
ARG SUPABASE_CLI_VERSION
ARG DCG_VERSION
ARG GITLEAKS_VERSION

# Install firewall tools and any extras not included in the base image
# Note: git, zsh, Oh My Zsh, fzf, jq, sudo, nano, vim, less, unzip, gnupg2, procps, man-db, and a non-root node user are all provided by the Microsoft base image and do not need to be installed here.
# gh (GitHub CLI) was dropped from the base image in Debian Trixie — installed separately below.
RUN apt-get update && apt-get install -y --no-install-recommends \
  iptables \
  ipset \
  iproute2 \
  dnsutils \
  aggregate \
  wget \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Chromium (for Playwright) + its shared C library dependencies.
#
# Why apt-installed Chromium and not Playwright's CDN download:
# Playwright's CDNs (cdn.playwright.dev, playwright.download.prss.microsoft.com)
# are firewall-allowlisted by domain name, but their edge IPs rotate while the
# devcontainer's resolved ipset goes stale within hours of init-firewall.sh
# running. A mid-session `pnpm exec playwright install chromium` then fails
# with EHOSTUNREACH, blocking every browser-dependent gate (gstack browse
# daemon, /design-review, /qa, /benchmark, Playwright E2E). Re-running
# init-firewall.sh is itself unreliable for the same DNS-rotation reason, so
# this is effectively unfixable at the Playwright-download layer. Baking
# Chromium into the image with apt eliminates the dependency on the CDN
# being reachable post-build.
#
# Playwright is told to use this binary via PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH
# in devcontainer.json's containerEnv. The shared libs below are still needed
# even with apt-installed chromium because chromium's own deps may not pull
# in every transitive dep Playwright tests trigger. Package names use the
# Debian Trixie (t64) suffix where applicable.
RUN apt-get update && apt-get install -y --no-install-recommends \
  chromium \
  chromium-driver \
  libnspr4 \
  libnss3 \
  libatk1.0-0t64 \
  libatk-bridge2.0-0t64 \
  libdbus-1-3 \
  libcups2t64 \
  libxkbcommon0 \
  libasound2t64 \
  libgbm1 \
  libxcomposite1 \
  libxdamage1 \
  libxfixes3 \
  libxrandr2 \
  libatspi2.0-0t64 \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# GitHub CLI — not in default Debian repos. Needed for git push (credential helper),
# PR creation/merge, CI status checks, and the autonomous /build workflow.
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
  && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
  | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
  && apt-get update && apt-get install -y --no-install-recommends gh \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# No docker CLI in the workspace — compose isolation puts the
# docker socket on the supabase-runner sibling service only. Workspace
# drives supabase commands via `pnpm db:*` → cmd-relay on :9000.

ARG USERNAME=node

# Persist bash history in a dedicated volume-backed directory. The directory is created at build time so Docker has a valid mount point. At runtime the named volume overlays this directory, making history persist across container rebuilds.
RUN mkdir /commandhistory \
  && touch /commandhistory/.bash_history \
  && chown -R $USERNAME /commandhistory

# Set `DEVCONTAINER` environment variable to help with orientation
ENV DEVCONTAINER=true

# Create workspace and Claude config directories and set permissions.
# /home/node/.claude is backed by a named volume so credentials and session history survive container rebuilds.
RUN mkdir -p /workspace /home/node/.claude && \
  chown -R node:node /workspace /home/node/.claude

WORKDIR /workspace

# ============================================================
# Binary installs (root) — version-pinned + checksum-verified
# All binaries are grouped here to minimize USER switches.
# Checksums file format: <sha256>  <prefix>/<filename>
# The grep finds the line by prefix/filename, sed strips the
# prefix so sha256sum -c sees <hash>  <local-filename>.
# ============================================================

COPY checksums.sha256 /checksums.sha256

# git-delta — syntax-highlighted git diffs
RUN ARCH=$(dpkg --print-architecture) && \
  FILE="git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
  wget -q "https://github.com/dandavison/delta/releases/download/${GIT_DELTA_VERSION}/${FILE}" && \
  grep "git-delta/${FILE}" /checksums.sha256 | sed 's|git-delta/||' | sha256sum -c - && \
  dpkg -i "$FILE" && \
  rm "$FILE"

# Supabase CLI — managing migrations and edge functions
RUN ARCH=$(dpkg --print-architecture) && \
  FILE="supabase_linux_${ARCH}.tar.gz" && \
  wget -q "https://github.com/supabase/cli/releases/download/v${SUPABASE_CLI_VERSION}/${FILE}" && \
  grep "supabase/${FILE}" /checksums.sha256 | sed 's|supabase/||' | sha256sum -c - && \
  tar xzf "$FILE" supabase && \
  mv supabase /usr/local/bin/supabase && \
  rm "$FILE"

# DCG (Destructive Command Guard) — PreToolUse safety hook for Claude Code
# Blocks git reset --hard, force push, rm -rf outside /tmp, DROP TABLE, and 49+ other
# destructive patterns including heredoc/inline-script scanning. Fail-open design.
RUN ARCH=$(dpkg --print-architecture | sed 's/amd64/x86_64/;s/arm64/aarch64/') && \
  FILE="dcg-${ARCH}-unknown-linux-gnu.tar.xz" && \
  wget -q "https://github.com/Dicklesworthstone/destructive_command_guard/releases/download/v${DCG_VERSION}/${FILE}" && \
  grep "dcg/${FILE}" /checksums.sha256 | sed 's|dcg/||' | sha256sum -c - && \
  tar xJf "$FILE" -C /usr/local/bin && \
  chmod +x /usr/local/bin/dcg && \
  rm "$FILE"

# gitleaks — secret scanning in pre-commit hook
RUN ARCH=$(dpkg --print-architecture | sed 's/amd64/x64/;s/arm64/arm64/') && \
  FILE="gitleaks_${GITLEAKS_VERSION}_linux_${ARCH}.tar.gz" && \
  wget -q "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/${FILE}" && \
  grep "gitleaks/${FILE}" /checksums.sha256 | sed 's|gitleaks/||' | sha256sum -c - && \
  tar xzf "$FILE" -C /usr/local/bin gitleaks && \
  chmod +x /usr/local/bin/gitleaks && \
  rm "$FILE"

# Grant node passwordless sudo for root-only scripts
COPY init-firewall.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/init-firewall.sh && \
  echo "node ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" > /etc/sudoers.d/node-firewall && \
  chmod 0440 /etc/sudoers.d/node-firewall

COPY init-devshop.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/init-devshop.sh && \
  echo "node ALL=(root) NOPASSWD: /usr/local/bin/init-devshop.sh" >> /etc/sudoers.d/node-firewall && \
  chmod 0440 /etc/sudoers.d/node-firewall

# No init-docker-socket.sh under compose isolation — the workspace has no docker
# socket to align (the docker socket lives on supabase-runner only).

# Remove blanket sudo — base image (common-utils) grants NOPASSWD:ALL by default. Only the firewall script should run as root (see node-firewall sudoers entry above).
RUN rm -f /etc/sudoers.d/node

# ============================================================
# User-space installs (node) — npm globals, shell config
# ============================================================

USER node

# npm global prefix so node user can manage global packages without sudo
ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH=$PATH:/usr/local/share/npm-global/bin

# Shell and editor defaults
ENV SHELL=/bin/zsh
ENV EDITOR=nano
ENV VISUAL=nano

# Configure git-delta as the default git pager
RUN git config --global core.pager delta \
  && git config --global interactive.diffFilter "delta --color-only" \
  && git config --global delta.navigate true \
  && git config --global delta.side-by-side true \
  && git config --global delta.line-numbers true

# Persistent shell history for zsh (volume-backed)
RUN echo 'export HISTFILE=/commandhistory/.bash_history' >> ~/.zshrc \
  && echo "export PROMPT_COMMAND='history -a'" >> ~/.zshrc

# Global npm packages
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}
RUN npm install -g bun
RUN npm install -g pnpm
