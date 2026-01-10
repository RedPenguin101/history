package history

EventType :: enum
{ Famine, Marriage, Death, Birth, BecameRuler }

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
			return tprintf("%s %s became ruler of [the civilization].",
				character_name(ce.char1),
				global.family_names[char.family])
		}
		case .Famine: {
			return tprintf("Famine swept the land, killing %d people.", ce.int1)
		}
		case .Death: {
			char := global.characters[ce.char1]
			return tprintf("%s %s died at age %d.",
				character_name(ce.char1),
				global.family_names[char.family],
				ce.year-char.birth_year)
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
			return tprintf("%s %s and %s had a baby %s, %s.",
				character_name(ce.char2),
				global.family_names[char2.family],
				character_name(ce.char3),
				sex,
				character_name(ce.char1))
		}
	}
	panic("unreachable")
}
