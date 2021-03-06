
var iosHelper = require("../lib/ios-helper");
var utilities = require("../lib/utilities");

module.exports = function(context) {

    var platforms = context.opts.cordova.platforms;

    // Add a build phase which runs a shell script that trims the TwilioVideo framework
    if (platforms.indexOf("ios") !== -1) {
        var xcodeProjectPath = utilities.getXcodeProjectPath(context);
        iosHelper.removeShellScriptBuildPhase(context, xcodeProjectPath);
    }
};
