package history

import "core:fmt"
printfln :: fmt.printfln
tprintf :: fmt.tprintf

import "core:math/rand"
import "core:strings"

SIM_YEARS :: 100

CivEventType :: enum
{ Famine, RulerDies }

CivEvent :: struct
{
	type   : CivEventType,
	year   : int,
	int1   : int,
	int2   : int,
}

event_description :: proc(ce:CivEvent) -> string
{
	switch ce.type {
		case .Famine: {
			return tprintf("Famine swept the land, killing %d people.", ce.int1)
		}
		case .RulerDies: {
			return tprintf("The ruler, %d, died age %d.", ce.int1, ce.int2)
		}
	}
	panic("unreachable")
}

Civilization :: struct
{
	population		: int,
	birth_rate		: f32,
	death_rate		: f32,
	event_history	: [SIM_YEARS][dynamic]CivEvent,
	ruler_idx		: int,
}

Character :: struct
{
	idx   : int,
	age   : int,
	alive : bool,
}

characters_global : [dynamic]Character

new_civ :: proc() -> Civilization
{
	pop_min :: 10000
	pop_max :: 50000
	init_pop := rand.int_range(pop_min, pop_max)

	ruler := Character { idx = len(characters_global), age = 21, alive = true }
	append(&characters_global, ruler)

	return {
		population = init_pop,
		birth_rate = 37.0/1000.0,
		death_rate = 37.0/1000.0,
		ruler_idx  = ruler.idx,
	}
}

civ_plus_1_year :: proc(c:^Civilization, year:int)
{
	if c.ruler_idx > 0
	{
		ruler := &characters_global[c.ruler_idx]
		assert(ruler.age < len(DEATH_RATE))
		death_prob := DEATH_RATE[ruler.age]
		roll := rand.float32()
		if roll < death_prob
		{
			event := CivEvent{type=.RulerDies, year=year, int1=ruler.idx, int2=ruler.age}
			append(&c.event_history[year], event)
			ruler.alive = false
			c.ruler_idx = 0
		}
	}

	dice_roll := rand.int_max(100)
	// 4% chance of famine
	if dice_roll < 4
	{
		pop_killed := int(rand.float32_range(0.05, 0.3) * f32(c.population))
		famine := CivEvent{type=.Famine, year=year, int1=pop_killed}
		append(&c.event_history[year], famine)
		c.population -= pop_killed
	}

	br_act := rand.float32_normal(c.birth_rate, 0.003)
	dr_act := rand.float32_normal(c.birth_rate, 0.003)
	c.population = int(f32(c.population)*(1+br_act-dr_act))
}

main :: proc()
{
	append(&characters_global, Character{}) // Null character
	civ := new_civ()

	printfln("Civ founded in year 0 with %d people, ruled by %d", civ.population, civ.ruler_idx)

	for year in 0..<SIM_YEARS {
		for &char in characters_global {
			if char.alive do char.age += 1
		}

		civ_plus_1_year(&civ, year)
		printfln("Year %d (%d):", year, civ.population)
		for event in civ.event_history[year] {
			printfln(" %v", event_description(event))
		}
	}
}
