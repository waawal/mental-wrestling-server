app = require("express.io")()
app.http().io()

#build your realtime-web app
app.listen 7076

playerQueue = []
activeGames = {}

class Game

  constructor: (@roomName, @pl1, @pl2) ->
    @pl1.socket.set 'roomName', @roomName
    @pl2.socket.set 'roomName', @roomName
    @pl1.socket.set 'clicks', 0
    @pl2.socket.set 'clicks', 0
    @emitToRoom 'screen', 'game'
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
    @emitToRoom 'winner', winner.socket.get('playerName')
    @pl1.socket.set 'roomName', false
    @pl2.socket.set 'roomName', false
    @pl1.leave(@roomName)
    @pl2.leave(@roomName)
    clearInterval(@interval)
    delete activeGames[roomName]

  checkClicks: ->
    # TODO: Fix algo!
    @pl1.socket.get 'totalClicks', (err, amount) ->
      if amount >= 200
        @endGame(@pl1)
    @pl2.socket.get 'totalClicks', (err, amount) ->
      if amount >= 200
        @endGame(@pl2)


app.io.route "player",
  name: (req) ->
    req.socket.set 'playerName', req.data
    req.io.emit 'name', req.data
    req.io.emit 'screen', "character"

  avatar: (req) ->
    req.socket.set 'playerAvatar', req.data
    req.io.emit 'avatar', req.data
    playerQueue.push req
    req.io.emit 'screen', "waiting"

  ready: (req) ->
    playerQueue.push req
    req.io.emit 'screen', "waiting"

  click: (req) ->
    req.socket.get 'roomName', (err, room) ->
      if room
        req.socket.get 'clicks', (err, amount) ->
          req.socket.set('clicks', amount + req.data)

checkQueue ->
  if playerQueue.length >= 2
    sockets = playerQueue.slice(0,2)
    pl1 = sockets[0]
    pl2 = sockets[1]
    roomName = "#{ pl1.socket.id }-#{ pl2.socket.id }"
    pl1.io.join roomName
    pl2.io.join roomName
    activeGames[roomName] = new Game(roomName, pl1, pl2)
  setTimeout(checkQueue, 500)
setTimeout(checkQueue, 500)

# Send the client html.
app.get "/", (req, res) ->
  res.sendfile __dirname + "/client.html"