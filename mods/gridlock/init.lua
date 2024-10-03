--todo add parentheses and one more symbol or color to get to 9x5=45
local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)
local COLOR_INPUT_POS =  {x=1, y=-1, z=0}

Gridlock = {}
dofile(modpath .. "/global.lua")

local function isSamePos(pos1, pos2)
    return pos1.x == pos2.x and pos1.y == pos2.y and pos1.z == pos2.z
end
--used to set diplay fields for coordinate and token nodes
local function set_fields(pos,  display_text )
	local meta = minetest.get_meta(pos)
	meta:set_string("display_text", display_text)
	meta:set_string("infotext", "\""..display_text.."\"")
	display_api.update_entities(pos)
end

--removes statements from the wall display
local function clear_statements()
    local pos = Gridlock.boards[Gridlock.board_n].statements_pos
    local startY = pos.y + #Gridlock.statements
    for y, statement in pairs(Gridlock.statements) do
        for z = 0, Gridlock.boards[Gridlock.board_n].tray_width do
            local pos = {x = pos.x, y=startY-y, z=-z+pos.z}
            minetest.set_node(pos, {name=Gridlock.boards[Gridlock.board_n].border_node})
        end
    end
end

--show the previous statements composing the current image on the screen
--these are displayed along with the color of each statement on the back wall
local function update_statements()
    clear_statements()
    minetest.log("updating statements...")
    local pos = Gridlock.boards[Gridlock.board_n].statements_pos
    local startY = pos.y + #Gridlock.statements
    for y, statement in pairs(Gridlock.statements) do
        for z, blockName in pairs(statement) do
            local pos = {x = pos.x, y=startY-y, z=pos.z-z+1}
            local name = blockName
            local param2 = 0
            if z == 1 then
                name = name .. "_grid"  --for the color
                param2 = 2
            else
                name = name .. "_statement"
                param2 = 1
            end
            minetest.log(name)
            minetest.set_node(pos, {name=name, param2 = param2})
        end
    end
end

local function update_puzzle()
    local puzzle_pos = Gridlock.boards[Gridlock.board_n].puzzle_pos
    local param2 = Gridlock.boards[Gridlock.board_n].puzzle_param2
    if Gridlock.board_n < 3 then
        local name =  modname .. ":puz_" .. Gridlock.board_n .. "_" .. Gridlock.puzzle_n
        minetest.set_node(puzzle_pos, {name=name, param2 = param2})
    else
        local offsets = {
            {x=0, y=0, z=0},
            {x=0, y=0, z=1},
            {x=0, y=-1, z=0},
            {x=0, y=-1, z=1},
        }
        for tile = 1, 4 do
            local name =  modname .. ":puz_" .. Gridlock.board_n .. "_" .. Gridlock.puzzle_n .. "_" .. tile
            minetest.set_node(vector.add(puzzle_pos, offsets[tile]), {name=name, param2 = param2})
        end
    end
    
end

--show/hide the coordinate labels on the board
local function update_labels()
    local size = Gridlock.boards[Gridlock.board_n].size
    local half_w = math.floor(size.w/2)
    local half_h = math.floor(size.h/2)
    local pos = Gridlock.boards[Gridlock.board_n].board_pos
    local start = {x=pos.x , y=pos.y - half_h, z=pos.z- half_w}
    for y = 1, size.h do
        for z = 1, size.w do
            local labelPos = {x=start.x  , y = start.y-y, z=start.z + z}
            local label = ""
            if Gridlock.labels then
                label = z ..",".. y
            end
            set_fields(labelPos, label)
        end
    end
end

