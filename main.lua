--[[
  Implementation on game logic and presentation 
  was largely influenced by the cs50 course.
  ]]

host = true

socket = require("socket")
udp = socket.udp()
udp:setsockname("127.0.0.1", 12345)
-- distinguish host from external client
if string.format("%s",udp:getsockname()) == '0.0.0.0' then
  udp:setpeername("127.0.0.1", 12345)
  udp:send("join")
  host = false
end

WIDTH = 1000
HEIGHT = 600

PADDLE_WIDTH = 16
PADDLE_HEIGHT = 64
PADDLE_SPEED = 280

BALL_SIZE = 16

LARGE_FONT = love.graphics.newFont(32)
SMALL_FONT = love.graphics.newFont(16)

gameState = 'title'

player1 = {
  x = 20, y = 20, score = 0
}

player2 = {
  x = WIDTH - PADDLE_WIDTH - 20,
  y = HEIGHT - PADDLE_HEIGHT - 20,
  score = 0
}

ball = {
  x = WIDTH / 2 - BALL_SIZE / 2,
  y = HEIGHT / 2 - BALL_SIZE / 2,
  dx = 0, dy = 0
}


function love.load()
  math.randomseed(os.time())
  love.graphics.setDefaultFilter('nearest', 'nearest')
  love.window.setMode(WIDTH, HEIGHT, {resizable=false, vsync=false})
  love.window.setTitle('Pong')
  resetBall()
  if host then
    currentPlayer = player1
    opponentPlayer = player2
  else 
    currentPlayer = player2
    opponentPlayer =  player1
  end

  if host then
    love.window.setTitle('Pong Host')
    local data, ip, port = udp:receivefrom()
    udp:setpeername(ip, port)
  end
  udp:settimeout(0)
end

function love.update(dt)
  if love.keyboard.isDown('w') then
    currentPlayer.y = currentPlayer.y - PADDLE_SPEED * dt
  elseif love.keyboard.isDown('s') then
    currentPlayer.y = currentPlayer.y + PADDLE_SPEED * dt
  end

  if host then
    if gameState == 'play' then
      ball.x = ball.x + ball.dx * dt
      ball.y = ball.y + ball.dy * dt

      if ball.y <= 0 then
        ball.dy = -ball.dy
      elseif ball.y >= HEIGHT - BALL_SIZE then
        ball.dy = -ball.dy
      end

      if collides(ball, player1) then
        ball.x = player1.x + PADDLE_WIDTH
        ball.dx = -ball.dx
      elseif collides(ball, player2) then
        ball.x = player2.x - BALL_SIZE
        ball.dx = -ball.dx
      end

      if ball.x <= 0 then
        resetBall()
        gameState = 'serve'
        player2.score = player2.score + 1
        if player2.score >= 3 then gameState = 'win' end
      elseif ball.x >= WIDTH - BALL_SIZE then
        resetBall()
        gameState = 'serve'
        player1.score = player1.score + 1
        if player1.score >= 3 then gameState = 'win' end
      end
    end

    udp:send(string.format("%s %s,%s,%s,%s", "ball", ball.x, ball.y, ball.dx, ball.dy))
    udp:send(string.format("%s %s,%s", "score", player1.score, player2.score))
    udp:send(string.format("%s %s", "status", gameState))
  end

  repeat
    data = udp:receive()
    if data then
      -- type, data = table.unpack(split(data, " "))
      info = split(data, " ")
      if info[1] == "player" then
        -- x, y = table.unpack(split(data, ","))
        coord = split(info[2], ",")
        opponentPlayer.x = tonumber(coord[1])
        opponentPlayer.y = tonumber(coord[2])
      end
      if not host then
        if info[1] == "score" then
          points = split(info[2], ",")
          opponentPlayer.score = points[1]
          currentPlayer.score = points[2]
        elseif info[1] == "ball" then
          ballPrp = split(info[2], ",")
          ball.x = ballPrp[1]
          ball.y = ballPrp[2]
          ball.dx = ballPrp[3]
          ball.dy = ballPrp[4]
        elseif info[1] == "status" then
          gameState = info[2]
        end
      end
    end
  until not data

  udp:send(string.format("%s %s,%s", "player", currentPlayer.x, currentPlayer.y))
end

function split(s, delimiter)
  result = {};
  for match in (s..delimiter):gmatch("(.-)"..delimiter) do
      table.insert(result, match);
  end
  return result;
end

function love.keypressed(key)
  if key == 'escape' then
    upd:close()
    love.event.quit()
  end

  if key == 'enter' or key == 'return' then
    if gameState == 'title' then
      gameState = 'serve'
    elseif gameState == 'serve' then
      gameState = 'play'
    elseif gameState == 'win' then
      player1.score = 0
      player2.score = 0
      gameState = 'title'
    end
  end
end

function love.draw()
  love.graphics.clear(40/255, 45/255, 52/255, 255/255)

  if gameState == 'title' then
    love.graphics.setFont(LARGE_FONT)
    love.graphics.printf('Pong', 0, 10, WIDTH, 'center')
    love.graphics.setFont(SMALL_FONT)
    love.graphics.printf('Press Enter', 0, HEIGHT - 32, WIDTH, 'center')
  elseif gameState == 'serve' then
    love.graphics.setFont(SMALL_FONT)
    love.graphics.printf('Press Enter to Serve!', 0, 10, WIDTH, 'center')
  elseif gameState == 'win' then
    love.graphics.setFont(LARGE_FONT)
    local winner = player1.score >= 3 and '1' or '2'
    love.graphics.printf('Player ' .. winner .. ' wins!', 0, 10, WIDTH, 'center')
    love.graphics.setFont(SMALL_FONT)
    love.graphics.printf('Press Enter to Restart', 0, HEIGHT - 32, WIDTH, 'center')
  end

  love.graphics.setFont(LARGE_FONT)
  love.graphics.print(player1.score, WIDTH / 2 - 36, HEIGHT / 2 - 16)
  love.graphics.print(player2.score, WIDTH / 2 + 16, HEIGHT / 2 - 16)
  love.graphics.setFont(SMALL_FONT)

  love.graphics.rectangle('fill', player1.x, player1.y, PADDLE_WIDTH, PADDLE_HEIGHT)
  love.graphics.rectangle('fill', player2.x, player2.y, PADDLE_WIDTH, PADDLE_HEIGHT)
  love.graphics.rectangle('fill', ball.x, ball.y, BALL_SIZE, BALL_SIZE)
end

function collides(b, p)
  return not (b.y > p.y + PADDLE_HEIGHT or b.x > p.x + PADDLE_WIDTH or p.y > b.y + BALL_SIZE or p.x > b.x + BALL_SIZE)
end

function resetBall()
  ball.x = WIDTH / 2 - BALL_SIZE / 2
  ball.y = HEIGHT / 2 - BALL_SIZE / 2

  ball.dx = 120 + math.random(180)
  if math.random(2) == 1 then
    ball.dx = -ball.dx
  end

  ball.dy = 60 + math.random(120)
  if math.random(2) == 1 then
    ball.dy = -ball.dy
  end
end
