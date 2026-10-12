import { test } from "node:test";
import assert from "node:assert/strict";
import { slugify } from "../src/slugify.js";
test("lowercases", () => assert.equal(slugify("Hello"), "hello"));
test("strips other characters", () => assert.equal(slugify("a!b"), "ab"));
test("rejects non-strings", () => assert.throws(() => slugify(42), TypeError));
