-- Table mapping each board number to the corresponding sound file
local room_music = {
    [1] = {key = "cloud_8", gain = 0.5},
    [2] = {key = "planet_metal", gain = 0.5},
    [3] = {key = "el_grande_diamonte_del_mundo_profundo", gain = 0.6},
    [4] = {key = "three_chord_rock", gain = 0.5},
    [5] = {key = "lord_of_happy", gain = 0.2},
}
-- Variable to store the current sound handle
local current_handle = nil

-- Function to update room audio
local function update_room_audio(board_n)
    -- Stop the currently playing sound with a fade-out effect (if possible)
    if current_handle then
        minetest.sound_fade(current_handle, 0.5, 0.0) -- Adjust fade-out duration if needed
    end

    -- Get the sound for the new room
    local sound = room_music[board_n]
    if sound then
        -- Play the new sound on loop

        current_handle = minetest.sound_play( {
            name = sound.key,
            gain = sound.gain,
            loop = true,
        })
    end
end

-- Call this function whenever Gridlocks.board_n changes
minetest.after(3, function() 
    minetest.register_globalstep(function()
        local board_n = Gridlock.board_n
        if board_n ~= Gridlock.last_board_n then
            Gridlock.last_board_n = board_n
            update_room_audio(board_n)
        end
    end)
end)