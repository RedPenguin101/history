package history

import "core:fmt"
printfln :: fmt.printfln
tprintf :: fmt.tprintf

import "core:math/rand"
import "core:strings"

SIM_YEARS :: 100

CivEventType :: enum
{ Famine }

CivEvent :: struct
{
	type   : CivEventType,
	year   : int,
	int1   : int,
}

event_description :: proc(ce:CivEvent) -> string {
	switch ce.type {
		case .Famine: {
			return tprintf("Famine swept the land, killing %d people.", ce.int1)
		}
	}
	panic("unreachable")
}

Civilization :: struct
{
	population  : int,
	birth_rate	: f32,
	death_rate	: f32,
	event_history : [SIM_YEARS][dynamic]CivEvent,
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
	if dice_roll < 4 {
		pop_killed := int(rand.float32_range(0.05, 0.3) * f32(c.population))
		famine := CivEvent{.Famine, year, pop_killed}
		append(&c.event_history[year], famine)
		c.population -= pop_killed
	}

	br_act := rand.float32_normal(c.birth_rate, 0.003)
	dr_act := rand.float32_normal(c.birth_rate, 0.003)
	c.population = int(f32(c.population)*(1+br_act-dr_act))
}

main :: proc()
{
	civ := new_civ()

	printfln("Civ founded in year 0 with %d people", civ.population)

	for year in 0..<SIM_YEARS {
		civ_plus_1_year(&civ, year)
		printfln("Year %d:", year)
		for event in civ.event_history[year] {
			printfln(" %v", event_description(event))
		}
		printfln(" At the end of the year, there were %d people", civ.population)
	}
}
