var exec = require('cordova/exec');

var PLUGIN_NAME = 'VideoConversationPlugin';

var conversations = {
  open: function(callTo,token,remoteParticipantName,succ,fail) {
    cordova.exec(
      succ || function(){},
      fail || function(){},
	  PLUGIN_NAME,
      'open',
      [callTo,token,remoteParticipantName]
    );
  },
  getTwilioVersion: function(cb) {
	cordova.exec(
	  cb,
	  null,
	  PLUGIN_NAME,
      'getTwilioVersion',
      []
	);		  
  }
};

module.exports = conversations;
