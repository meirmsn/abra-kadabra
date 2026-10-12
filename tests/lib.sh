# Shared helpers for tests/*.test.sh (sourced, not run).
# shellcheck shell=bash
fail() { echo "FAIL: $*" >&2; exit 1; }

# rand <charset> <length>: random string (pipefail off here: head closing the pipe is expected).
rand() { (set +o pipefail; LC_ALL=C tr -dc "$1" </dev/urandom 2>/dev/null | head -c "$2"); }

# fake_aws_key: an AWS-access-key-shaped fake, generated so test files hold no secret literal.
fake_aws_key() { echo "AKIA$(rand 'A-Z2-7' 16)"; }

# isolate_git <dir>: point HOME and git config at <dir>, so tests never touch the real ones (L-41).
isolate_git() {
  export HOME="$1/home" GIT_CONFIG_NOSYSTEM=1
  mkdir -p "$HOME"
  git config --global user.name "Scan Test"
  git config --global user.email "scan-test@example.com"
  git config --global init.defaultBranch main
}

# new_repo <dir>: an empty repo with one harmless commit.
new_repo() {
  git init -q "$1"
  printf 'hello\n' >"$1/README.md"
  git -C "$1" add -A && git -C "$1" commit -qm "init"
}

# commit_file <repo> <path> <content>: write and commit one file.
commit_file() {
  printf '%s\n' "$3" >"$1/$2"
  git -C "$1" add -A && git -C "$1" commit -qm "change $2"
}
