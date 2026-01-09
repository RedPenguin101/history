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

SIM_YEARS :: 100
DAYS_IN_YEAR :: 336

global : struct {
	characters : [dynamic]Character,
	character_events : [dynamic]Event,
	family_names : [dynamic]string,
	civs : [dynamic]Civilization,
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
		delete(global.family_names)
	}

	append(&global.characters, Character{}) // Null character
	append(&global.civs, new_civ())
	civ := &global.civs[0]
	printfln("Civ founded in year 0 with %d people", civ.population)

	ruler_sex := rand.int_range(1,3)
	ruler_idx := create_character(21, ruler_sex, 0, 0, family=1)
	ruler_family_name := generate_name(rand.int_range(3,6), string_allocator)
	append(&global.family_names, "")
	append(&global.family_names, ruler_family_name)
	civ.ruler_idx = ruler_idx

	became_ruler := Event{
		type = .BecameRuler,
		char1 = ruler_idx,
		year = 0, day = 0,
	}

	append(&global.character_events, became_ruler)
	printfln(" %v", event_description(became_ruler))

	if true {
		for year in 0..<SIM_YEARS {
			for day in 0..<DAYS_IN_YEAR {
				char_events := characters_sim_loop(year, day)
				for ch_env in char_events {
					printfln(" %v", event_description(ch_env))
					if ch_env.type == .Death && ch_env.char1 == civ.ruler_idx {
						inheritor := find_inheritor(civ.ruler_idx)
						if inheritor == 0 do panic("can't find inheritor")
						civ.ruler_idx = inheritor
						became_ruler := Event{
							type = .BecameRuler,
							char1 = civ.ruler_idx,
							year = year, day = day,
						}

						append(&civ.event_history[year], became_ruler)

					}
				}
			}
			civ_plus_1_year(civ, year)
			printfln("Year %d (%d):", year, civ.population)
			for event in civ.event_history[year] {
				printfln(" %v", event_description(event))
			}
		}
	}
}
