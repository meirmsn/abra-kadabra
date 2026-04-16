#!/usr/bin/env bats
# Tests for kit/scripts/normalize-devshop-paths.sh
# Pure pipe: stdin → sed transformation → stdout

setup() {
  load helpers/setup
  NORMALIZE="$SCRIPTS_DIR/normalize-devshop-paths.sh"
}

@test "rewrites kit/ to .devshopkit/" {
  result=$(echo "kit/scripts/foo.sh" | bash "$NORMALIZE")
  assert_equal "$result" ".devshopkit/scripts/foo.sh"
}

@test "preserves absolute /devshop/kit/ paths" {
  result=$(echo "/devshop/kit/scripts/foo.sh" | bash "$NORMALIZE")
  assert_equal "$result" "/devshop/kit/scripts/foo.sh"
}

@test "handles mixed absolute and relative in same input" {
  input=$'kit/hooks/pre-commit.sh\n/devshop/kit/scripts/init.sh\nkit/docs/MODEL.md'
  expected=$'.devshopkit/hooks/pre-commit.sh\n/devshop/kit/scripts/init.sh\n.devshopkit/docs/MODEL.md'
  result=$(echo "$input" | bash "$NORMALIZE")
  assert_equal "$result" "$expected"
}

@test "passes through lines with no kit/ references" {
  result=$(echo "src/index.ts" | bash "$NORMALIZE")
  assert_equal "$result" "src/index.ts"
}

@test "handles empty input" {
  result=$(echo "" | bash "$NORMALIZE")
  assert_equal "$result" ""
}
