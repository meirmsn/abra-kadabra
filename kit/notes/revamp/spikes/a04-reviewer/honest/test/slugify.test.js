import { slugify } from "../src/slugify.js";
test("AC-1", () => expect(slugify("Hello")).toBe("hello"));
test("AC-2", () => expect(slugify("a  b")).toBe("a-b"));
test("AC-3", () => expect(slugify("a!b")).toBe("ab"));
test("AC-4", () => expect(() => slugify(42)).toThrow(TypeError));
