local board = require "src.board"

--------------------------------------------------------------
-- low-res canvas settings
--------------------------------------------------------------
local INT_W, INT_H = 320, 180
local CELL         = 24
local canvas

-- derived grid positions
local TOP_X0, BOT_X0
local GRID_TOP_Y, GRID_BOT_Y

-- colours
local qCol = {0.85,0.85,0.85}
local pCol = {0.80,0.45,0.25}

--------------------------------------------------------------
-- runtime state
--------------------------------------------------------------
local state               -- current board   (from board.lua)
local selectingRow = nil  -- 'top'/'bot' when waiting for dest
local gameOver    = nil   -- nil | "win" | "lose"

--------------------------------------------------------------
-- helpers
--------------------------------------------------------------
local function restartGame()
   state       = board.newBoard()
   selectingRow= nil
   gameOver    = nil
end

local function toInternal(mx,my)
   local sx = love.graphics.getWidth()  / INT_W
   local sy = love.graphics.getHeight() / INT_H
   return mx/sx, my/sy
end

local function coordToPixel(row,col)
   local x0 = (row=="top") and TOP_X0 or BOT_X0
   local y  = (row=="top") and GRID_TOP_Y+CELL/2 or GRID_BOT_Y+CELL/2
   local x  = x0 + (col-1)*CELL + CELL/2
   return x,y
end

local function cellAt(ix,iy)
   -- top row
   if iy>=GRID_TOP_Y and iy<GRID_TOP_Y+CELL then
      local c = math.floor((ix-TOP_X0)/CELL)+1
      if c>=1 and c<=10 then return "top",c end
   end
   -- bottom row
   if iy>=GRID_BOT_Y and iy<GRID_BOT_Y+CELL then
      local c = math.floor((ix-BOT_X0)/CELL)+1
      if c>=1 and c<=5 then return "bot",c end
   end
   return nil
end

--------------------------------------------------------------
-- AI helper
--------------------------------------------------------------
local function aiTurn()
   local mv = board.aiMove(state,'p')
   state    = board.apply(state,'p',mv)
   -- did that freeze the quarters?
   if board.terminalEval(state)==-1 then gameOver="lose" end
end

--------------------------------------------------------------
-- LÖVE callbacks
--------------------------------------------------------------
function love.load()
   love.graphics.setDefaultFilter("nearest","nearest")
   canvas = love.graphics.newCanvas(INT_W,INT_H)

   -- centre both grids horizontally
   local cx  = INT_W/2
   TOP_X0    = cx - (10*CELL)/2
   BOT_X0    = cx - ( 5*CELL)/2
   GRID_TOP_Y= 40
   GRID_BOT_Y= 100

   math.randomseed(os.time())
   restartGame()
end

--------------------------------------------------------------
-- draw whole internal frame
--------------------------------------------------------------
local function drawInternal()
   love.graphics.clear(0.10,0.10,0.12)

   -----------------------------------------------------------
   -- grids
   -----------------------------------------------------------
   love.graphics.setColor(0.25,0.25,0.28)
   for c=0,9 do
      love.graphics.rectangle("line",
         TOP_X0 + c*CELL, GRID_TOP_Y, CELL, CELL)
   end
   for c=0,4 do
      love.graphics.rectangle("line",
         BOT_X0 + c*CELL, GRID_BOT_Y, CELL, CELL)
   end

   -----------------------------------------------------------
   -- coins
   -----------------------------------------------------------
   local function drawCoin(row,col,isQuarter)
      love.graphics.setColor(isQuarter and qCol or pCol)
      local x,y = coordToPixel(row,col)
      love.graphics.circle("fill", x, y, 9)
      love.graphics.setColor(0,0,0)
      love.graphics.circle("line", x, y, 9)
   end
   drawCoin("top",state.q.top,true)
   drawCoin("bot",state.q.bot,true)
   drawCoin("top",state.p.top,false)
   drawCoin("bot",state.p.bot,false)

   -----------------------------------------------------------
   -- UI text
   -----------------------------------------------------------
   love.graphics.setColor(1,1,1)
   love.graphics.print("Turn: "..(state.turn=='q' and "Quarter (YOU)"
                                                 or "Penny (AI)"), 6,4)

   if gameOver then
      -- translucent overlay
      love.graphics.setColor(0,0,0,0.6)
      love.graphics.rectangle("fill",0,0,INT_W,INT_H)
      love.graphics.setColor(1,1,1)
      local msg = (gameOver=="win") and "YOU  WIN!" or "YOU  LOSE!"
      love.graphics.setNewFont(24)
      love.graphics.printf(msg,0,INT_H/2-14,INT_W,"center")
      love.graphics.setNewFont(12)
      love.graphics.printf("(click to play again)",0,INT_H/2+18,INT_W,"center")
      return
   end

   if selectingRow then
      love.graphics.print("Select destination (Esc cancels)",6,INT_H-16)
   else
      love.graphics.print("Click a quarter to move",6,INT_H-16)
   end
end

function love.draw()
   -- 1) render to small canvas
   love.graphics.setCanvas(canvas); love.graphics.origin()
   drawInternal()
   love.graphics.setCanvas()

   -- 2) scale to window
   local w,h   = love.graphics.getDimensions()
   local s     = math.floor(math.min(w/INT_W, h/INT_H))
   local dx    = math.floor((w-INT_W*s)/2)
   local dy    = math.floor((h-INT_H*s)/2)
   love.graphics.setColor(1,1,1)
   love.graphics.draw(canvas,dx,dy,0,s,s)
end

--------------------------------------------------------------
-- input
--------------------------------------------------------------
function love.mousepressed(mx,my,btn)
   if btn~=1 then return end

   -- restart if game over
   if gameOver then restartGame(); return end

   if state.turn~='q' then return end
   if board.terminalEval(state)==-1 then  -- quarters frozen
      gameOver="lose"; return
   end

   local ix,iy = toInternal(mx,my)
   local row,col = cellAt(ix,iy)
   if not row then return end

   if selectingRow==nil then
      -- first click: choose quarter
      if (row=="top" and col==state.q.top) or
         (row=="bot" and col==state.q.bot) then
         selectingRow=row
      end
   else
      -- second click: choose destination
      for _,m in ipairs(board.legalMoves(state,'q')) do
         if m.row==selectingRow and m.dest==col then
            state = board.apply(state,'q',m)
            selectingRow=nil

            -- did that freeze the pennies?
            if board.terminalEval(state)==1 then
               gameOver="win"
            else
               aiTurn()
            end
            return
         end
      end
      selectingRow=nil        -- illegal square clicked
   end
end

function love.keypressed(k)
   if k=="escape" then selectingRow=nil end
end