var http = require('http');
var https = require('https');
var fs = require('fs');
var decompress = require('decompress');
const exec = require('child_process').exec;

function getFile(url, path, cb) {
    var http_or_https = http;
    if (/^https:\/\//.test(url)) {
        http_or_https = https;
    }
    http_or_https.get(url, function(response) {
        var headers = JSON.stringify(response.headers);
        switch(response.statusCode) {
        case 200:
            var file = fs.createWriteStream(path);
            response.on('data', function(chunk){
//				process.stdout.write('.');
                file.write(chunk);
            }).on('end', function(){
                file.end();
                cb(null);
//				process.stdout.write('\n');
            });
            break;
        case 301:
        case 302:
        case 303:
        case 307:
//			console.log('Redirecting to ' + response.headers.location)
            getFile(response.headers.location, path, cb);
            break;
        default:
            cb(new Error('Server responded with status code ' + response.statusCode));
        }

    })
		.on('error', function(err) {
			cb(err);
		});
}

var filename = 'TwilioVideo.framework'
var dest_dir = 'src/ios/frameworks'
var dest = dest_dir + '/' + filename

console.log("Fetching " + filename);

if (!fs.existsSync(dest_dir)) {
	fs.mkdirSync(dest_dir);
}
getFile('https://github.com/twilio/twilio-video-ios/releases/download/2.7.0/TwilioVideo.framework.zip', dest + '.zip', function(err) {
	if (err === null) {
		console.log("Decompressing " + dest + ".zip")
		decompress(dest + '.zip', dest_dir)
	}
});
