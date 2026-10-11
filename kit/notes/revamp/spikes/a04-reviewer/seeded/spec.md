# Spec: slugify()

Acceptance:
1. AC-1: lowercases the input ("Hello" -> "hello").
2. AC-2: replaces runs of whitespace with a single "-" ("a  b" -> "a-b").
3. AC-3: strips characters other than [a-z0-9-] ("a!b" -> "ab").
4. AC-4: throws a TypeError when the input is not a string.
Each acceptance item must have a test.
