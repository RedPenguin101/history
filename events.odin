package history

EventType :: enum
{ Famine, Marriage, Death, Birth, BecameFamilyHead, BecameRuler }

Event :: struct
{
	type : EventType,
	day, year  : int,
	char1, char2, char3,
	civ1, civ2,
	int1, int2: int,
}

event_description :: proc(ce:Event) -> string
{
	switch ce.type {
		case .BecameRuler: {
			char := global.characters[ce.char1]
			if ce.char2 > 0 && ce.int2 > 0 {
				return tprintf("%s %s became ruler of [the civilization] at age %d, succeeding %s %s.",
					character_name(ce.char1),
					global.family_names[ce.int1],
					ce.year-char.birth_year,
					character_name(ce.char2), global.family_names[ce.int2])
			} else {
				return tprintf("%s %s became ruler of [the civilization] at age %d",
					character_name(ce.char1),
					global.family_names[ce.int1],
					ce.year-char.birth_year,
					)
			}
		}
		case .BecameFamilyHead: {
			if ce.char1 == 0 {
				return tprintf("After the death of %s, having no suitable descendents, the house of %s became extinct.",
					character_name(ce.char2), global.family_names[ce.int1])
			} else {
				char := global.characters[ce.char1]
				return tprintf("%s %s became head of house %s at the age of %d, succeeding %s.",
					character_name(ce.char1),
					global.family_names[char.family],
					global.family_names[ce.int1],
					ce.year-char.birth_year,
					character_name(ce.char2))
			}
		}
		case .Famine: {
			return tprintf("Famine swept the land, killing %d people.", ce.int1)
		}
		case .Death: {
			char := global.characters[ce.char1]
			return tprintf("%s %s died at age %d",
				character_name(ce.char1),
				global.family_names[char.family],
				ce.year-char.birth_year,
				)
		}
		case .Marriage: {
			assert(ce.char1 != 0)
			char1 := global.characters[ce.char1]
			char2 := global.characters[ce.char2]
			return tprintf("%s %s and %s %s got married.",
				character_name(ce.char1),
				global.family_names[ce.int1],
				character_name(ce.char2),
				global.family_names[ce.int2])
		}
		case .Birth: {
			sex := "boy" if ce.int1 == male else "girl"
			char1 := global.characters[ce.char1]
			char2 := global.characters[ce.char2]
			char3 := global.characters[ce.char3]
			return tprintf("%s %s and %s %s had a baby %s, %s %s.",
				character_name(ce.char2),
				global.family_names[char2.family],
				character_name(ce.char3),
				global.family_names[char3.family],
				sex,
				character_name(ce.char1),
				global.family_names[char1.family],
				)
		}
	}
	panic("unreachable")
}
