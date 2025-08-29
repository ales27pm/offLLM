const { spawnSync } = require("node:child_process");

spawnSync("npx", ["react-native", "codegen"], { stdio: "inherit" });
