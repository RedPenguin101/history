package history

import "core:math/rand"

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
	age   : int,
	alive : bool,
	sex   : int,
	spouse, mother, father: int,
	children : [dynamic]int,
	attributes : bit_set[CharacterAttribute],
}

CharacterEventType :: enum
{
	Marriage,
	Death,
}

CharacterEvent :: struct
{
	type:CharacterEventType,
	char1, char2: int,
	year, day: int,
}

character_event_description :: proc(ce:CharacterEvent) -> string
{
	switch ce.type {
		case .Death: {
			return tprintf("%d died at age %d.", ce.char1, characters_global[ce.char1].age)
		}
		case .Marriage: {
			return tprintf("%d and %d got married.", ce.char1, ce.char2)
		}
	}
	panic("unreachable")
}

characters_global : [dynamic]Character
character_events_global : [dynamic]CharacterEvent

create_character :: proc(age, sex, mother, father:int) -> int
{
	idx := len(characters_global)
	char := Character {
		idx = idx,
		age = age,
		alive = true,
		sex = sex,
		mother = mother,
		father = father,
	}
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

characters_sim_loop :: proc(year, day_of_year:int) -> []CharacterEvent
{
	event_start := len(character_events_global)
	// Represents a single iterations. Probably there will be one allowed act per day, or 28*12=336 per year
	for &char, i in characters_global
	{
		if char.idx == 0 || !char.alive do continue

		if .IsMarried not_in char.attributes && char.age < FERTILITY_END
		{
			new_spouse_idx := find_or_create_suitable_mate(char)
			assert(new_spouse_idx > 0)

			char.attributes += {.IsMarried}
			char.spouse = new_spouse_idx

			new_spouse := &characters_global[new_spouse_idx]
			new_spouse.attributes += {.IsMarried}
			new_spouse.spouse = char.idx

			event := CharacterEvent{
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
			char.age += 1
			// Determine if character dies this year
			assert(char.age < len(DEATH_RATE))
			death_prob := DEATH_RATE[char.age]
			roll := rand.float32()
			if roll < death_prob
			{
				char.alive = false
				if .IsMarried in char.attributes {
					spouse := &characters_global[char.spouse]
					spouse.spouse = 0
					spouse.attributes -= {.IsMarried}
				}
				event := CharacterEvent{
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
