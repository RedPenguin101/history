package history

import "core:fmt"
printfln :: fmt.printfln
tprintf :: fmt.tprintf
import "core:mem"
import "core:log"
DEBUG :: log.debug

import "core:math/rand"
import "core:strings"

import vmem "core:mem/virtual"
string_arena : vmem.Arena
string_allocator : mem.Allocator

SIM_YEARS :: 100
DAYS_IN_YEAR :: 336

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

main :: proc()
{
	context.logger = log.create_console_logger()
	context.logger.lowest_level = .Warning
	defer log.destroy_console_logger(context.logger)

	when ODIN_DEBUG {
		context.logger.lowest_level = .Debug
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				for _, entry in track.allocation_map {
					fmt.eprintf("%v leaked %v bytes\n", entry.location, entry.size)
				}
			}
			if len(track.bad_free_array) > 0 {
				for entry in track.bad_free_array {
					fmt.eprintf("%v bad free at %v\n", entry.location, entry.memory)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

	string_allocator = vmem.arena_allocator(&string_arena)
	defer vmem.arena_destroy(&string_arena)

	defer delete(characters_global)
	defer delete(character_events_global)

	append(&characters_global, Character{}) // Null character
	civ := new_civ()
	ruler_sex := rand.int_range(1,3)
	ruler_idx := create_character(21, ruler_sex, 0, 0, family=1)
	ruler_family_name := generate_name(rand.int_range(3,6), string_allocator)
	append(&family_names, "")
	append(&family_names, ruler_family_name)
	civ.ruler_idx = ruler_idx

	defer {
		for events in civ.event_history {
			delete(events)
		}
	}

	printfln("Civ founded in year 0 with %d people, ruled by %d", civ.population, civ.ruler_idx)

	if true {
		for year in 0..<SIM_YEARS {
			for day in 0..<DAYS_IN_YEAR {
				char_events := characters_sim_loop(year, day)
				for ch_env in char_events {
					printfln(" %v", character_event_description(ch_env))
				}
			}
			civ_plus_1_year(&civ, year)
			printfln("Year %d (%d):", year, civ.population)
			for event in civ.event_history[year] {
				printfln(" %v", civ_event_description(event))
			}
		}
	}
}
