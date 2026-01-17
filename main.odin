package history

import "core:fmt"
printfln :: fmt.printfln
tprintf :: fmt.tprintf
import "core:mem"
import "core:log"
DEBUG :: log.debug
INFO  :: log.info

import "core:math/rand"

import vmem "core:mem/virtual"
string_arena : vmem.Arena
string_allocator : mem.Allocator

SIM_YEARS :: 200
DAYS_IN_YEAR :: 336

global : struct {
	characters			: [dynamic]Character,
	character_events	: [dynamic]Event,
	houses              : [dynamic]House,
	given_names			: [3][dynamic]string,
	family_names		: [dynamic]string,
	civs				: [dynamic]Civilization,
	settlements         : [dynamic]Settlement,
}

main :: proc()
{
	/* PRELUDE AND MEMORY ADMIN */

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
	for _ in 0..<10 {
		append(&global.given_names[male], generate_name(rand.int_range(2, 6), male, string_allocator))
		append(&global.given_names[female], generate_name(rand.int_range(2, 6), female, string_allocator))
	}

	defer {
		vmem.arena_destroy(&string_arena)

		for c in global.characters {
			delete(c.children)
		}
		delete(global.characters)
		delete(global.character_events)

		for civ in global.civs {
			for events in civ.event_history {
				delete(events)
			}
		}
		delete(global.civs)
		delete(global.settlements)

		delete(global.houses)
		delete(global.family_names)
		delete(global.given_names[1])
		delete(global.given_names[2])
	}

	/* STATE SETUP */

	append(&global.family_names, "(commoner)")
	append(&global.characters, Character{}) // Null character
	append(&global.houses, House{}) // Null House
	append(&global.settlements, Settlement{})

	/* THE PROGRAM */

	SIM_CHARACTERS :: false

	new_settlement()

	append(&global.civs, new_civ())
	civ := &global.civs[0]
	houses := rand.int_range(5,10)

	for _ in 0..<houses {
		idx := create_house(-25)
		house := global.houses[idx]
	}

	ruling_house := global.houses[1]

	fmt.printfln("The civilization [name] emerged in the year 0. It numbered %d people", civ.population)
	fmt.printfln("It was ruled by %s of house %s.", character_name(ruling_house.current_head), global.family_names[ruling_house.house_name])
	fmt.print("The houses of ")
	for house, i in global.houses[2:] {
		if i < len(global.houses)-4
		{
			fmt.printf("%s, ", global.family_names[house.house_name])
		}
		else if i == len(global.houses)-4 {
			fmt.printf("%s and ", global.family_names[house.house_name])
		} else {
			fmt.printf("%s ", global.family_names[house.house_name])
		}
	}
	fmt.printfln("were also prominant.")

	civ.ruler_house = 1
	civ.ruler_idx = ruling_house.current_head

	became_ruler := Event{
		type = .BecameRuler,
		char1 = ruling_house.current_head,
		int1 = 1,
		year = 0, day = 0,
	}

	append(&global.character_events, became_ruler)
	printfln("In 0, %v", event_description(became_ruler))

	/* LOOP */

	/* test_collection_loss() */

	for year in 0..<SIM_YEARS {
		if SIM_CHARACTERS {
			for day in 0..<DAYS_IN_YEAR {
				char_events := characters_sim_loop(year, day)
				for ch_env in char_events {
					printfln("In %d, %v", year, event_description(ch_env))
					if ch_env.type == .Death && ch_env.char1 == civ.ruler_idx {
						// The current ruler has died, select a new one
						old_ruler := civ.ruler_idx
						old_house := civ.ruler_house

						new_house_head := global.houses[civ.ruler_house].current_head
						if new_house_head > 0 {
							civ.ruler_idx = new_house_head
						} else {
							// The old house is extinct
							new_house := 0
							new_ruler := 0
							for house, i in global.houses {
								if house.current_head > 0 {
									new_house = i
									new_ruler = house.current_head
									break
								}
							}
							if new_house > 0 {
								civ.ruler_house = new_house
								civ.ruler_idx   = global.houses[new_house].current_head
							} else {
								panic("Couldn't find a candidate for new ruler...")
							}
						}
						became_ruler := Event{
							type = .BecameRuler,
							char1 = civ.ruler_idx,
							int1  = civ.ruler_house,
							char2 = old_ruler, int2 = old_house,
							year = year, day = day,
						}

						append(&civ.event_history[year], became_ruler)

					}
				}
			}
		}
		for s_idx in 1..<len(global.settlements)
		{
			tick_settlement_year(s_idx)
		}
		civ_plus_1_year(civ, year)
		for event in civ.event_history[year] {
			printfln("In %d, %v", year, event_description(event))
		}
	}

	if SIM_CHARACTERS {
		for house in global.houses[1:] {
			fmt.printfln("after %d years, house %s has %d living members (%d total)",
				SIM_YEARS,
				global.family_names[house.house_name],
				house.living_members, house.total_members)
		}
	}
}
