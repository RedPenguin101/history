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
	birth_year              : int,
	alive					: bool,
	death_year              : int,
	sex						: int,
	spouse, mother, father	: int,
	children				: [dynamic]int,
	attributes				: bit_set[CharacterAttribute],
}

create_character :: proc(birth_year, sex, mother, father:int, family:=0, name:=0) -> int
{
	idx := len(global.characters)
	char := Character {
		idx		= idx,
		birth_year = birth_year,
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
	global.houses[family].living_members += 1
	global.houses[family].total_members += 1

	return idx
}

character_name :: proc(idx:int) -> string
{
	char := global.characters[idx]
	sex := char.sex
	return global.given_names[sex][char.given_name]
}

find_or_create_suitable_mate :: proc(this:Character, year:int) -> int
{
	/* This routine tries to find candidates for marriage. The
	preferred candidate for marriage is not already married, not
	closely related, in another house, and fertile */

	candidates := make([dynamic]struct{idx:int,score:f32}, context.temp_allocator)
	el : struct{idx:int,score:f32}
	total_score:f32 = 0.0
	candidate := 0
	house_count := len(global.houses)

	for other, idx in global.characters
	{
		score:f32 = 0.0

		// Disqualifying criteria
		if !other.alive || other.idx == this.idx || other.sex == this.sex do continue
		if other.father == this.father || other.mother == this.mother do continue
		if .IsMarried in other.attributes do continue

		other_age := year-other.birth_year
		is_fertile := other_age < FERTILITY_END && other_age > FERTILITY_START

		if is_fertile do score += 20

		// The highest prominance house that is LOWER than yours is best, because children
		// born of the marriage belong to the highest prominance house

		// e.g. if this.family = 3, the ideal other.family is 4 (the next most prominent house).
		// 5 is slightly less preferable. 2 is less preferable than that, because the children
		// won't be of your house

		family_delta := other.family - this.family
		if other.family == 0 do score += 0
		else if this.family > other.family do score += 0 // don't want to marry into more prominant house
		else do f32(house_count-other.family+1)

		el.idx = idx; el.score = score
		append(&candidates, el)
		total_score += score
	}

	if len(candidates) > 0 {
		roll := rand.float32()

		acc:f32 = 0
		for el in candidates {
			n_score := el.score/total_score + acc
			if n_score > roll do return el.idx
			acc += el.score/total_score
		}
	}

	// If no candidate exists, create one from commoners

	age := rand.int_range(FERTILITY_START, FERTILITY_END)
	birth_year := year - age
	sex := male if this.sex == female else female

    return create_character(birth_year, sex, 0, 0)
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

create_child :: proc(mother, father, year, day: int) -> int {
	sex := rand.int_range(1, 3)
	name := choose_child_name(mother, father, sex)

	mother_fam := global.characters[mother].family
	father_fam := global.characters[father].family
	fam : int

	// The family of the child is the most prominant house of the parents.
	if mother_fam == 0 {
		fam = father_fam
	} else if father_fam == 0 {
		fam = mother_fam
	} else {
		fam = min(father_fam, mother_fam)
	}

	baby_idx := create_character(year, sex, mother, father, family=fam, name=name)

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
	return baby_idx
}

find_house_head :: proc(idx:int, house:=true) -> int
{
	// NOTE: Intended to be called externally with a single param, the house ID.
	// But interally will just look up that houses founder and (if they are dead)
	// walk their descendents tree.

	if house {
		founder_idx := global.houses[idx].founder_idx
		if global.characters[founder_idx].alive do return founder_idx
		return find_house_head(founder_idx, false)
	}
	char := global.characters[idx]
	inheritor := 0
	for child_idx in char.children {
		child := global.characters[child_idx]
		if child.alive {
			return child_idx
		} else {
			inheritor = find_house_head(child_idx, false)
		}
		if inheritor != 0 do return inheritor
	}
	return inheritor
}

find_inheritor :: proc(char_idx:int, ignore:=0) -> int
{
	// TODO: This will fail in the case that a char has no
	// descendents, and their next sibling has no descendents.
	// It will oscillate between checking the char and the sibling. A
	// 'seen' set is required.

	inheritor := 0
	char := global.characters[char_idx]
	for child_idx in char.children {
		if child_idx == ignore {
			continue
		}
		child := global.characters[child_idx]
		if child.alive {
			return child_idx
		}
		else {
			inheritor = find_inheritor(child_idx)
		}
		if inheritor != 0 do return inheritor
	}
	if inheritor == 0 && char.mother != 0 {
		inheritor = find_inheritor(char.mother, char_idx)
	}
	if inheritor == 0 && char.father != 0 {
		inheritor = find_inheritor(char.father, char_idx)
	}
	// no living children
	return inheritor
}

character_death :: proc(idx,year:int)
{
	char := &global.characters[idx]
	char.alive = false
	char.death_year = year
	if .IsMarried in char.attributes {
		spouse := &global.characters[char.spouse]
		spouse.spouse = 0
		spouse.attributes -= {.IsMarried}
	}

	// reduce number of house members, pick new house head if char was house head

	house := &global.houses[char.family]
	house.living_members -= 1

	if house.current_head == idx {
		inheritor := find_house_head(char.family)
		house.current_head = inheritor
		event := Event{
			type = .BecameFamilyHead,
			int1 = char.family,
			char1 = inheritor,
			char2 = idx,
			year = year,
			// TODO: Maybe move this thing out, not great to be creating events here should be in main loop
			day = 0,
		}
		append(&global.character_events, event)
	}
}

characters_sim_loop :: proc(year, day_of_year:int) -> []Event
{
	event_start := len(global.character_events)
	// Represents a single iterations. Probably there will be one allowed act per day, or 28*12=336 per year
	for char, i in global.characters
	{
		if char.idx == 0 || !char.alive do continue

		char_age := year - char.birth_year

		// MARRIAGE EVENT
		if char.family > 0 && .IsMarried not_in char.attributes && char_age >= FERTILITY_START && char_age < FERTILITY_END
		{
			new_spouse_idx := find_or_create_suitable_mate(char, year)
			assert(new_spouse_idx > 0)

			// Mutations are done separately because we're potentially creating characters as part of this.
			// So the pointers can get messed up if there's a realloc

			global.characters[i].attributes += {.IsMarried}
			global.characters[i].spouse = new_spouse_idx

			global.characters[new_spouse_idx].attributes += {.IsMarried}
			global.characters[new_spouse_idx].spouse = char.idx

			char_old_family := char.family
			spouse_old_family := global.characters[new_spouse_idx].family

			event := Event{
				type = .Marriage,
				char1 = char.idx,
				char2 = new_spouse_idx,
				year = year,
				day = day_of_year,
				int1 = char_old_family,
				int2 = spouse_old_family,
			}
			append(&global.character_events, event)
		}

		if day_of_year == 0
		{
			// CHILD EVENT
			// Determine if the character has children this year.
			// There's a 10% chance whenever both partners in a
			// marriage are fertile

			if char.sex == female && .IsMarried in char.attributes && char_age >= FERTILITY_START && char_age < FERTILITY_END
			{
				husband := global.characters[char.spouse]
				husband_age := year-husband.birth_year
				if husband_age >= FERTILITY_START && husband_age < FERTILITY_END {
					roll := rand.float32()
					if roll < 0.1 {
						create_child(i, char.spouse, year, day_of_year)
					}
				}
			}

			// Determine if character dies this year
			assert(char_age < len(DEATH_RATE))
			death_prob := DEATH_RATE[char_age]
			roll := rand.float32()
			if roll < death_prob {
				character_death(i, year)
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

/* HOUSES */

House :: struct
{
	house_name   : int,
	founder_idx  : int,
	current_head : int,
	total_members : int,
	living_members : int,
}

create_house :: proc(start_year:int) -> int
{
	house_idx := len(global.houses)
	house_name_idx := len(global.family_names)

	house := House {
		house_name = house_name_idx,
	}
	append(&global.houses, house)

	house_name := generate_name(rand.int_range(3,6), 0, string_allocator)
	append(&global.family_names, house_name)

	founder_sex := rand.int_range(1,3)
	founder_idx := create_character(start_year, founder_sex, 0, 0, house_idx, house_name_idx)

	global.houses[house_idx].founder_idx = founder_idx
	global.houses[house_idx].current_head = founder_idx

	return house_idx
}

descendents :: proc(char_idx:int) -> (living,total:int) {
	// TODO: This will definitely double count
	char := global.characters[char_idx]

	tot := 1
	liv := 1 if char.alive else 0

	for child in char.children {
		ld, td := descendents(child)
		liv += ld
		tot += td
	}

	return liv, tot
}
