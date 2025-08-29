const path = require("path");
const generate = require("react-native/scripts/generate-codegen-artifacts");

generate({
  config: {
    libraries: [
      {
        type: "modules",
        jsSrcsDir: path.join(__dirname, ".."),
        outputDir: path.join(__dirname, "../build/generated/ios"),
      },
    ],
  },
});
