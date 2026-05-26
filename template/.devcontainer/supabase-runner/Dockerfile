FROM debian:trixie-slim

ARG SUPABASE_CLI_VERSION=2.98.2

ENV DEBIAN_FRONTEND=noninteractive

# ca-certificates + curl for fetches; tini for proper signal handling so
# `docker compose stop supabase-runner` cleanly tears down the relay + any
# lingering child processes instead of leaving zombies.
#
# socat: forwards 127.0.0.1:54321 / :54322 inside the runner to
# host.docker.internal:54321 / :54322 so that `supabase start`'s healthcheck
# (which hardcodes 127.0.0.1 for the db connection) can reach the
# supabase_db_* / supabase_kong_* SIBLING containers whose ports are
# bound to the HOST docker engine, not to the runner. Without this,
# `supabase start` fails with
# "dial tcp 127.0.0.1:54322: connect: connection refused" because the
# runner's loopback has nothing listening on those ports.
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl wget gnupg \
      tini socat \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Node 20 — runtime for cmd-relay.mjs (~30 lines, stdlib-only HTTP server).
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Docker CLI client (no daemon). Talks to the host engine via the bind-
# mounted /var/run/docker.sock declared in compose.yml. Required for the
# supabase CLI to spawn its Postgres / Auth / PostgREST / Realtime /
# Edge-Runtime sibling containers.
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/debian/gpg \
       -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" \
       > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends docker-ce-cli docker-compose-plugin \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Supabase CLI — fetched from GitHub releases. Version pinned via build arg
# from compose.yml so workspace + runner stay in lockstep with the
# canonical version in the workspace Dockerfile (SUPABASE_CLI_VERSION).
# Checksum is self-verifying: fetched from the same GitHub release.
RUN ARCH=$(dpkg --print-architecture) \
    && FILE="supabase_linux_${ARCH}.tar.gz" \
    && wget -q "https://github.com/supabase/cli/releases/download/v${SUPABASE_CLI_VERSION}/${FILE}" \
    && wget -qO /tmp/supabase_checksums.txt "https://github.com/supabase/cli/releases/download/v${SUPABASE_CLI_VERSION}/supabase_${SUPABASE_CLI_VERSION}_checksums.txt" \
    && grep "${FILE}" /tmp/supabase_checksums.txt | sha256sum -c - \
    && tar xzf "$FILE" supabase \
    && mv supabase /usr/local/bin/supabase \
    && rm "$FILE" /tmp/supabase_checksums.txt

COPY cmd-relay.mjs /usr/local/bin/cmd-relay.mjs
RUN chmod +x /usr/local/bin/cmd-relay.mjs

EXPOSE 54321 54322 9000

ENTRYPOINT ["/usr/bin/tini", "--"]
