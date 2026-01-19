package history

import "core:fmt"
printfln :: fmt.printfln
tprintf :: fmt.tprintf
println :: fmt.println
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
	events	: [dynamic]Event,
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

	/* Memory Cleanup */

	defer {
		vmem.arena_destroy(&string_arena)

		for c in global.characters {
			delete(c.children)
		}
		delete(global.characters)
		delete(global.events)
		delete(global.houses)
		delete(global.family_names)
		delete(global.civs)
		delete(global.settlements)

		for i in 0..<3 {
			delete(global.given_names[i])
		}
	}

	/* GENERATE INITIAL GIVEN NAMES */
	for _ in 0..<10 {
		append(&global.given_names[male], generate_name(rand.int_range(2, 6), male, string_allocator))
		append(&global.given_names[female], generate_name(rand.int_range(2, 6), female, string_allocator))
	}

	/* STATE SETUP */

	append(&global.civs, Civilization{})
	append(&global.family_names, "(commoner)")
	append(&global.characters, Character{}) // Null character
	append(&global.houses, House{}) // Null House
	append(&global.settlements, Settlement{}) // Null settlement

	/* THE PROGRAM */

	SIM_CHARACTERS :: true

	ruling_house_idx := create_house(-25)
	ruling_house := global.houses[ruling_house_idx]

	initial_civ_name := generate_name(3, 0, string_allocator)
	civ_idx := new_civ(initial_civ_name, ruling_house_idx, ruling_house.current_head)
	civ := &global.civs[civ_idx]

	stl_idx := new_settlement(civ_idx, initial_civ_name)
	settlement := global.settlements[stl_idx]

	println("Behold! The new civilization of", initial_civ_name, "comes into being.")
	println("Ruled by", character_name(ruling_house.current_head), "of the house of", global.family_names[ruling_house.house_name])
	println("The town of", settlement.name, "has", settlement.population, "people")

	/* LOOP */

	for year in 0..<SIM_YEARS {
		if SIM_CHARACTERS {
			for day in 0..<DAYS_IN_YEAR {
				char_events := characters_sim_loop(year, day)
				for ch_env in char_events {
					printfln("In the year %d, %v", year, event_description(ch_env))
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
					}
				}
			}
		}
		for s_idx in 1..<len(global.settlements)
		{
			tick_settlement_year(s_idx)
			s := global.settlements[s_idx]
			println("At the end of year", year, "the settlement of", s.name, "had", s.population, "people")
			println("\tManagers", int(f32(s.population)*s.job_allocation[.Manager]))
			println("\tFood Surplus:", s.inventory[.Food])
		}
		free_all(context.temp_allocator)
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