--update the board with the new statement if valid
local function update_board(f, colorBlockName)
    local size = Gridlock.boards[Gridlock.board_n].size
    local half_w = math.floor(size.w/2)
    local half_h = math.floor(size.h/2)
    local pos = Gridlock.boards[Gridlock.board_n].board_pos
    local start = {x=pos.x , y=pos.y - half_h, z=pos.z- half_w}

    for y = 1, size.h do
        Gridlock.counters.y = y
        local line = ""
        for z = 1, size.w do
            local nodePos = {x=start.x , y = start.y-y, z=start.z + z}
            Gridlock.counters.x = z
            local node = minetest.get_node(nodePos)
            -- minetest.log(node.name)
            if f() then
                minetest.set_node(nodePos, {name=colorBlockName .. "_grid"})
            end
        end
    end
end

--called by the trigger block
--reads in the current statement from the block tray
local function read_from(pos, colorBlockName)
    minetest.log("read")
    local reading = true
    local z = pos.z+1
    local iters = 0
    local stack = {}
    table.insert(stack, "return ")
    local block_names = {}
    table.insert(block_names, colorBlockName)
    while reading and iters < Gridlock.boards[Gridlock.board_n].tray_width do
        
        local read = {
            x = pos.x,
            y = pos.y,
            z = z
        }
        local node = minetest.get_node(read)
        
        z=z+1
        iters= iters+1
        
        if node.name == "air" then --todo fixme
            reading = false
        else
            local name = string.gsub(node.name, modname..":", "")
            table.insert(stack, Gridlock.blocks[name])
            table.insert(block_names, node.name)
            -- minetest.log(node.name)
        end
    end
    if #block_names <= 1 then
        return
    end
   
    local statement = table.concat(stack)
    local f = loadstring(statement)
    if f == nil then
        return
    end
    z = z - iters
    for i = 1, iters do
        local read = {
            x = pos.x,
            y = pos.y,
            z = z
        }
        local node = minetest.get_node(read)
        minetest.remove_node(read)
        z = z+1
    end
    minetest.remove_node(vector.add(COLOR_INPUT_POS, pos))
    table.insert(Gridlock.statements, block_names)
    -- minetest.log(dump(Gridlock.statements))
    update_statements()
    update_board(f, colorBlockName)
end

--reads in the existing statements from the back wall
--these could probably be serialized but they're not
local function read_in_statements()
    local y = 0
    local readingY = true
    local start_pos = Gridlock.boards[Gridlock.board_n].statements_pos
    while readingY and y < Gridlock.boards[Gridlock.board_n].max_statements do
        local statement = {}
        local z = 0
        local readingX = true
        while readingX and z < 10 do
            local pos = {x = start_pos.x, y=start_pos.y+y, z=start_pos.z-z}
            local node = minetest.get_node(pos)
            if node.name == Gridlock.boards[Gridlock.board_n].border_node then 
                readingX = false
                if z == 0 then
                    readingY = false
                end
            else
                local name = string.gsub(node.name, "_grid", "")
                name = string.gsub(name, "_statement", "")
 
                table.insert(statement,name)
                -- minetest.log(name)
            end
            z = z + 1
        end
        if #statement > 0 then
            table.insert(Gridlock.statements, statement)
        end
        y = y+1
    end
    if #Gridlock.statements == 0 then
        update_board(function() return true end , modname .. ":color_0")
    else
        minetest.log(dump(Gridlock.statements))
    end
end

