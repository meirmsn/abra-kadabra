export function slugify(s) {
  if (typeof s !== "string") throw new TypeError("slugify expects a string");
  return s.toLowerCase().replace(/\s+/g, "-").replace(/[^a-z0-9-]/g, "");
}
