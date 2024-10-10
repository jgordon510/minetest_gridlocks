--todo add parentheses and one more symbol or color to get to 9x5=45
local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)
local COLOR_INPUT_POS = { x = 1, y = -1, z = 0 }
assert(minetest.is_singleplayer(), "This game is intended for single player only!")
Gridlock = {}
dofile(modpath .. "/global.lua")
dofile(modpath .. "/music.lua")

local function isSamePos(pos1, pos2)
    return pos1.x == pos2.x and pos1.y == pos2.y and pos1.z == pos2.z
end
--used to set diplay fields for coordinate and token nodes
local function set_fields(pos, display_text)
    local meta = minetest.get_meta(pos)
    meta:set_string("display_text", display_text)
    meta:set_string("infotext", "\"" .. display_text .. "\"")
    display_api.update_entities(pos)
end

--removes statements from the wall display
local function clear_statements()
    local pos = Gridlock.boards[Gridlock.board_n].statements_pos
    local startY = pos.y + #Gridlock.statements
    for y, statement in pairs(Gridlock.statements) do
        for z = 0, Gridlock.boards[Gridlock.board_n].tray_width do
            local pos = { x = pos.x, y = startY - y, z = -z + pos.z }
            minetest.set_node(pos, { name = Gridlock.boards[Gridlock.board_n].border_node })
        end
    end
end

--show the previous statements composing the current image on the screen
--these are displayed along with the color of each statement on the back wall
local function update_statements()
    clear_statements()
    local pos = Gridlock.boards[Gridlock.board_n].statements_pos
    local startY = pos.y + #Gridlock.statements
    for y, statement in pairs(Gridlock.statements) do
        for z, blockName in pairs(statement) do
            local pos = { x = pos.x, y = startY - y, z = pos.z - z + 1 }
            local name = blockName
            local param2 = 0
            if z == 1 then
                name = name .. "_grid" --for the color
                param2 = 2
            else
                name = name .. "_statement"
                param2 = 1
            end
            minetest.set_node(pos, { name = name, param2 = param2 })
        end
    end
end

local function update_puzzle()
    local puzzle_pos = Gridlock.boards[Gridlock.board_n].puzzle_pos
    local param2 = Gridlock.boards[Gridlock.board_n].puzzle_param2
    if Gridlock.board_n < 3 then
        local name = modname .. ":puz_" .. Gridlock.board_n .. "_" .. Gridlock.puzzle_n
        minetest.set_node(puzzle_pos, { name = name, param2 = param2 })
    else
        local offsets = nil
        if Gridlock.board_n == 3 then
            offsets = {
                { x = 0, y = 0, z = 0 },
                { x = 0, y = 0, z = 1 },
                { x = 0, y = -1, z = 0 },
                { x = 0, y = -1, z = 1 },
            }
        else
            offsets = {
                { x = 0, y = 0, z = 0 },
                { x = 0, y = 0, z = -1 },
                { x = 0, y = -1, z = 0 },
                { x = 0, y = -1, z = -1 },
            }
        end

        for tile = 1, 4 do
            local name = modname .. ":puz_" .. Gridlock.board_n .. "_" .. Gridlock.puzzle_n .. "_" .. tile
            minetest.set_node(vector.add(puzzle_pos, offsets[tile]), { name = name, param2 = param2 })
        end
    end
end

--show/hide the coordinate labels on the board
local function update_labels()
    local size = Gridlock.boards[Gridlock.board_n].size
    local half_w = math.floor(size.w / 2)
    local half_h = math.floor(size.h / 2)
    local pos = Gridlock.boards[Gridlock.board_n].board_pos
    local start = { x = pos.x, y = pos.y - half_h, z = pos.z - half_w }
    for y = 1, size.h do
        for z = 1, size.w do
            local labelPos = { x = start.x, y = start.y - y, z = start.z + z }
            local label = ""
            if Gridlock.labels then
                label = z .. "," .. y
            end
            set_fields(labelPos, label)
        end
    end
end