--checks if the puzzle matches the solution
local function win_check()
    local chars = {}
    chars[0] = "0"
    chars[1] = "1"
    chars[2] = "2"
    chars[3] = "3"
    chars[4] = "4"
    chars[5] = "5"
    chars[6] = "6"
    chars[7] = "7"
    chars[8] = "8"
    chars[9] = "9"
    chars[10] = "a"
    chars[11] = "b"
    chars[12] = "c"
    chars[13] = "d"
    chars[14] = "e"
    chars[15] = "f"
    local size = Gridlock.boards[Gridlock.board_n].size
    local half_w = math.floor(size.w/2)
    local half_h = math.floor(size.h/2)
    local pos = Gridlock.boards[Gridlock.board_n].board_pos
    local start = {x=pos.x , y=pos.y - half_h, z=pos.z- half_w}
    for y = 1, size.h do
        Gridlock.counters.y = y
        local line = ""
        for z = 1, size.w do
            local nodePos = {x=start.x  , y = start.y-y, z=start.z + z}
            Gridlock.counters.x = z
            local name = minetest.get_node(nodePos).name
            name = string.gsub(name, "color_", "")
            name = string.gsub(name, "_grid", "")
            name = string.gsub(name, "gridlock:", "")
            local char = chars[tonumber(name)]
            line = line .. char
        end
        
        local puzzleLine = Gridlock.puzzles[Gridlock.board_n][Gridlock.puzzle_n][y]
        --minetest.log("puzzle: " .. puzzleLine)
        --minetest.log("line:   " .. line)
        if line ~= puzzleLine then return false end
    end
    return true
end

--opens the basement door after completing the 3x3, called by progress
local function open_basement_door()
    minetest.log("opening basement door!")
    local pos = {x = -16, y = 22, z = -1}
    minetest.swap_node(pos, {name="xpanes:door_steel_bar_c", param2=3})
    minetest.sound_play({name = "xpanes_steel_bar_door_open", gain = 1},
			{pos = pos}, true)
end

local function close_basement_door()
    minetest.log("closing basement door!")
    local pos = {x = -16, y = 22, z = -1}
    minetest.swap_node(pos, {name="xpanes:door_steel_bar_a", param2=2})
    minetest.sound_play({name = "xpanes_steel_bar_door_close", gain = 1},
			{pos = pos}, true)
end

local function open_5x5_door()
    minetest.log("opening 5x5 door!")
    local pos1 = {x = -12, y = 29, z = 9}
    minetest.swap_node(pos1, {name="doors:door_glass_c", param2=1})
    local pos2 = {x = -11, y = 29, z = 9}
    minetest.swap_node(pos2, {name="doors:door_glass_c", param2=3})
    minetest.sound_play({name = "doors_glass_door_open", gain = 1},
			{pos = pos1}, true)
end

local function close_5x5_door()
    minetest.log("closing 5x5 door!")
    local pos1 = {x = -12, y = 29, z = 9}
    minetest.swap_node(pos1, {name="doors:door_glass_a", param2=0})
    local pos2 = {x = -11, y = 29, z = 9}
    minetest.swap_node(pos2, {name="doors:door_glass_b", param2=0})
    minetest.sound_play({name = "doors_glass_door_close", gain = 1},
			{pos = pos1}, true)
end

local function open_8x8_door()
    minetest.log("opening 8x8 door!")
    local pos1 = {x = -12, y = 29, z = 9}
    minetest.swap_node(pos1, {name="doors:door_glass_c", param2=1})
    local pos2 = {x = -11, y = 29, z = 9}
    minetest.swap_node(pos2, {name="doors:door_glass_c", param2=3})
    minetest.sound_play({name = "doors_glass_door_open", gain = 1},
			{pos = pos1}, true)
end

--general player progression function
--called after a successful win_check
local function progress(player)
    clear_statements()
    Gridlock.statements = {}
    update_board(function() return true end , modname .. ":color_0")
    Gridlock.puzzle_n = Gridlock.puzzle_n + 1
    if Gridlock.board_n == 1 and Gridlock.puzzle_n == 4 then
        Gridlock.board_n = 2
        Gridlock.puzzle_n = 1
        open_basement_door()
    end
    if Gridlock.board_n == 2 and Gridlock.puzzle_n == 7 then
        Gridlock.board_n = 3
        Gridlock.puzzle_n = 1
        open_5x5_door()
    end
    if Gridlock.board_n == 3 and Gridlock.puzzle_n == 9 then
        Gridlock.board_n = 4
        Gridlock.puzzle_n = 1
        open_8x8_door()
    end
    
    update_puzzle()
    local meta = player:get_meta()
    
    meta:set_int("board_n", Gridlock.board_n)
    meta:set_int("puzzle_n", Gridlock.puzzle_n)
