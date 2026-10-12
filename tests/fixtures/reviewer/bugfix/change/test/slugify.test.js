import { test } from "node:test";
import assert from "node:assert/strict";
import { slugify } from "../src/slugify.js";
test("lowercases", () => assert.equal(slugify("Hello"), "hello"));
test("strips other characters", () => assert.equal(slugify("a!b"), "ab"));
test("rejects non-strings", () => assert.throws(() => slugify(42), TypeError));
// Regression: "a  b" gave "a--b" because each whitespace character became its own dash.
test("a run of whitespace becomes one dash", () => assert.equal(slugify("a  b\t c"), "a-b-c"));
