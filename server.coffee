express           = require 'express'
fs                = require 'fs'
passport          = require 'passport'
TumblrStrategy    = require('passport-tumblr').Strategy
tumblrOptions     = require('./keys.js').keys
util              = require('./util.js')
webServer         = express.createServer()
users             = {}

webServer.set 'view engine', 'jade'
webServer.use express.cookieParser()
webServer.use express.session
                              secret: "samisreallycool"

webServer.use express.bodyParser()
webServer.use passport.initialize()
webServer.use passport.session()
webServer.use express.static __dirname + '/public'

passport.serializeUser (user, done) ->
  users[user.username] = user
  done null, user.username

passport.deserializeUser (id, done) ->
  done null, users[id]

passport.use new TumblrStrategy(tumblrOptions , (token, tokenSecret, profile, done) ->
  process.nextTick ->
    profile.token = token
    done null, profile
)


## ROUTING
webServer.get '/', (req, res) ->
  res.render 'index', user: req.user

webServer.get '/auth', passport.authenticate('tumblr'),
  (req, res) ->

webServer.get('/oauth', passport.authenticate('tumblr',
  failureRedirect: '/login'
  ), (req, res) ->
    ## Successful authentication, redirect home.
    res.redirect '/'
  )

webServer.post '/upload', (req, res) ->
  fs.readFile req.files.xml.path, (err, data) ->
    filePath = __dirname + "/uploads/"+req.files.xml.filename+".xml"
    fs.writeFile filePath, data, (err) ->
      if err then throw new Error "Error saving file " + err
      req.session.xml = filePath;
      res.redirect '/uploadToTumblr'

webServer.get '/uploadToTumblr', (req, res) ->
  if req.user
    util.readAndParseXml req.session.xml, (data) ->
      res.render 'uploadToTumblr',
        blogs: req.user._json.response.user.blogs
        wordpress: data
  else
    res.redirect '/'

webServer.post '/importToTumblr', (req, res) ->
  util.uploadPostsToTumblr
    wordpress: req.body.wordpress_posts
    tumblr: req.body.blogChoice
    imports: req.body.selectedImports
  res.render 'uploadingToTumblr'

webServer.listen 9000