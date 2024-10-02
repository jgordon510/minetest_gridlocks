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
    }
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
    }
}