--update the board with the new statement if valid
local function update_board(f, colorBlockName)
    local size = Gridlock.boards[Gridlock.board_n].size
    local half_w = math.floor(size.w / 2)
    local half_h = math.floor(size.h / 2)
    local pos = Gridlock.boards[Gridlock.board_n].board_pos
    local start = { x = pos.x, y = pos.y - half_h, z = pos.z - half_w }

    for y = 1, size.h do
        Gridlock.counters.y = y
        local line = ""
        for z = 1, size.w do
            local nodePos = { x = start.x, y = start.y - y, z = start.z + z }
            Gridlock.counters.x = z
            local node = minetest.get_node(nodePos)
            if f() then
                minetest.set_node(nodePos, { name = colorBlockName .. "_grid" })
            end
        end
    end
end

--called by the trigger block
--reads in the current statement from the block tray
local function read_from(pos, colorBlockName)
    local reading = true
    local z = pos.z + 1
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

        z = z + 1
        iters = iters + 1

        if node.name == "air" then --todo fixme
            reading = false
        else
            local name = string.gsub(node.name, modname .. ":", "")
            table.insert(stack, Gridlock.blocks[name])
            table.insert(block_names, node.name)
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
        z = z + 1
    end
    minetest.remove_node(vector.add(COLOR_INPUT_POS, pos))
    table.insert(Gridlock.statements, block_names)
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
            local pos = { x = start_pos.x, y = start_pos.y + y, z = start_pos.z - z }
            local node = minetest.get_node(pos)
            if node.name == Gridlock.boards[Gridlock.board_n].border_node then
                readingX = false
                if z == 0 then
                    readingY = false
                end
            else
                local name = string.gsub(node.name, "_grid", "")
                name = string.gsub(name, "_statement", "")

                table.insert(statement, name)
            end
            z = z + 1
        end
        if #statement > 0 then
            table.insert(Gridlock.statements, statement)
        end
        y = y + 1
    end
    if #Gridlock.statements == 0 then
        update_board(function() return true end, modname .. ":color_0")
    else
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
    local half_w = math.floor(size.w / 2)
    local half_h = math.floor(size.h / 2)
    local pos = Gridlock.boards[Gridlock.board_n].board_pos
    local start = { x = pos.x, y = pos.y - half_h, z = pos.z - half_w }
    for y = 1, size.h do
        Gridlock.counters.y = y
        local line = ""
        for z = 1, size.w do
            local nodePos = { x = start.x, y = start.y - y, z = start.z + z }
            Gridlock.counters.x = z
            local name = minetest.get_node(nodePos).name
            name = string.gsub(name, "color_", "")
            name = string.gsub(name, "_grid", "")
            name = string.gsub(name, "gridlock:", "")
            local char = chars[tonumber(name)]
            line = line .. char
        end

        local puzzleLine = Gridlock.puzzles[Gridlock.board_n][Gridlock.puzzle_n][y]
        if line ~= puzzleLine then return false end
    end
    return true
end

--opens the basement door after completing the 3x3, called by progress
local function open_basement_door()
    local pos = { x = -16, y = 22, z = -1 }
    minetest.swap_node(pos, { name = "xpanes:door_steel_bar_c", param2 = 3 })
    minetest.sound_play({ name = "xpanes_steel_bar_door_open", gain = 1 },
        { pos = pos }, true)
end

local function close_basement_door()
    local pos = { x = -16, y = 22, z = -1 }
    minetest.swap_node(pos, { name = "xpanes:door_steel_bar_a", param2 = 2 })
    minetest.sound_play({ name = "xpanes_steel_bar_door_close", gain = 1 },
        { pos = pos }, true)
end

local function open_5x5_door()
    local pos1 = { x = -12, y = 29, z = 9 }
    minetest.swap_node(pos1, { name = "doors:door_glass_c", param2 = 1 })
    local pos2 = { x = -11, y = 29, z = 9 }
    minetest.swap_node(pos2, { name = "doors:door_glass_c", param2 = 3 })
    minetest.sound_play({ name = "doors_glass_door_open", gain = 1 },
        { pos = pos1 }, true)
