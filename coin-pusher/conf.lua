function love.conf(t)
    t.window.title  = "Coin-Pusher"
    t.window.width  = 640   -- scaled up later
    t.window.height = 360
    t.window.resizable = true
    -- no blurry scaling:
    t.gammacorrect = true
    t.modules.joystick = false
end