import base, { coreRules } from "./oxlint.config.mts";

// Explicit proposal, not an ordinary check or editor gate.
export default { ...base, rules: { ...base.rules, ...coreRules, "oxc/no-accumulating-spread": "error" } };