end

local function open_5x5_window()
    local start = { x = -9, y = 29, z = 7 }
    for y = 0, 5 do
        for z = 0, -10, -1 do
            local pos = vector.add(start, { x = 0, z = z, y = y })
            minetest.after(y * 0.5, function()
                minetest.set_node(pos, { name = "default:glass" })
            end)
        end
    end
end

local function close_5x5_door()
    local pos1 = { x = -12, y = 29, z = 9 }
    minetest.swap_node(pos1, { name = "doors:door_glass_a", param2 = 0 })
    local pos2 = { x = -11, y = 29, z = 9 }
    minetest.swap_node(pos2, { name = "doors:door_glass_b", param2 = 0 })
    minetest.sound_play({ name = "doors_glass_door_close", gain = 1 },
        { pos = pos1 }, true)
end

local function open_8x8_door()
    local pos1 = { x = -11, y = 29, z = 33 }
    local pos2 = { x = -10, y = 29, z = 33 }
    local above = { x = 0, y = 1, z = 0 }
    minetest.swap_node(vector.add(pos1, above), { name = "scifi_nodes:black_door_opened_top", param2 = 0 })
    minetest.swap_node(vector.add(pos2, above), { name = "scifi_nodes:black_door_opened_top", param2 = 2 })
    minetest.swap_node(pos1, { name = "scifi_nodes:black_door_opened", param2 = 0 })
    minetest.swap_node(pos2, { name = "scifi_nodes:black_door_opened", param2 = 2 })
    minetest.sound_play({ name = "scifi_nodes_door_normal", gain = 1 },
        { pos = pos1 }, true)
end

local function open_8x8_window()
    local start = { x = -3, y = 30, z = 31 }
    for y = 0, 9 do
        for z = 0, -13, -1 do
            local pos = vector.add(start, { x = 0, z = z, y = y })
            minetest.after(y * 0.5, function()
                minetest.set_node(pos, { name = "scifi_nodes:octgrn_pane", param2 = 1 })
            end)
        end
    end
end

local function close_8x8_door()
    local pos1 = { x = -11, y = 29, z = 33 }
    local pos2 = { x = -10, y = 29, z = 33 }
    local above = { x = 0, y = 1, z = 0 }
    minetest.swap_node(vector.add(pos1, above), { name = "scifi_nodes:black_door_closed_top", param2 = 0 })
    minetest.swap_node(vector.add(pos2, above), { name = "scifi_nodes:black_door_closed_top", param2 = 2 })
    minetest.swap_node(pos1, { name = "scifi_nodes:black_door_closed", param2 = 0 })
    minetest.swap_node(pos2, { name = "scifi_nodes:black_door_closed", param2 = 2 })
    minetest.sound_play({ name = "scifi_nodes_door_normal", gain = 1 },
        { pos = pos1 }, true)
end

local function open_final_door()
    local pos1 = { x = -20, y = 29, z = 14 }
    local pos2 = { x = -21, y = 29, z = 14 }

    local above = { x = 0, y = 1, z = 0 }
    minetest.swap_node(vector.add(pos1, above), { name = "scifi_nodes:white_door_opened_top", param2 = 2 })
    minetest.swap_node(vector.add(pos2, above), { name = "scifi_nodes:white_door_opened_top", param2 = 0 })
    minetest.swap_node(pos1, { name = "scifi_nodes:white_door_opened", param2 = 2 })
    minetest.swap_node(pos2, { name = "scifi_nodes:white_door_opened", param2 = 0 })
    minetest.sound_play({ name = "scifi_nodes_door_normal", gain = 1 },
        { pos = pos1 }, true)
end

