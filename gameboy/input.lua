local bit32 = require("bit")

local memory = require("gameboy/memory")
local io = require("gameboy/io")

local input = {}

input.keys = {}
input.keys.Left = 0
input.keys.Right = 0
input.keys.Up = 0
input.keys.Down = 0
input.keys.A = 0
input.keys.B = 0
input.keys.Start = 0
input.keys.Select = 0

input.update = function()
  local d_pad_bits = input.keys.Right +
               bit32.lshift(input.keys.Left, 1) +
               bit32.lshift(input.keys.Up, 2) +
               bit32.lshift(input.keys.Down, 3)
  local button_bits = input.keys.A +
                bit32.lshift(input.keys.B, 1) +
                bit32.lshift(input.keys.Select, 2) +
                bit32.lshift(input.keys.Start, 3)

  local active_bits = 0
  if bit32.band(io.ram[io.ports.JOYP], 0x20) == 0 then
    active_bits = bit32.bor(active_bits, button_bits)
  end
  if bit32.band(io.ram[io.ports.JOYP], 0x10) == 0 then
    active_bits = bit32.bor(active_bits, d_pad_bits)
  end
  active_bits = bit32.bnot(active_bits)

  io.ram[io.ports.JOYP] = bit32.bor(io.ram[io.ports.JOYP], bit32.band(active_bits, 0x0F))
end

-- Register hooks for input-related registers
io.write_logic[io.ports.JOYP] = function(byte)
  io.ram[io.ports.JOYP] = bit32.band(byte, 0x30)  
  input.update()
end

return input
