express = require('express.io')
app = express().http().io()

app.use(express.cookieParser())
app.use(express.session({secret: 'monkey'}))



playerQueue = []
activeGames = {}
clicks = {}

class Game

  constructor: (@roomName, @pl1, @pl2) ->
    @pl1.session.roomName = @roomName
    @pl2.session.roomName = @roomName
    @pl1.session.save()
    @pl2.session.save()
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
      ), 5000

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
    @pl1.io.leave(@roomName)
    @pl2.io.leave(@roomName)
    @pl1.session.save()
    @pl2.session.save()
    clearInterval(@interval)
    delete activeGames[roomName]

  checkClicks: =>
    # TODO: Fix algo!
    diff = clicks[@pl1.session.playerName] - clicks[@pl2.session.playerName]
    if diff < -50
      @endGame(@pl1)
    else if diff > 50
      @endGame(@pl2)
    percent = diff + 50
    #total = clicks[@pl1.session.playerName] + clicks[@pl2.session.playerName]
    #if total
    #  percent = 100 / total * clicks[@pl1.session.playerName]
    #  if percent >= 100
    #      @endGame(@pl1)
    #  if @pl2.session.clicks <= 0
    #      @endGame(@pl2)
    #else
    #  percent = 50
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
      clicks[req.session.playerName] = 50

  ready: (req) ->
    playerQueue.push req
    clicks[req.session.playerName] = 50
    req.io.emit 'screen', "waiting"

  click: (req) ->
    #if req.session.roomName
    console.log req.data
    console.log clicks[req.session.playerName]
    clicks[req.session.playerName] += req.data
    #req.session.clicks += req.data
    #req.session.save()

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