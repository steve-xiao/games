--------------------------------------------------------------------
-- Pure rules engine for “Coin-Pusher”
-- • Lua-5.1 compatible (no goto, no bit32, etc.)
-- • No vertical-overlap restriction, only the “cannot pass enemy
--   coin on same row” rule.
-- • Returns a table of functions so `require "src.board"` works.
--------------------------------------------------------------------
local M = {}   -- module table to be returned at the end

--------------------------------------------------------------------
-- constants
--------------------------------------------------------------------
local TOP_LEN, BOT_LEN = 10, 5

--------------------------------------------------------------------
-- helpers
--------------------------------------------------------------------
local function deepcopy(t)
   if type(t) ~= "table" then return t end
   local r = {}
   for k,v in pairs(t) do r[k] = deepcopy(v) end
   return r
end

--------------------------------------------------------------------
-- board constructor
--------------------------------------------------------------------
function M.newBoard()
   return { q = {top=1,           bot=1},
            p = {top=TOP_LEN,     bot=BOT_LEN},
            turn = 'q' }          -- quarters start
end

local function occupied(b,row,pos)
   return (b.q[row]==pos) or (b.p[row]==pos)
end

--------------------------------------------------------------------
-- legal-move generator  (no goto)
--------------------------------------------------------------------
function M.legalMoves(b, side)
   local moves  = {}
   local enemy  = (side=='q') and 'p' or 'q'

   for _,row in ipairs({'top','bot'}) do
      local here     = b[side][row]
      local enemyPos = b[enemy][row]
      local rowLen   = (row=='top') and TOP_LEN or BOT_LEN

      for dest = 1, rowLen do
         if dest ~= here and not occupied(b,row,dest) then
            local blocked = (here < enemyPos and dest > enemyPos) or
                            (here > enemyPos and dest < enemyPos)
            if not blocked then
               moves[#moves+1] = {row=row, dest=dest}
            end
         end
      end
   end
   return moves
end

--------------------------------------------------------------------
-- apply move (immutably)
--------------------------------------------------------------------
function M.apply(b, side, m)
   local nb = deepcopy(b)
   nb[side][m.row] = m.dest
   nb.turn = (side=='q') and 'p' or 'q'
   return nb
end

--------------------------------------------------------------------
-- terminal evaluation
--------------------------------------------------------------------
function M.terminalEval(b)
   if #M.legalMoves(b,'q')==0 then return -1 end   -- quarters lose
   if #M.legalMoves(b,'p')==0 then return  1 end   -- pennies lose
   return 0
end

--------------------------------------------------------------------
-- very small depth-2 minimax AI
--------------------------------------------------------------------
local function minimax(b, side, depth)
   local term = M.terminalEval(b)
   if depth==0 or term~=0 then return term, nil end

   local bestScore = (side=='q') and -math.huge or math.huge
   local bestMove  = nil

   for _,mv in ipairs(M.legalMoves(b,side)) do
      local child  = M.apply(b,side,mv)
      local score  = select(1, minimax(child, child.turn, depth-1))
      if side=='q' then
         if score > bestScore then bestScore, bestMove = score, mv end
      else
         if score < bestScore then bestScore, bestMove = score, mv end
      end
   end
   return bestScore, bestMove
end

function M.aiMove(b, side)
   local _,mv = minimax(b, side, 2)
   if not mv then                             -- fallback (shouldn’t occur)
      local list = M.legalMoves(b,side)
      mv = list[math.random(#list)]
   end
   return mv
end

--------------------------------------------------------------------
return M   --<<<<  makes require("src.board") give this table
--------------------------------------------------------------------