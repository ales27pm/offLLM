module.exports = {
  transform: {
    "^.+\\.[jt]sx?$": "babel-jest",
  },
  testEnvironment: "node",
  coverageThreshold: {
    global: { lines: 40 },
  },
};
