package history

import "core:math/rand"
import "core:strings"

CharacterAttribute :: enum
{
	IsMarried,
}

male			:: 1
female			:: 2
FERTILITY_END   :: 50
FERTILITY_START :: 15

Character :: struct
{
	idx						: int,
	given_name				: int,
	family					: int,
	age						: int,
	alive					: bool,
	sex						: int,
	spouse, mother, father	: int,
	children				: [dynamic]int,
	attributes				: bit_set[CharacterAttribute],
}

create_character :: proc(age, sex, mother, father:int, family:=0, name:=0) -> int
{
	idx := len(global.characters)
	char := Character {
		idx		= idx,
		age		= age,
		alive	= true,
		sex		= sex,
		family	= family,
		mother	= mother,
		father	= father,
	}
	if name > 0 {
		char.given_name = name
	} else {
		char.given_name = rand.int_max(len(global.given_names[sex]))
	}
	append(&global.characters, char)
	return idx
}

find_or_create_suitable_mate :: proc(this:Character) -> int
{
	candidate := 0

	for other in global.characters
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

choose_child_name :: proc(mother, father, sex:int) -> int {
	mat_gp := global.characters[mother].father if sex == male else global.characters[mother].mother
	pat_gp := global.characters[father].father if sex == male else global.characters[father].mother

	has_mat_gp := (mat_gp > 0)
	has_pat_gp := (pat_gp > 0)

	child_name : int

	parent_name := global.characters[father if sex == male else mother].given_name
	mat_gp_name := global.characters[mat_gp].given_name if has_mat_gp else 0
	pat_gp_name := global.characters[pat_gp].given_name if has_pat_gp else 0

	roll := rand.float32()

	has_sibling_named_for_parent := false
	has_sibling_named_for_mat_gp := false
	has_sibling_named_for_pat_gp := false

	for child in global.characters[mother].children {
		sibling_name := global.characters[child].given_name
		if sibling_name == parent_name do has_sibling_named_for_parent = true
		if sibling_name == mat_gp_name do has_sibling_named_for_mat_gp = true
		if sibling_name == pat_gp_name do has_sibling_named_for_pat_gp = true
	}

	if roll < 0.3 && !has_sibling_named_for_parent
	{
		return parent_name
	}
	else if roll < 0.5 && has_pat_gp && !has_sibling_named_for_pat_gp
	{
		return pat_gp_name
	}
	else if roll < 0.7 && has_mat_gp && !has_sibling_named_for_mat_gp
	{
		return mat_gp_name
	}
	return rand.int_max(len(global.given_names[sex]))
}

create_child :: proc(mother, father, year, day: int) {
	fam := global.characters[mother].family
	sex := rand.int_range(1, 3)
	name := choose_child_name(mother, father, sex)

	baby_idx := create_character(0, sex, mother, father, family=fam, name=name)

	event := Event{
		type = .Birth,
		char1 = baby_idx,
		char2 = mother,
		char3 = father,
		int1  = sex,
		year = year,
		day = day,
	}

	append(&global.characters[father].children, baby_idx)
	append(&global.characters[mother].children, baby_idx)
	append(&global.character_events, event)
}

find_inheritor :: proc(char_idx:int) -> int
{
	for child_idx in global.characters[char_idx].children {
		child := global.characters[child_idx]
		if child.alive do return child_idx
	}
	// no living children
	return 0
}

characters_sim_loop :: proc(year, day_of_year:int) -> []Event
{
	event_start := len(global.character_events)
	// Represents a single iterations. Probably there will be one allowed act per day, or 28*12=336 per year
	for char, i in global.characters
	{
		if char.idx == 0 || !char.alive do continue

		if .IsMarried not_in char.attributes && char.age >= FERTILITY_START && char.age < FERTILITY_END
		{
			new_spouse_idx := find_or_create_suitable_mate(char)
			assert(new_spouse_idx > 0)

			// Mutations are done separately because we're potentially creating characters as part of this.
			// So the pointers can get messed up if there's a realloc

			global.characters[i].attributes += {.IsMarried}
			global.characters[i].spouse = new_spouse_idx

			global.characters[new_spouse_idx].attributes += {.IsMarried}
			global.characters[new_spouse_idx].spouse = char.idx

			if global.characters[new_spouse_idx].family == 0 {
				global.characters[new_spouse_idx].family = char.family
			} else {
				roll := rand.float32()
				if roll < 0.5 {
					global.characters[new_spouse_idx].family = char.family
				} else {
					global.characters[i].family = global.characters[new_spouse_idx].family
				}
			}

			event := Event{
				type = .Marriage,
				char1 = char.idx,
				char2 = new_spouse_idx,
				year = year,
				day = day_of_year,
			}
			append(&global.character_events, event)
		}

		if day_of_year == 0
		{
			global.characters[i].age += 1

			// Determine if the character has children this year.
			// There's a 10% chance whenever both partners in a
			// marriage are fertile

			if char.sex == female && .IsMarried in char.attributes && char.age >= FERTILITY_START && char.age < FERTILITY_END
			{
				husband := global.characters[char.spouse]
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
				global.characters[i].alive = false
				if .IsMarried in char.attributes {
					spouse := &global.characters[char.spouse]
					spouse.spouse = 0
					spouse.attributes -= {.IsMarried}
				}
				event := Event{
					type = .Death,
					char1 = char.idx,
					year = year,
					day = day_of_year,
				}
				append(&global.character_events, event)
			}
		}
	}
	event_end := len(global.character_events)
	return global.character_events[event_start:event_end]
}
