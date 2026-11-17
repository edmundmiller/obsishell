import base from "./oxlint.config.mts";
import { martinFowlerJevRules } from "./tools/oxlint/anti-slop/martinfowler/jev-rules.ts";

// No semantic plugin is registered by the ordinary config.
const questions = Object.fromEntries(martinFowlerJevRules.map(({ id }) => [`anti-slop-martinfowler-jev/${id}`, "warn"]));

export default {
  ...base,
  jsPlugins: [...base.jsPlugins, { name: "anti-slop-martinfowler-jev", specifier: "./tools/oxlint/anti-slop/martinfowler/jev-plugin.ts" }],
  rules: { ...base.rules, ...questions },
  overrides: [{ files: ["**/*.test.*", "**/*.spec.*", "test/**", "tests/**"], rules: Object.fromEntries(Object.keys(questions).map((id) => [id, "off"])) }],
};
