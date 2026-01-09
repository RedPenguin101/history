package history

import "core:math/rand"
import "core:strings"

CharacterAttribute :: enum
{
	IsMarried,
}

male   :: 1
female :: 2
FERTILITY_END   :: 50
FERTILITY_START :: 15

Character :: struct
{
	idx   : int,
	given_name  : string,
	family : int,
	age   : int,
	alive : bool,
	sex   : int,
	spouse, mother, father: int,
	children : [dynamic]int,
	attributes : bit_set[CharacterAttribute],
}

characters_global : [dynamic]Character
character_events_global : [dynamic]Event
family_names : [dynamic]string

create_character :: proc(age, sex, mother, father:int, family:=0, name:string="") -> int
{
	idx := len(characters_global)
	char := Character {
		idx = idx,
		age = age,
		alive = true,
		sex = sex,
		family = family,
		mother = mother,
		father = father,
	}
	if len(name) > 0 {
		char.given_name = strings.clone(name, string_allocator)
	} else {
		char.given_name = strings.clone(generate_name(rand.int_range(3, 5)), string_allocator)
	}
	DEBUG("created", char)
	append(&characters_global, char)
	return idx
}

find_or_create_suitable_mate :: proc(this:Character) -> int
{
	candidate := 0

	for other in characters_global
	{
		if !other.alive do continue
		if other.idx == this.idx do continue
		if other.sex == this.sex do continue
		if other.age < FERTILITY_START do continue
		if other.age > FERTILITY_END do continue
		if other.father == this.father do continue
		if other.mother == this.mother do continue
		if .IsMarried in other.attributes do continue

		candidate = other.idx
	}
	if candidate > 0 do return candidate

	// If no candidate exists, create one

	age := rand.int_range(FERTILITY_START, FERTILITY_END)
	sex := male if this.sex == female else female

    return create_character(age, sex, 0, 0)
}

create_child :: proc(mother, father, year, day: int) {
	sex := rand.int_range(1, 3)
	fam := characters_global[mother].family
	baby_idx := create_character(0, sex, mother, father, family=fam)
	event := Event{
		type = .Birth,
		char1 = baby_idx,
		char2 = mother,
		char3 = father,
		int1  = sex,
		year = year,
		day = day,
	}
	append(&characters_global[father].children, baby_idx)
	append(&characters_global[mother].children, baby_idx)
	append(&character_events_global, event)
}

find_inheritor :: proc(char_idx:int) -> int
{
	for child_idx in characters_global[char_idx].children {
		child := characters_global[child_idx]
		if child.alive do return child_idx
	}
	// no living children
	return 0
}

characters_sim_loop :: proc(year, day_of_year:int) -> []Event
{
	event_start := len(character_events_global)
	// Represents a single iterations. Probably there will be one allowed act per day, or 28*12=336 per year
	for char, i in characters_global
	{
		if char.idx == 0 || !char.alive do continue

		if .IsMarried not_in char.attributes && char.age >= FERTILITY_START && char.age < FERTILITY_END
		{
			DEBUG("1: marriage for i=", i, "char=", char)
			new_spouse_idx := find_or_create_suitable_mate(char)
			assert(new_spouse_idx > 0)

			// Mutations are done separately because we're potentially creating characters as part of this.
			// So the pointers can get messed up if there's a realloc

			characters_global[i].attributes += {.IsMarried}
			characters_global[i].spouse = new_spouse_idx

			DEBUG("2: marriage for i=", i, "char=", char)

			characters_global[new_spouse_idx].attributes += {.IsMarried}
			characters_global[new_spouse_idx].spouse = char.idx

			if characters_global[new_spouse_idx].family == 0 {
				characters_global[new_spouse_idx].family = char.family
			} else {
				roll := rand.float32()
				if roll < 0.5 {
					characters_global[new_spouse_idx].family = char.family
				} else {
					characters_global[i].family = characters_global[new_spouse_idx].family
				}
			}

			event := Event{
				type = .Marriage,
				char1 = char.idx,
				char2 = new_spouse_idx,
				year = year,
				day = day_of_year,
			}
			append(&character_events_global, event)
		}

		if day_of_year == 0
		{
			characters_global[i].age += 1

			// Determine if the character has children this year.
			// There's a 10% chance whenever both partners in a
			// marriage are fertile

			if char.sex == female && .IsMarried in char.attributes && char.age >= FERTILITY_START && char.age < FERTILITY_END
			{
				husband := characters_global[char.spouse]
				if husband.age >= FERTILITY_START && husband.age < FERTILITY_END {
					roll := rand.float32()
					if roll < 0.1 {
						create_child(i, char.spouse, day_of_year, year)
					}
				}
			}

			// Determine if character dies this year
			assert(char.age < len(DEATH_RATE))
			death_prob := DEATH_RATE[char.age]
			roll := rand.float32()
			if roll < death_prob
			{
				characters_global[i].alive = false
				if .IsMarried in char.attributes {
					spouse := &characters_global[char.spouse]
					spouse.spouse = 0
					spouse.attributes -= {.IsMarried}
				}
				event := Event{
					type = .Death,
					char1 = char.idx,
					year = year,
					day = day_of_year,
				}
				append(&character_events_global, event)
			}
		}
	}
	event_end := len(character_events_global)
	/* DEBUG("events", event_start, event_end) */
	return character_events_global[event_start:event_end]
}
