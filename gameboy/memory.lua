local bit32 = require("bit")

local memory = {}

local block_map = {}

memory.print_block_map = function()
  --debug
  print("Block Map: ")
  for b = 0, 0xFF do
    if block_map[b] then
      print(string.format("Block at: %02X starts at %04X", b, block_map[b].start))
    end
  end
end

memory.map_block = function(starting_high_byte, ending_high_byte, mapped_block, starting_address)
  if starting_high_byte > 0xFF or ending_high_byte > 0xFF then
    print("Bad block, bailing", starting_high_byte, ending_high_byte)
    return
  end

  starting_address = starting_address or bit32.lshift(starting_high_byte, 8)
  for i = starting_high_byte, ending_high_byte do
    block_map[bit32.lshift(i, 8)] = {start=starting_address, block=mapped_block}
  end
end

memory.generate_block = function(size)
  local block = {}
  for i = 0, size - 1 do
    block[i] = 0
  end
  return block
end

-- Main Memory
memory.work_ram_0 = memory.generate_block(4 * 1024)
memory.work_ram_1 = memory.generate_block(4 * 1024)
memory.map_block(0xC0, 0xCF, memory.work_ram_0)
memory.map_block(0xD0, 0xDF, memory.work_ram_1)

memory.work_ram_echo = {}
memory.work_ram_echo.mt = {}
memory.work_ram_echo.mt.__index = function(table, key)
  return memory.read_byte(key + 0xC000)
end
memory.work_ram_echo.mt.__newindex = function(table, key, value)
  memory.write_byte(key + 0xC000, value)
end
setmetatable(memory.work_ram_echo, memory.work_ram_echo.mt)
memory.map_block(0xE0, 0xFD, memory.work_ram_echo)

memory.read_byte = function(address)
  local high_byte = bit32.band(address, 0xFF00)
  if block_map[high_byte] then
    local adjusted_address = address - block_map[high_byte].start
    return block_map[high_byte].block[adjusted_address]
  end

  -- No mapped block for this memory exists! Return something sane-ish.
  -- TODO: Research what real hardware does on unmapped memory regions and
  -- do that here instead.
  return 0x00
end

memory.write_byte = function(address, byte)
  local high_byte = bit32.band(address, 0xFF00)
  if block_map[high_byte] then
    local adjusted_address = address - block_map[high_byte].start
    block_map[high_byte].block[adjusted_address] = byte
  end

  -- Note: If no memory is mapped to handle this write, DO NOTHING. (This is fine.)
end

memory.reset = function()
  -- It's tempting to want to zero out all 0x0000-0xFFFF, but
  -- instead here we'll reset only that memory which this module
  -- DIRECTLY controls, so initialization logic can be performed
  -- elsewhere as appropriate.

  for i = 0, #memory.work_ram_0 do
    memory.work_ram_0[i] = 0
  end

  for i = 0, #memory.work_ram_1 do
    memory.work_ram_1[i] = 0
  end
end

memory.save_state = function()
  local state = {}

  state.work_ram_0 = {}
  for i = 0, #memory.work_ram_0 do
    state.work_ram_0[i] = memory.work_ram_0[i]
  end

  state.work_ram_1 = {}
  for i = 0, #memory.work_ram_1 do
    state.work_ram_1[i] = memory.work_ram_1[i]
  end

  return state
end

memory.load_state = function(state)
  for i = 0, #memory.work_ram_0 do
    memory.work_ram_0[i] = state.work_ram_0[i]
  end
  for i = 0, #memory.work_ram_1 do
    memory.work_ram_1[i] = state.work_ram_1[i]
  end
end

-- Fancy: make access to ourselves act as an array, reading / writing memory using the above
-- logic. This should cause memory[address] to behave just as it would on hardware.
memory.mt = {}
memory.mt.__index = function(table, key)
  return memory.read_byte(key)
end
memory.mt.__newindex = function(table, key, value)
  memory.write_byte(key, value)
end
setmetatable(memory, memory.mt)

return memory
