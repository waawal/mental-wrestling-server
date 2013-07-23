app = require("express.io")()
app.http().io()

#build your realtime-web app
app.listen 7076

class Game

  constructor: (@roomName) ->
    @room = app.io.room(@roomName)
    [@pl1, @pl2] = app.io.sockets.clients(@roomName)
    @pl1.set 'roomName', @roomName
    @pl2.set 'roomName', @roomName
    @pl1.set 'clicks', 0
    @emitToRoom 'gameStatus', 'preGame'
    setTimeOut (=>
      @startGame()
      ), 10000

  emitToRoom: (event, data) =>
    app.io.sockets.in(@roomName).emit event, data

  startGame: ->
    @emitToRoom 'gameStatus', 'inGame'
    @interval = setInterval(=>
      @checkClicks()
    , 2000)
  endGame: (winner) ->
    @emitToRoom 'gameStatus', 'endGame'
    @emitToRoom 'winner', winner.get('playerName')
    @pl1.set 'roomName', @roomName
    @pl2.set 'roomName', @roomName
    @pl1.leave(@roomName)
    @pl2.leave(@roomName)
    clearInterval(@interval)

  checkClicks: ->
    # TODO: Fix algo!
    if @pl1.totalClicks >= 200
      @endGame(@pl1)
    else if @pl2.totalClicks >= 200
      @endGame(@pl2)


app.io.route "player",
  name: (req) ->
    req.io.set 'playerName', req.data

  avatar: (req) ->
    req.io.set 'playerAvatar', req.data

  ready: (req) ->
    req.io.join 'ready'

  click: (req) ->
    if req.io.get(roomName)
      req.io.set 'clicks', req.io.get(clicks) + req.data

setInterval (->
    sockets = app.io.sockets.clients('ready')
    if sockets.length >= 2
      pl1 = sockets[0]
      pl2 = sockets[1]
      roomName = "#{ sockets[0].get('playerName') }-#{ sockets[1].get('playerName') }"
      pl1.join roomName
      pl2.join roomName
      pl1.leave 'ready'
      pl2.leave 'ready'
      new Game(roomName)
  ), 500

# Send the client html.
app.get "/", (req, res) ->
  res.sendfile __dirname + "/client.html"