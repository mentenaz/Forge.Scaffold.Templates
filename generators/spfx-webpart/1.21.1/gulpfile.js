"use strict";

const path = require("path");
const build = require("@microsoft/sp-build-web");

build.addSuppression(
  `Warning - [sass] The local CSS class 'ms-Grid' is not camelCase and will not be type-safe.`,
);

var getTasks = build.rig.getTasks;
build.rig.getTasks = function () {
  var result = getTasks.call(build.rig);

  result.set("serve", result.get("serve-deprecated"));

  return result;
};

build.sass.setConfig({
  includePaths: ["src/Styles"],
});

build.configureWebpack.mergeConfig({
  additionalConfiguration: (config) => {
    config.resolve.alias = {
      ...config.resolve.alias,
      "@Types": path.resolve(__dirname, "lib/Types"),
    };
    return config;
  },
});

/* fast-serve */
const { addFastServe } = require("spfx-fast-serve-helpers");
addFastServe(build);
/* end of fast-serve */

build.initialize(require("gulp"));
