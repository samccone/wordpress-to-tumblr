xml2js            = require 'xml2js'
fs                = require 'fs'
parser            = new xml2js.Parser()
OAuth             = require('oauth').OAuth
tumblrOptions     = require('./keys.js').keys

postToTumblr = (_token, _secret, _post, _tumblr, cb) ->
  tumblr = new OAuth "http://www.tumblr.com/oauth/request_token",
                     "http://www.tumblr.com/oauth/access_token",
                     tumblrOptions.consumerKey,
                     tumblrOptions.consumerSecret,
                     "1.0",
                     null,
                     "HMAC-SHA1"

  tumblr.post "http://api.tumblr.com/v2/blog/"+_tumblr+".tumblr.com/post",
              _token,
              _secret,
              _post,
              "application/json",
              (err, data, res) ->
                if err then throw new Error "Error Posting " + JSON.stringify err
                if cb
                  cb()
                else
                  console.log "Uploads Complete!"


exports.readAndParseXml = (filename, cb) ->
  fs.readFile filename, 'utf8', (err, data) ->
    if err then throw new Error "Error Reading File " + err
    parser.parseString data, (err, data) ->
      if err then throw new Error "Error Parsing File " + err
      cb(data)

exports.uploadPostsToTumblr = (args) ->
  toPost = []
  for post in args.imports
    for wp_post in args.wordpress.channel.item
      if wp_post['wp:post_id'] == post
        if wp_post["content:encoded"].length && wp_post["title"].length
          toPost.push
                        body: wp_post["content:encoded"],
                        title: wp_post["title"]
  if toPost.length
    stepPost toPost, 0, args


stepPost = (posts, index, args) ->
  cb = if posts.length > index + 1 then () -> stepPost(posts, index + 1, args)
  current = index + 1
  console.log "Importing Post " + current + " of " + posts.length
  postToTumblr args.token,
             args.secret,
             posts[index],
             args.tumblr,
             cb

exports.postToTumblr = postToTumblr