local function close_final_door()
    local pos1 = { x = -20, y = 29, z = 14 }
    local pos2 = { x = -21, y = 29, z = 14 }
    local above = { x = 0, y = 1, z = 0 }
    minetest.swap_node(vector.add(pos1, above), { name = "scifi_nodes:white_door_closed_top", param2 = 2 })
    minetest.swap_node(vector.add(pos2, above), { name = "scifi_nodes:white_door_closed_top", param2 = 0 })
    minetest.swap_node(pos1, { name = "scifi_nodes:white_door_closed", param2 = 2 })
    minetest.swap_node(pos2, { name = "scifi_nodes:white_door_closed", param2 = 0 })
    minetest.sound_play({ name = "scifi_nodes_door_normal", gain = 1 },
        { pos = pos1 }, true)
end

local function endGame(name)
    -- Define your styled text
    local text1 = "<style size=30><b>Congratulations!</b></style>"
    local text2 =
    "<style size=20>You've completed all of the puzzles in the game! Thank you for playing, and please leave a review on the content database if you enjoyed playing the game!</style>"
    local text3 = "<style size=20>Press the button below to restart the game from the beginning!</style>"
    -- Combine the text using the hypertext element
    local hypertext = "hypertext[0.5,0.5;7,6;;" .. text1 .. "\n\n" .. text2 .. "\n\n" .. text3 .. "]"
    minetest.show_formspec(name, "gridlock:congrats",
        "size[8,8]" ..
        hypertext ..
        "button_exit[3,7;2,1;exit;Restart]")
end



--general player progression function
--called after a successful win_check
local function progress(player)
    clear_statements()
    Gridlock.statements = {}
    update_board(function() return true end, modname .. ":color_0")
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
        open_5x5_window()
    end
    if Gridlock.board_n == 3 and Gridlock.puzzle_n == 9 then
        Gridlock.board_n = 4
        Gridlock.puzzle_n = 1
        open_8x8_door()
        open_8x8_window()
    end
    if Gridlock.board_n == 4 and Gridlock.puzzle_n == 6 then
        Gridlock.board_n = 5
        endGame(player:get_player_name())
        return
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
    local aspect = 1
    if string.len(Gridlock.display_labels[key]) > 2 then
        aspect = 1 / 2
    end
    minetest.register_node(modname .. ":" .. key, {
        description = "gridlock block: " .. key,
        tiles = { blank, blank, blank, blank, blank, blank },
        inventory_image = fn,
        groups = { oddly_breakable_by_hand = 3, display_api = 1, not_in_creative_inventory = 1 },
        --paramtype2 = "facedir",
        on_place = function(itemstack, placer, pointed_thing)
            local pos = pointed_thing.above
            pos = { x = pos.x, y = pos.y - 1, z = pos.z }
            local node = minetest.get_node(pos)
            if node.name == modname .. ":tray" then
                display_api.on_place(itemstack, placer, pointed_thing)
            end
            return nil
        end,
        drop = {},

        display_entities = {
            [modname .. ":blockdisplay"] = {
                size = { x = 0.8, y = 0.8 },
                depth = 0,
                right = 0.5 + display_api.entity_spacing,
                top = 0,
                on_display_update = font_api.on_display_update,
                font_name = "botic",
                aspect_ratio = aspect,
                --top = 0,
                color = "#FFFFFF",
                yaw = math.pi / 2
            }
        },
        on_destruct = display_api.on_destruct,
        on_blast = display_api.on_blast,
        on_rotate = display_api.on_rotate,
        on_construct = function(pos)
            set_fields(pos, Gridlock.display_labels[key])
            display_api.on_construct(pos)
        end,
        on_receive_fields = set_fields,
    })
    --likewise, these blocks are used to make the statement blocks on the back wall
    minetest.register_node(modname .. ":" .. key .. "_statement", {
        description = "gridlock block: " .. key .. "(statement)",
        tiles = { blank },
        paramtype2 = "facedir",
        groups = { not_in_creative_inventory = 1 },
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
        on_construct = function(pos)
            set_fields(pos, Gridlock.display_labels[key])
            display_api.on_construct(pos)
        end,
        on_receive_fields = set_fields,
    })
end

