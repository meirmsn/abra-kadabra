#!/usr/bin/env node
// Prints a greeting: node cli.js [name]
const name = process.argv[2] || "world";
console.log(`Hello, ${name}!`);