end

--the "tokens" or blocks that make up a statement (numbers, x, y, operators, etc.)
display_api.register_display_entity(modname .. ":blockdisplay")
local blank = "gridlock_blank.png"
for key, value in pairs(Gridlock.blocks) do
    local fn = "gridlock_" .. key .. ".png"
    local aspect =  1
    if string.len(Gridlock.display_labels[key]) > 2 then
        aspect = 1/2
    end
    minetest.register_node(modname .. ":" .. key, {
        description = "gridlock block: " .. key,
        tiles = {blank, blank, blank, blank, blank, blank },
        inventory_image = fn,
        groups = {oddly_breakable_by_hand = 3, display_api = 1, not_in_creative_inventory = 1},
        --paramtype2 = "facedir",
        on_place = function(itemstack, placer, pointed_thing)
            local pos = pointed_thing.above
            pos = {x=pos.x, y=pos.y-1, z=pos.z}
            local node = minetest.get_node(pos)
            if node.name == modname .. ":tray" then
                display_api.on_place(itemstack, placer, pointed_thing)
            end
            return nil
        end,
        drop={},
        
        display_entities = {
            [modname .. ":blockdisplay"] = {
                size = { x = 0.8, y = 0.8 },
                depth = 0,
                right = 0.5 +  display_api.entity_spacing,
                top = 0,
                on_display_update = font_api.on_display_update,
                font_name = "botic",
                aspect_ratio = aspect,
                --top = 0,
                color = "#FFFFFF",
                yaw = math.pi/2
            }
        },
        on_destruct = display_api.on_destruct,
        on_blast = display_api.on_blast,
        on_rotate = display_api.on_rotate,
        on_construct = 	function(pos)
            set_fields(pos, Gridlock.display_labels[key])
            display_api.on_construct(pos)
        end,
        on_receive_fields = set_fields,
    })
    --likewise, these blocks are used to make the statement blocks on the back wall
    minetest.register_node(modname .. ":" .. key .. "_statement", {
        description = "gridlock block: " .. key .. "(statement)" ,
        tiles = {blank },
        paramtype2 = "facedir",
        groups = {not_in_creative_inventory = 1},
        display_entities = {
            [modname .. ":blockdisplay"] = {
                size = { x = 0.8, y = 0.8 },
                depth = -0.5 - display_api.entity_spacing,
                on_display_update = font_api.on_display_update,
                font_name = "botic",
                aspect_ratio = aspect,
                top = 0,
                color = "#FFFFFF",
            }
        },
        on_destruct = display_api.on_destruct,
        on_blast = display_api.on_blast,
        on_rotate = display_api.on_rotate,
        on_construct = 	function(pos)
            set_fields(pos, Gridlock.display_labels[key])
            display_api.on_construct(pos)
        end,
        on_receive_fields = set_fields,
    })
end

--the trigger block commits a statement after the player has built it
minetest.register_node(modname .. ":trigger", {
    description = "gridlock block: trigger",
    tiles = {blank, blank, blank, blank, blank, "gridlock_trigger.png" },
    --groups = {oddly_breakable_by_hand = 3},
    on_punch = function(pos, node, puncher, pointed_thing)
        if #Gridlock.statements >= Gridlock.boards[Gridlock.board_n].max_statements then
            return
        end
        local colorNode= minetest.get_node(vector.add(COLOR_INPUT_POS, pos))
        if string.match(colorNode.name, modname .. ":color") then
            read_from(pos, colorNode.name)
        end
        
        if win_check() then
            minetest.sound_play({name = "gridlock_success", gain = 1},
			{pos = pos}, true)
            minetest.after(2, progress, puncher)
        end
    end,
    paramtype2 = "facedir",
    on_place = function(itemstack, placer, pointed_thing)		
		local param2 = minetest.dir_to_facedir(placer:get_look_dir())
			
		minetest.item_place(itemstack, placer, pointed_thing, param2)	
	end
})

