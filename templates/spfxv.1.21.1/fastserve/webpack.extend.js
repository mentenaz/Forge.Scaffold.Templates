const path = require("path");

// fast-serve serves bundles from src/ via ts-loader — aliases must resolve
// against src/, not against the compiled lib/ output.
const srcRoot = path.resolve(__dirname, "../src");

const webpackConfig = {};

const transformConfig = function (initialWebpackConfig, webpack) {
  // @pnp packages reference .module.scss files not shipped in the package —
  // replace with a local empty stub so webpack does not fail to resolve them.
  initialWebpackConfig.plugins.push(
    new webpack.NormalModuleReplacementPlugin(/\.module\.scss$/, (resource) => {
      if (resource.context && resource.context.includes("@pnp")) {
        resource.request = path.resolve(__dirname, "empty.module.scss");
      }
    }),
  );

  // Mirror tsconfig.json `paths` directly onto the webpack config so that
  // @-aliases in compiled lib/ files resolve back to src/ TypeScript sources
  // (ts-loader handles the compilation on the fly).
  if (!initialWebpackConfig.resolve) initialWebpackConfig.resolve = {};
  if (!initialWebpackConfig.resolve.alias)
    initialWebpackConfig.resolve.alias = {};

  Object.assign(initialWebpackConfig.resolve.alias, {
    "@Types": path.resolve(srcRoot, "Types"),
  });

  return initialWebpackConfig;
};

module.exports = {
  webpackConfig,
  transformConfig,
};
