import { readdirSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

let count = 0;
for (const directory of ["rules/", "martinfowler/rules/"]) {
  for (const name of readdirSync(new URL(`./anti-slop/${directory}`, import.meta.url)).filter((name) => name.endsWith(".test.ts"))) {
    const result = spawnSync(process.execPath, [fileURLToPath(new URL(`./anti-slop/${directory}${name}`, import.meta.url))], { stdio: "inherit" });
    if (result.status !== 0) process.exit(result.status ?? 1);
    count++;
  }
}
console.log(`${count} offline Core/Fowler suites passed`);
