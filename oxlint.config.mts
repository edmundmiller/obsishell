import core from "./tools/oxlint/anti-slop/index.ts";

// Only additions with no current findings are active. Full policy stays in the proposal.
export const coreRules = Object.fromEntries(
  Object.keys(core.rules).map((id) => [`anti-slop/${id}`, id === "max-ternary-depth" ? ["error", { maxDepth: 2 }] : "error"]),
);

// Pending migration decision; enabled without exceptions by oxlint.strict.config.mts.
const pending = ["require-readable-spacing"];

export default {
  ignorePatterns: ["node_modules/**", "dist/**", "out/**", "coverage/**", ".next/**", "tools/oxlint/**", ".agents/**", ".claude/**", ".cursor/**"],
  categories: { correctness: "off" },
  jsPlugins: [
    { name: "anti-slop", specifier: "./tools/oxlint/anti-slop/index.ts" },
    { name: "anti-slop-martinfowler", specifier: "./tools/oxlint/anti-slop/martinfowler/index.ts" },
  ],
  rules: {
    ...Object.fromEntries(Object.entries(coreRules).filter(([id]) => !pending.includes(id.slice("anti-slop/".length)))),
    "oxc/no-accumulating-spread": "error",
    "anti-slop-martinfowler/global-data": "warn",
    "anti-slop-martinfowler/long-function": "warn",
    "anti-slop-martinfowler/long-parameter-list": "warn",
    "anti-slop-martinfowler/loops": "warn",
    "anti-slop-martinfowler/mutable-data": "warn",
    "anti-slop-martinfowler/mysterious-name": "warn",
    "anti-slop-martinfowler/repeated-switches": "warn",
  },
};
