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
			return tprintf("%s %s became ruler of [the civilization].", char.given_name, global.family_names[char.family])
		}
		case .Famine: {
			return tprintf("Famine swept the land, killing %d people.", ce.int1)
		}
		case .Death: {
			return tprintf("%s %s died at age %d.",
				global.characters[ce.char1].given_name, global.family_names[global.characters[ce.char1].family],
				global.characters[ce.char1].age)
		}
		case .Marriage: {
			assert(ce.char1 != 0)
			return tprintf("%s %s and %s got married.",
				global.characters[ce.char1].given_name, global.family_names[global.characters[ce.char1].family],
				global.characters[ce.char2].given_name)
		}
		case .Birth: {
			sex := "boy" if ce.int1 == male else "girl"
			return tprintf("%s %s and %s had a baby %s, %s.",
				global.characters[ce.char2].given_name, global.family_names[global.characters[ce.char2].family],
				global.characters[ce.char3].given_name,
				sex,
				global.characters[ce.char1].given_name)
		}
	}
	panic("unreachable")
}
