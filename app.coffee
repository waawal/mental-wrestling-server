require('nodefly').profile(
    process.env.NODEFLY_APPLICATION_KEY,
    [process.env.APPLICATION_NAME,'Heroku']
)

express = require('express.io')
app = express().http().io()

app.use(express.cookieParser())
app.use(express.session({secret: process.env.SECRET or 'monkey'}))
app.use(express.static('public'))

app.io.configure ->
  app.io.set("transports", ["xhr-polling"])
  app.io.set("polling duration", 10)

playerQueue = []
activeGames = {}
clicks = {}

class Game

  constructor: (@roomName, @pl1, @pl2) ->
    @emitToRoom 'screen', 'game'
    #@pl1.socket.on "disconnect", =>
    #  @endGame(@pl2, @pl1)
    #@pl2.socket.on "disconnect", =>
    #  @endGame(@pl1, @pl2)
    bgChoice = [0,1,2]
    @emitToRoom 'playerInfo',
      pl1:
        name: pl1.session.playerName
        avatar: pl1.session.playerAvatar
      pl2:
        name: pl2.session.playerName
        avatar: pl2.session.playerAvatar
      bg:
        bgChoice[Math.floor(Math.random() * bgChoice.length)]
    
    @emitToRoom 'gameStatus', 'preGame'
    setTimeout (=>
      @startGame()
      ), 2500

  emitToRoom: (event, data) =>
    app.io.room(@roomName).broadcast event, data

  startGame: =>
    @emitToRoom 'gameStatus', 'inGame'
    @interval = setInterval(=>
      @checkClicks()
    , 1000)
  endGame: (winner, loser) ->
    @emitToRoom 'gameStatus', 'endGame'
    winner.io.emit 'winner', true
    loser.io.emit 'winner', false
    clicks[@pl1.session.playerName] = 0
    clicks[@pl2.session.playerName] = 0
    @pl1.io.leave(@roomName)
    @pl2.io.leave(@roomName)
    clearInterval(@interval)
    delete activeGames[@roomName]
    setTimeout(=>
      winner.io.emit 'screen', 'character'
      loser.io.emit 'screen', 'character'
    , 5000)

  checkClicks: =>
    # TODO: Fix algo!
    diff = clicks[@pl1.session.playerName] - clicks[@pl2.session.playerName]
    if diff < -50
      @endGame(@pl2, @pl1)
    else if diff > 50
      @endGame(@pl1, @pl2)
    percent = diff + 50
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
      clicks[req.session.playerName] = 0

  ready: (req) ->
    playerQueue.push req
    clicks[req.session.playerName] = 0
    req.io.emit 'screen', "waiting"

  click: (req) ->
    clicks[req.session.playerName] += req.data

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


app.listen process.env.PORT or 7076
