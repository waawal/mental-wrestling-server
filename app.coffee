express = require('express.io')
app = express().http().io()

app.use(express.cookieParser())
app.use(express.session({secret: 'monkey'}))



playerQueue = []
activeGames = {}

class Game

  constructor: (@roomName, @pl1, @pl2) ->
    @pl1.session.roomName = @roomName
    @pl2.session.roomName = @roomName
    @pl1.session.clicks = 0
    @pl2.session.clicks = 0
    @emitToRoom 'screen', 'game'
    @emitToRoom 'playerInfo',
      pl1:
        name: pl1.session.playerName
        avatar: pl1.session.playerAvatar
      pl2:
        name: pl2.session.playerName
        avatar: pl2.session.playerAvatar
    @emitToRoom 'gameStatus', 'preGame'
    setTimeout (=>
      @startGame()
      ), 10000

  emitToRoom: (event, data) =>
    app.io.room(@roomName).broadcast event, data

  startGame: =>
    @emitToRoom 'gameStatus', 'inGame'
    @interval = setInterval(=>
      @checkClicks()
    , 2000)
  endGame: (winner) ->
    @emitToRoom 'gameStatus', 'endGame'
    @emitToRoom 'winner', winner.session.playerName
    @pl1.session.roomName = false
    @pl2.session.roomName = false
    @pl1.leave(@roomName)
    @pl2.leave(@roomName)
    @pl1.session.save()
    @pl2.session.save()
    clearInterval(@interval)
    delete activeGames[roomName]

  checkClicks: ->
    # TODO: Fix algo!
    total = @pl1.session.totalClicks + @pl2.session.totalClicks
    percent = 100 / total * @pl1.session.totalClicks
    if @pl1.session.totalClicks >= 200
        @endGame(@pl1)
    if @pl2.session.totalClicks >= 200
        @endGame(@pl2)
    @emitToRoom 'score', percent

app.io.route "player",
  name: (req) ->
    req.session.playerName = req.data
    req.session.save ->
      req.io.emit 'screen', "character"

  avatar: (req) ->
    req.session.playerAvatar = req.data
    req.session.save ->
      playerQueue.push req
      req.io.emit 'screen', "waiting"

  ready: (req) ->
    playerQueue.push req
    req.io.emit 'screen', "waiting"

  click: (req) ->
    if req.session.roomName
      req.session.clicks += req.data

checkQueue = ->
  setTimeout(checkQueue, 500)
  if playerQueue.length >= 2
    sockets = playerQueue.splice(0,2)
    pl1 = sockets[0]
    pl2 = sockets[1]
    roomName = "#{ pl1.session.playerName }-#{ pl2.session.playerName }"
    pl1.io.join roomName
    pl2.io.join roomName
    activeGames[roomName] = new Game(roomName, pl1, pl2)
setTimeout(checkQueue, 500)

# Send the client html.
app.get "/", (req, res) ->
  res.sendfile __dirname + "/client.html"


app.listen 7076