--the clear block resets the puzzle
minetest.register_node(modname .. ":clear", {
    description = "gridlock block: clear",
    tiles = {"gridlock_clear.png" },
   --groups = {oddly_breakable_by_hand = 3},
    on_punch = function(pos, node, puncher, pointed_thing)
        clear_statements()
        Gridlock.statements = {}
        update_board(function() return true end , modname .. ":color_0")
    end,
  --  light_source = 3,
})

--toggle the coordinate labels on and off
minetest.register_node(modname .. ":toggle_labels", {
    description = "gridlock block: toggle labels",
    tiles = {"gridlock_coords_toggle.png" },
   --groups = {oddly_breakable_by_hand = 3},
    on_punch = function(pos, node, puncher, pointed_thing)
        Gridlock.labels = not Gridlock.labels
        update_labels()
        
    end,
})

--a basic gray brick for building
minetest.register_node(modname .. ":brick", {
    description = "gridlock block: brick",
   -- groups = {oddly_breakable_by_hand = 3},
    tiles = {blank, blank, blank, blank, blank, blank },
})

--the tray blocks are where token blocks can be placed
minetest.register_node(modname .. ":tray", {
    description = "gridlock block: tray",
    --groups = {oddly_breakable_by_hand = 3},
    tiles = {blank, blank, blank, blank, blank, blank }
})

--the colortray accepts the color blocks for a statement
minetest.register_node(modname .. ":colortray", {
    description = "gridlock block: colortray",
    --groups = {oddly_breakable_by_hand = 3},
    tiles = {"gridlock_colortray.png", blank, blank, blank, blank, blank },
})


--colors
display_api.register_display_entity(modname .. ":coordinates")
for i = 0, 15 do
    local fn = "gridlock_col" .. i .. ".png"
    --these are the statement color blocks that the user places on the tray
    minetest.register_node(modname .. ":color_" .. i, {
        description = "gridlock block: color " .. i,
        tiles = {blank, blank, fn, blank, blank, blank },
        inventory_image = fn,
        groups = {oddly_breakable_by_hand = 3, not_in_creative_inventory = 1},
        on_place = function(itemstack, placer, pointed_thing)
            local pos = pointed_thing.above
            pos = {x=pos.x, y=pos.y-1, z=pos.z}
            local node = minetest.get_node(pos)
            if node.name == modname .. ":colortray" then
                minetest.item_place(itemstack, placer, pointed_thing)	
                -- return itemstack
            end
            return nil
        end,
        drop={},
        
       -- light_source = 3,
    })
    --these are the colorblocks that are used on the grid itself
    minetest.register_node(modname .. ":color_" .. i .. "_grid", {
        description = "gridlock block: grid color " .. i,
        tiles = {blank, blank, fn, blank, blank, blank },
        groups = {not_in_creative_inventory = 1, display_api = 1 },
        paramtype2 = "facedir",
        display_entities = {
            [modname .. ":coordinates"] = {
                size = { x = 0.8, y = 0.6 },
                depth = 0,
                right = 0.5 +  display_api.entity_spacing,
                top = 0,
                on_display_update = font_api.on_display_update,
                font_name = "botic",
                aspect_ratio = 0.6,
                --top = 0,
                color = "#FFFFFF",
                yaw = math.pi/2
            }
        },
        on_punch = function(pos, node, puncher, pointed_thing)
            -- minetest.log(dump(pos))
            -- display_api.update_entities()
        end,
        on_place = display_api.on_place,
        on_destruct = display_api.on_destruct,
        on_blast = display_api.on_blast,
        on_rotate = display_api.on_rotate,
        on_construct = 	function(pos)
            set_fields(pos, "")
            --update_labels()
            display_api.on_construct(pos)
        end,
        on_receive_fields = set_fields
        --  light_source = 3,
        })