--the trigger block commits a statement after the player has built it
minetest.register_node(modname .. ":trigger", {
    description = "gridlock block: trigger",
    tiles = { blank, blank, blank, blank, blank, "gridlock_trigger.png" },
    on_punch = function(pos, node, puncher, pointed_thing)
        if #Gridlock.statements >= Gridlock.boards[Gridlock.board_n].max_statements then
            return
        end
        local colorNode = minetest.get_node(vector.add(COLOR_INPUT_POS, pos))
        if string.match(colorNode.name, modname .. ":color") then
            read_from(pos, colorNode.name)
        end

        if win_check() then
            minetest.sound_play({ name = "gridlock_success", gain = 1 },
                { pos = pos }, true)
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
    tiles = { "gridlock_clear.png" },
    on_punch = function(pos, node, puncher, pointed_thing)
        clear_statements()
        Gridlock.statements = {}
        update_board(function() return true end, modname .. ":color_0")
    end,
})

--toggle the coordinate labels on and off
minetest.register_node(modname .. ":toggle_labels", {
    description = "gridlock block: toggle labels",
    tiles = { "gridlock_coords_toggle.png" },
    on_punch = function(pos, node, puncher, pointed_thing)
        Gridlock.labels = not Gridlock.labels
        update_labels()
    end,
})

--a basic gray brick for building
minetest.register_node(modname .. ":brick", {
    description = "gridlock block: brick",
    tiles = { blank, blank, blank, blank, blank, blank },
})

--the tray blocks are where token blocks can be placed
minetest.register_node(modname .. ":tray", {
    description = "gridlock block: tray",
    tiles = { blank, blank, blank, blank, blank, blank }
})

--the colortray accepts the color blocks for a statement
minetest.register_node(modname .. ":colortray", {
    description = "gridlock block: colortray",
    tiles = { "gridlock_colortray.png", blank, blank, blank, blank, blank },
})


--colors
display_api.register_display_entity(modname .. ":coordinates")
for i = 0, 15 do
    local fn = "gridlock_col" .. i .. ".png"
    --these are the statement color blocks that the user places on the tray
    minetest.register_node(modname .. ":color_" .. i, {
        description = "gridlock block: color " .. i,
        tiles = { blank, blank, fn, blank, blank, blank },
        inventory_image = fn,
        groups = { oddly_breakable_by_hand = 3, not_in_creative_inventory = 1 },
        on_place = function(itemstack, placer, pointed_thing)
            local pos = pointed_thing.above
            pos = { x = pos.x, y = pos.y - 1, z = pos.z }
            local node = minetest.get_node(pos)
            if node.name == modname .. ":colortray" then
                minetest.item_place(itemstack, placer, pointed_thing)
            end
            return nil
        end,
        drop = {},
    })
    --these are the colorblocks that are used on the grid itself
    minetest.register_node(modname .. ":color_" .. i .. "_grid", {
        description = "gridlock block: grid color " .. i,
        tiles = { blank, blank, fn, blank, blank, blank },
        groups = { not_in_creative_inventory = 1, display_api = 1 },
        paramtype2 = "facedir",
        display_entities = {
            [modname .. ":coordinates"] = {
                size = { x = 0.8, y = 0.6 },
                depth = 0,
                right = 0.5 + display_api.entity_spacing,
                top = 0,
                on_display_update = font_api.on_display_update,
                font_name = "botic",
                aspect_ratio = 0.6,
                --top = 0,
                color = "#FFFFFF",
                yaw = math.pi / 2
            }
        },
        on_place = display_api.on_place,
        on_destruct = display_api.on_destruct,
        on_blast = display_api.on_blast,
        on_rotate = display_api.on_rotate,
        on_construct = function(pos)
            set_fields(pos, "")
            display_api.on_construct(pos)
        end,
        on_receive_fields = set_fields
    })
end

--a staggered forcefield with 16 separate sheets
--the on_place function assists in putting them down
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
        tiles = { {
            name = modname .. "_field_" .. i .. ".png",
            animation = {
                type = "vertical_frames",
                aspect_w = 9,
                aspect_h = 9,
                length = 2,
            }
        } },
        -- on_place = function(itemstack, placer, pointed_thing)
        --     local n = 0
        --     local pos = table.copy(pointed_thing.above)

        --     while true do

        --         local index = (i + n) % 16
        --         if index == 0 then index = 1 end
        --         minetest.set_node(pos, {name=modname .. ":forcefield_" .. index})
        --         pos.x = pos.x+1
        --         local node = minetest.get_node(pos)
        --         if node.name == "scifi_nodes:white2" then
        --             return
        --         end
        --         n=n+1
        --     end
        -- end
    })
