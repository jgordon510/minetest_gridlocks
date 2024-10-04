local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)
Gridlock.counters = {}
Gridlock.counters.x = nil
Gridlock.counters.y = nil
Gridlock.statements = {}
Gridlock.labels = false
Gridlock.board_n = 2
Gridlock.puzzle_n = 1
Gridlock.spawn_point = {x=-16, y=22, z=2}--{x=12, y=2, z=-3}
--45 blocks
--16 colors
--10 digits
--x, y (2)
--eq, gt, lt, gte, lte (5)
--or, and, not (3)
--+, -, *, /, % (5)
--abs1 => "abs(" (1)
-- ( , ) (2)
-- ~= (1)

Gridlock.blocks = {
    x = ' Gridlock.counters.x ',
    y = ' Gridlock.counters.y ',
    eq ='==',
    neq ='~=',
    gt = '>',
    lt ='<',
    gte = '>=',
    lte = '<=',
    _or = ' or ',
    _and = ' and ',
    _not = ' not ',
    _0 = '0',
    _1 = '1',
    _2 = '2',
    _3 = '3',
    _4 = '4',
    _5 = '5',
    _6 = '6',
    _7 = '7',
    _8 = '8',
    _9 = '9',
    add = '+',
    sub = '-',
    mul = '*',
    mod = '%',
    div = '/',
    abs = 'math.abs(',
    paren1 = '(',
    paren2 = ')'
}

Gridlock.display_labels = {
    x = 'x',
    y = 'y',
    eq ='==',
    neq ='~=',
    gt = '>',
    lt ='<',
    gte = '>=',
    lte = '<=',
    _or = 'or',
    _and = 'and',
    _not = 'not',
    _0 = '0',
    _1 = '1',
    _2 = '2',
    _3 = '3',
    _4 = '4',
    _5 = '5',
    _6 = '6',
    _7 = '7',
    _8 = '8',
    _9 = '9',
    add = '+',
    sub = '-',
    mul = '*',
    mod = '%',
    div = '/',
    abs = 'abs(',
    paren1 = '(',
    paren2 = ')'
}

Gridlock.load_order = {"x", "y", "_0", "_1","_2","_3","_4","_5","_6","_7","_8","_9", "add", "sub", "mul", "div", "eq", "neq" , "gt" , "lt" , "gte", "lte", "_or", "_and", "_not", "mod", "abs", "paren1", "paren2"}
Gridlock.boards = {
    {
        statements_pos = {x=-15, y=22, z=3},--{x = 14, y = 2, z = -5}, --add one to x
        board_pos = {x=-19, y=28, z=1}, --{x = 11, y=8, z = -1}, add 4 to y
        puzzle_pos = {x=-17, y=23, z=4}, --{x = 9, y=3, z = -3},
        puzzle_param2 = 1,
        size={w=3, h=3},
        tray_width = 3,
        max_statements = 5,
        border_node = "default:cobble"
    }, 
    {
        statements_pos = {x = -9, y = 29, z = 7},
        board_pos = {x = -18, y=37, z = 1},
        puzzle_pos = {x = -18, y=30, z = -3},
        puzzle_param2 = 0,
        size={w=5, h=5},
        tray_width = 9,
        max_statements = 6, --double check this and add top frame to window
        border_node = modname .. ":brick"
    },
    {
        statements_pos = {x = -3, y = 30, z = 32},
        board_pos = {x = -13, y=43, z = 25},
        puzzle_pos = {x = -13, y=31, z = 17},
        puzzle_param2 = 0,
        size={w=8, h=8},
        tray_width = 12,
        max_statements = 10, --double check this and add top frame to window
        border_node = modname .. ":brick"
    },
    --todo board 4 here
}

Gridlock.puzzles = {
    { --room 1 (basement 3x3)
        {
            "ccc",
            "ccc",
            "ccc"
        },
        {
            "288",
            "288",
            "288"
        },
        {
            "333",
            "3e3",
            "333"
        }
    },
    { --room 2 (bingo boards)
        {
            "99999",
            "99999",
            "ccccc",
            "99999",
            "99999",
        },
        {
            "23332",
            "22322",
            "22222",
            "22322",
            "23332"
        },
        {
            "d333d",
            "dd3dd",
            "ddddd",
            "dd3dd",
            "d333d"
        },
       
        {
            "07070",
            "70707",
            "07070",
            "70707",
            "07070"
        },
        {
            "66866",
            "68686",
            "86868",
            "68686",
            "86668"
            
        },
        {
            "03333",
            "30000",
            "03330",
            "00003",
            "33330"
        },
    },
    { --room 3
        { --3/1 frog green 3 gray 5 black 0
            "53335333",
            "53035303",
            "33333333",
            "30000000",
            "33333333",
            "33333333",
            "33333333",
            "33533353",
        },
        {--3/2 skull black 0 gray 5 white 7
            "77777777",
            "77777777",
            "77777777",
            "70777077",
            "77707777",
            "77777777",
            "57070755",
            "57070755",
        },
        {--3/3 snake green 3 black 0 red 8 lt gray 6
            "66666663",
            "63333333",
            "63666666",
            "63333366",
            "66666366",
            "03033366",
            "33366666",
            "86666666",
        },
        {--3/4 dorky duck brown 4 yellow 10 black 0 white 7 blue c 
            "44004ccc",
            "44444ccc",
            "44444ccc",
            "47070ccc",
            "47aaaaaa",
            "47accccc",
            "77aaaaaa",
            "777ccccc",
        },
        {--3/5 dude tan f  plum d  lt gray 6 black 0 brown 4 blue c green b 
            "cc4444cc",
            "cc4444cc",
            "44444444",
            "bbf0f0bb",
            "bbffffbb",
            "bb00000b",
            "bb0fff0b",
            "bbdd6dbb",
        },
        {--3/6 panda black 0 gray 5 white 7
            "00700777",
            "00700777",
            "77777777",
            "77777777",
            "07070000",
            "77770070",
            "00770070",
            "55550050",
        },
        {--3/7 cool duck black 0 gray 5 white 6 yellow 10
            "56666666",
            "55666666",
            "55666666",
            "50000000",
            "50060006",
            "aaaa6666",
            "55666666",
            "55666666",
        },
        {--3/8 ninja white 6 tan 15 red 8 gray 5 black 0
            "00000000",
            "88888888",
            "88888888",
            "60f60f08",
            "00000008",
            "00000008",
            "55555000",
            "55555000",
        },
    },
    {
        --arrow
        {
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
        },
        --heart
        {
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
        },
        --gem
        {
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
        },
        --key
        {
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
        },
        --sword
        {
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
        }
    }
}