xml2js            = require 'xml2js'
fs                = require 'fs'
parser            = new xml2js.Parser()

exports.readAndParseXml = (filename, cb) ->
  fs.readFile filename, 'utf8', (err, data) ->
    if err then throw new Error "Error Reading File " + err
    parser.parseString data, (err, data) ->
      if err then throw new Error "Error Parsing File " + err
      cb(data)

exports.uploadPostsToTumblr = (args) ->
  console.log args