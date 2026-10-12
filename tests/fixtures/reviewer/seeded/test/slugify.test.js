import { test } from "node:test";
import assert from "node:assert/strict";
import { slugify } from "../src/slugify.js";
test("AC-1", () => assert.equal(slugify("Hello"), "hello"));
test("AC-2", () => assert.equal(slugify("a  b"), "a-b"));
test("AC-3", () => assert.equal(slugify("a!b"), "ab"));
