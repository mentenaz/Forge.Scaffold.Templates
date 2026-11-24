const path = require("path");

/**
 * you can add your project related webpack configuration here, it will be merged using webpack-merge module
 * i.e. plugins: [new webpack.Plugin()]
 */
const webpackConfig = {};

/**
 * For even more fine-grained control, you can apply custom webpack settings using below function
 * @param {object} initialWebpackConfig - initial webpack config object
 * @param {object} webpack - webpack object, used by SPFx pipeline
 * @returns webpack config object
 */
const transformConfig = function (initialWebpackConfig, webpack) {
  // @pnp packages reference .module.scss files that are not shipped in the package:
  // replace them with a local empty stub so webpack does not fail to resolve them.
  initialWebpackConfig.plugins.push(
    new webpack.NormalModuleReplacementPlugin(/\.module\.scss$/, (resource) => {
      if (resource.context && resource.context.includes("@pnp")) {
        resource.request = path.resolve(__dirname, "empty.module.scss");
      }
    }),
  );

  return initialWebpackConfig;
};

module.exports = {
  webpackConfig,
  transformConfig,
};