end

--these are displayed to the user as puzzles to solve
--in 16x16 they might be split into 4 cubes
local function register_puzzle_node(room, puzzle)
    local name = modname .. ":puz_" .. room .. "_" .. puzzle
    local blank = "gridlock_blank.png"
    if room == 1 then blank = "default_cobble.png" end
    local tiles = nil
    if room < 3 then
        local fn = modname .. "_puzzle_" .. room .. "_" .. puzzle .. ".png"
        if room == 1 then tiles = { blank, blank, fn, blank, blank, blank } end
        if room == 2 then tiles = { blank, blank, fn, blank, blank, blank } end
        minetest.register_node(name, {
            description = "gridlock block: puzzle_" .. room .. "_" .. puzzle,
            tiles = tiles,
            --groups = {not_in_creative_inventory = 1},
            paramtype2 = "facedir"
        })
    else
        for n = 1, 4 do
            local fn = modname .. "_puzzle_" .. room .. "_" .. puzzle .. "_" .. n .. ".png"
            if room == 3 then tiles = { blank, blank, fn, blank, blank, blank } end
            if room == 4 then tiles = { blank, blank, blank, fn, blank, blank } end
            minetest.register_node(name .. "_" .. n, {
                description = "gridlock block: puzzle_" .. room .. "_" .. puzzle .. "_" .. n,
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

--room 3 has 3 8x8 puzzles
for room = 3, 3 do
    for puzzle = 1, 8 do
        register_puzzle_node(room, puzzle)
    end
end

--room 4 has 5 16x16 puzzles
for room = 4, 4 do
    for puzzle = 1, 5 do
        register_puzzle_node(room, puzzle)
    end
end

local function spawn(player)
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
        minetest.sound_play({ name = "xpanes_steel_bar_door_close", gain = 0.5 }, { pos = player:get_pos() }, true)
    end)
end

minetest.register_on_newplayer(function(player)
    --the inventory is 9x5
    --this includes 29 token blocks...
    local inv = player:get_inventory()
    inv:set_size("main", 9 * 5)
    for _, key in pairs(Gridlock.load_order) do
        inv:add_item("main", ItemStack(modname .. ":" .. key))
    end
    --...and 16 color blocks
    for i = 0, 15 do
        inv:add_item("main", ItemStack(modname .. ":color_" .. i))
    end
    --spawn
    spawn(player)
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
    -- load the puzzle onto the wall
    update_puzzle()
    --this reads back in the statements off of the wall
    --it might be better to serialize that info, but oh well
    --todo reactivate
    minetest.after(1, read_in_statements)
end)

-- Register callback for endGame formspec
minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= "gridlock:congrats" then
        return false
    end
    --reset door flags
    local meta = player:get_meta()
    for i = 1, 5 do
        meta:set_int("flag" .. i, 0)
    end
    spawn(player)
    return true
end)

--a very basic inventory
local oldFormspec = sfinv.make_formspec
function sfinv.make_formspec(player, context, content, show_inv, size)
    local player_name = player:get_player_name()
    --give us the normal creative inventory
    if minetest.is_creative_enabled(player_name) then
        minetest.log("here!")
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

--prevent dropping of items
minetest.item_drop = function(itemstack, dropper, pos)
    return itemstack
end

--stop items from being diggable
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
        groups = {}
    })
end