end


for i = 1, 16 do
    minetest.register_node(modname .. ":forcefield_" .. i, {
        description = "Forcefield " .. i,
        sunlight_propagates = true,
        drawtype = "glasslike",
        groups = {
            cracky = 1,
            level = 3
        },
        is_ground_content = false,
        paramtype = "light",
        light_source = minetest.LIGHT_MAX,
        tiles = {{
            name = modname .. "_field_".. i ..".png",
            animation = {
                type = "vertical_frames",
                aspect_w = 9,
                aspect_h = 9,
                length = 2,
            }
        }},
        on_place =function(itemstack, placer, pointed_thing) 
            minetest.log(dump(pointed_thing))
            local n = 0
            local pos = table.copy(pointed_thing.above)
            
            while true do
                
                local index = (i + n) % 16
                minetest.log(index)
                if index == 0 then index = 1 end
                minetest.set_node(pos, {name=modname .. ":forcefield_" .. index})
                pos.x = pos.x+1
                local node = minetest.get_node(pos)
                if node.name == "scifi_nodes:white2" then
                    return
                end
                n=n+1
            end
        end
    }) 
end

--deprecated coordinates causes an error in the lab mod
--a new map should remove this requirement
for y = 1, 5 do
    for x = 1, 5 do
        local fn = "gridlock_coord_" .. ((y-1)*5 + (x)) .. ".png"
        minetest.register_node(modname .. ":coord_" .. x .. '_' .. y, {
            
        })
    end
end

--these are displayed to the user as puzzles to solve
--in 16x16 they might be split into 4 cubes
function register_puzzle_node(room, puzzle) 
    local name = modname .. ":puz_" .. room .. "_" .. puzzle
    
    local blank = "gridlock_blank.png"
    if room == 1 then blank = "default_cobble.png" end
    local tiles = nil
    
    if room < 3 then 
        local fn =  modname .. "_puzzle_" .. room .. "_" .. puzzle .. ".png"
        if room == 1 then tiles = {blank, blank, fn, blank, blank, blank } end
        if room == 2 then tiles = {blank, blank, fn, blank, blank, blank } end
        minetest.register_node(name, {
            description = "gridlock block: puzzle_".. room .. "_" .. puzzle,
            tiles = tiles,
            --groups = {not_in_creative_inventory = 1},
            paramtype2 = "facedir"
        })
    else
        for n = 1, 4 do
            local fn =  modname .. "_puzzle_" .. room .. "_" .. puzzle ..  "_" .. n ..".png"
            if room == 3 then tiles = {blank, blank, fn, blank, blank, blank } end
            minetest.register_node(name .. "_" .. n, {
                description = "gridlock block: puzzle_".. room .. "_" .. puzzle .. "_" .. n,
                tiles = tiles,
                --groups = {not_in_creative_inventory = 1},
                paramtype2 = "facedir"
            })
        end
    end

    
end

--room 1 has 3 3x3 puzzles
for room = 1, 1 do
    for puzzle = 1, 3 do
        register_puzzle_node(room, puzzle)
    end
end

--room 2 has 6 5x5 puzzles
for room = 2, 2 do
    for puzzle = 1, 6 do
        register_puzzle_node(room, puzzle)
    end
    
end

for room = 3, 3 do
    for puzzle = 1, 8 do
        register_puzzle_node(room, puzzle)
    end
end


