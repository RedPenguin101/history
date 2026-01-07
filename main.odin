package history

import "core:fmt"
printfln :: fmt.printfln

Civilization :: struct
{
	population  : int,
	birth_rate	: f32,
	death_rate	: f32,
}

civ_plus_1_year :: proc(c:Civilization) -> Civilization
{
	// new_pop = pop + (b*pop) - (d*pop)
	//         = pop * (1+b-d)
	cr := c
	cr.population = int(f32(c.population)*(1+c.birth_rate-c.death_rate))
	return cr
}

main :: proc()
{
	civ := Civilization {
		population = 1000,
		birth_rate = 37.0/1000.0,
		death_rate = 27.0/1000.0,
	}

	printfln("Civ founded in year 0 with %d people", civ.population)

	for year in 0..<10 {
		civ = civ_plus_1_year(civ)
		printfln("Year %d: New population %d", year, civ.population)
	}
}