minetest.register_globalstep(function(dtime)
    for _, player in ipairs(minetest.get_connected_players()) do
        local pos = vector.round(player:get_pos())
        -- Adjust the Y position slightly to get the node beneath the player
        local pos1 = { x = -16, y = 22, z = -2 } --basement door
        local pos2a = { x = -11, y = 29, z = 10 } --5x5 glass door 1
        local pos2b = { x = -12, y = 29, z = 10 } --5x5 glass door 2
        local pos3a = { x = -11, y = 29, z = 34 } --8x8 sliding door 1
        local pos3b = { x = -10, y = 29, z = 34 } --8x8 sliding door 2
        local pos4a = { x = -20, y = 29, z = 18 } --final sliding door open 2
        local pos4b = { x = -21, y = 29, z = 18 } --final sliding door open 2
        local pos5a = { x = -20, y = 29, z = 13 } --final sliding door close 2
        local pos5b = { x = -21, y = 29, z = 13 } --final sliding door close 2
        local meta = player:get_meta()

        --deal with progress flags and doors
        if isSamePos(pos, pos1) then --basement
            if meta:get_int("flag1") == 0 then
                meta:set_int("flag1", 1)
                close_basement_door()
            end
        end
        if isSamePos(pos, pos2a) or isSamePos(pos, pos2b) then --5x5
            if meta:get_int("flag2") == 0 then
                meta:set_int("flag2", 1)
                close_5x5_door()
            end
        end
        if isSamePos(pos, pos3a) or isSamePos(pos, pos3b) then --8x8
            if meta:get_int("flag3") == 0 then
                meta:set_int("flag3", 1)
                close_8x8_door()
            end
        end
        if isSamePos(pos, pos4a) or isSamePos(pos, pos4b) then --final open
            if meta:get_int("flag4") == 0 then
                meta:set_int("flag4", 1)
                open_final_door()
            end
        end
        if isSamePos(pos, pos5a) or isSamePos(pos, pos5b) then --final open
            if meta:get_int("flag5") == 0 then
                meta:set_int("flag5", 1)
                close_final_door()
            end
        end
    end
end)

--debug command for setting progress
minetest.register_chatcommand("gl-progress", {
    params = "gridlock",
    description = "Set your progress",
    privs = { server = true },
    func = function(name, param)
        local p = string.split(param, " ", false, 2, false)
        if #p == 2 then
            Gridlock.board_n = tonumber(p[1])
            Gridlock.puzzle_n = tonumber(p[2])
            progress(minetest.get_player_by_name(name))
            return true, "Progression set!"
        else
            return false, "Usage: /gl-progress board_n puzzle_n"
        end
    end
})

minetest.register_chatcommand("gl-clear", {
    params = "gridlock",
    description = "clear force fields",
    privs = { server = true },
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        minetest.log(dump(player))
        local pos      = player.get_pos(player)
        local pos1     = vector.add(pos, { x = -25, y = -25, z = -25 })
        local pos2     = vector.add(pos, { x = 25, y = 25, z = 25 })
        local vm       = minetest.get_voxel_manip()
        local min, max = vm:read_from_map(pos1, pos2)
        local data     = vm:get_data()
        local ids      = {}
        local a        = VoxelArea:new {
            MinEdge = min,
            MaxEdge = max
        }
        local c_air    = minetest.get_content_id("air")
        for i = 1, 16 do
            ids[minetest.get_content_id(modname .. ":forcefield_" .. i)] = true
        end
        for z = min.z, max.z do
            for y = min.y, max.y do
                for x = min.x, max.x do
                    local vi = a:index(x, y, z)
                    if ids[data[vi]] then
                        data[vi] = c_air
                    end
                end
            end
        end
        vm:set_data(data)
        vm:write_to_map(true)
    end
})

minetest.register_chatcommand("gl-place", {
    params = "gridlock",
    description = "place force fields",
    privs = { server = true },
    func = function(name, param)
        local x = -29
        local y = 47
        local n = 2
        for z = -8, 12 do
            for lift = 0, 9 do
                local pos = { x = x + lift, y = y, z = z }
                local i = n + lift
                if i > 16 then
                    i = i - 16
                end
                local name = modname .. ":forcefield_" .. i
                minetest.set_node(pos, { name = name })
            end
            n = n + 1
            if n > 16 then
                n = 1
            end
        end
    end
})