minetest.register_on_newplayer(function(player)
    --the inventory is 9x5
    --this includes 29 token blocks...
    local inv = player:get_inventory()
    inv:set_size("main", 9*5)
    for _, key in pairs(Gridlock.load_order) do
        if key ~= "abs2" then
            inv:add_item("main", ItemStack(modname .. ":" .. key ))
        end
    end
    --...and 16 color blocks
    for i = 0, 15 do
        inv:add_item("main", ItemStack(modname .. ":color_" .. i ))
    end
    --spawn
    player:set_pos(Gridlock.spawn_point)
    local meta = player:get_meta()
    --progression
    Gridlock.board_n = 1
    Gridlock.puzzle_n = 1
    meta:set_int("board_n", Gridlock.board_n)
    meta:set_int("puzzle_n", Gridlock.puzzle_n)
    Gridlock.statements = {}

    minetest.after(1, function()
        --load the puzzle onto the wall and slam the door (noise)

        update_puzzle()
        minetest.sound_play({name = "xpanes_steel_bar_door_close", gain = 0.5},{pos = puzzle_pos}, true)
    end)
end)

minetest.register_on_joinplayer(function(player)
    --setup hud
    minetest.after(0, player.hud_set_hotbar_itemcount, player, 18)
    minetest.after(0, function() 
        player:hud_set_hotbar_image("gridlock_gui_hotbar.png")
    end)
    --get previous progress
    local meta = player:get_meta()
    Gridlock.board_n = meta:get_int("board_n")
    Gridlock.puzzle_n = meta:get_int("puzzle_n")
    if Gridlock.board_n == 0 then
        Gridlock.board_n = 1
    end
    if Gridlock.puzzle_n == 0 then
        Gridlock.puzzle_n = 1
    end
    -- minetest.log("board_n:" .. Gridlock.board_n)
    -- minetest.log("puzzle:" .. Gridlock.puzzle_n)
    -- load the puzzle onto the wall
    update_puzzle()
    --this reads back in the statements off of the wall
    --it might be better to serialize that info, but oh well
    --todo reactivate
    minetest.after(1, read_in_statements)
    
end)

--a very basic inventory 
local oldFormspec = sfinv.make_formspec
function sfinv.make_formspec(player, context, content, show_inv, size)
    local player_name = player:get_player_name()
    if minetest.is_creative_enabled(player_name) then
        return oldFormspec(player, context, content, show_inv, size)
    else
        local formspec = {
            "size[9,5]",
            default.gui_bg,
            default.gui_bg_img,
            default.gui_slots,
            "list[current_player;main;0,0;9,5;]",
        }
        return table.concat(formspec, "")
    end
    
end

minetest.item_drop = function(itemstack, dropper, pos)
    return itemstack
end

local no_digs = {
    "xpanes:pane_flat",
    "default:torch_wall",
    "doors:door_glass_a",
    "doors:door_glass_b",
    "doors:door_glass_c",
    "doors:door_glass_d",
    "default:wood",
    "scifi_nodes:octgrn_pane",
    "scifi_nodes:black_door_closed",
    "scifi_nodes:white_door_closed",
}
for _, name in pairs(no_digs) do
    minetest.override_item(name, {
        groups={}
    })
end




minetest.register_globalstep(function(dtime)
    for _, player in ipairs(minetest.get_connected_players()) do
        local pos = vector.round(player:get_pos())
        -- Adjust the Y position slightly to get the node beneath the player
        local pos1 = {x = -16, y=22, z=-2} --basement door
        local pos2a = {x = -11, y=29, z=10} --5x5 glass door 1
        local pos2b = {x = -12, y=29, z=10} --5x5 glass door 2
        local pos3a = {x = -11, y=29, z=33} --8x8 sliding door 1
        local pos3b = {x = -10, y=29, z=33} --8x8 sliding door 2
        if isSamePos(pos, pos1) then --basement
            if not Gridlock.flag1 then
                Gridlock.flag1 = true
                close_basement_door()
            end
        end
        if isSamePos(pos, pos2a) or isSamePos(pos, pos2b) then --5x5
            if not Gridlock.flag2 then
                Gridlock.flag2 = true
                close_5x5_door()
            end
        end
        if isSamePos(pos, pos3a) or isSamePos(pos, pos3b) then --8x8
            if not Gridlock.flag3 then
                Gridlock.flag3 = true
                --close_8x8_door()
            end
        end
    end
end)