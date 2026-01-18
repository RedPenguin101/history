package history

import "core:math/rand"
import "core:strings"

Civilization :: struct
{
	name            : string,
	ruler_house		: int,
	ruler_idx		: int,
}

new_civ :: proc(name:string, ruler_house, ruler_idx:int) -> int
{
	pop_min :: 10000
	pop_max :: 50000

	civ := Civilization {
		name = name,
		ruler_house = ruler_house,
		ruler_idx = ruler_idx,
	}

	idx := len(global.civs)
	append(&global.civs, civ)

	return idx
}
