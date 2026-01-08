package history

import "core:math/rand"
import "core:strings"

CivEventType :: enum
{ Famine, RulerDies }

CivEvent :: struct
{
	type   : CivEventType,
	year   : int,
	int1   : int,
	int2   : int,
}


civ_event_description :: proc(ce:CivEvent) -> string
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

new_civ :: proc() -> Civilization
{
	pop_min :: 10000
	pop_max :: 50000
	init_pop := rand.int_range(pop_min, pop_max)

	return {
		population = init_pop,
		birth_rate = 37.0/1000.0,
		death_rate = 37.0/1000.0,
	}
}

civ_plus_1_year :: proc(c:^Civilization, year:int)
{
	dice_roll := rand.int_max(100)
	// 4% chance of famine
	if dice_roll < 4
	{
		pop_killed := int(rand.float32_range(0.01, 0.05) * f32(c.population))
		famine := CivEvent{type=.Famine, year=year, int1=pop_killed}
		append(&c.event_history[year], famine)
		c.population -= pop_killed
	}

	br_act := rand.float32_normal(c.birth_rate, 0.003)
	dr_act := rand.float32_normal(c.birth_rate, 0.003)
	c.population = int(f32(c.population)*(1+br_act-dr_act))
}
