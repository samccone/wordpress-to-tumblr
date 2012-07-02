xml2js            = require 'xml2js'
fs                = require 'fs'
OAuth             = require('oauth').OAuth
tumblrOptions     = require('./keys.js').keys
s3Keys            = require('./keys.js').s3_keys
cherrio           = require 'cheerio'
request           = require 'request'
awssum            = require 'awssum'
amazon            = awssum.load('amazon/amazon');
S3                = awssum.load('amazon/s3').S3;
parser            = new xml2js.Parser()

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

## Gets Images out of Post
replaceImages = (post, cb) ->
  $ = cherrio.load unescape(post)
  images = [];
  processed = 0;
  $('img').each (index, target) ->
    images.push $(target).attr 'src'
  for image in images
    downloadImage image, (err, data) ->
      processed++
      if err
        cb err
      else
        $('[src="'+data.originalName+'"]').attr('src', "https://s3.amazonaws.com/"+s3Keys.bucket+"/"+data.newFileName)
      if processed == images.length
        cb null, $.html()

## Downloads the images and then sends them to S3
downloadImage = (src, cb) ->
  request.get
    url: src
    encoding: 'binary'
  , (err, response, body) ->
      if err
        cb "error downloading image " + JSON.stringify(err, null, 4)
      else
        uploadToS3 body, (new Date).getTime()+"."+response.headers["content-type"].split('/')[1], src, (error, data) ->
          if error
            cb error
          else
            cb null, data

## Uploads Image To S3
uploadToS3 = (data, filename, originalName, cb) ->
  s3 = new S3
              accessKeyId: s3Keys.access_key_id
              secretAccessKey: s3Keys.secret_access_key
              region: amazon.US_EAST_1
  s3.PutObject
    BucketName: 'wordpress-to-tumblr'
    ObjectName: filename
    ContentLength: new Buffer(data, 'binary').length
    Body: new Buffer(data, 'binary')
  , (err, data) ->
    if err
      cb "Problem Uploading to S3 " + JSON.stringify(err, null, 4)
    else
      data.newFileName = filename
      data.originalName = originalName
      cb null, data

stepPost = (posts, index, args) ->
  cb = if posts.length > index + 1 then () -> stepPost(posts, index + 1, args)
  current = index + 1
  replaceImages posts[index].body, (err, data) ->
    console.log "Importing Post " + current + " of " + posts.length
    if err
      console.log err
    else
      posts[index].body = data
      postToTumblr args.token,
                 args.secret,
                 posts[index],
                 args.tumblr,
                 cb

exports.postToTumblr = postToTumblr