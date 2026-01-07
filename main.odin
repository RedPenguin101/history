package history

import "core:fmt"
printfln :: fmt.printfln

import "core:math/rand"

Civilization :: struct
{
	population  : int,
	birth_rate	: f32,
	death_rate	: f32,
}

new_civ :: proc() -> Civilization
{
	pop_min :: 10000
	pop_max :: 50000
	init_pop := rand.int_range(pop_min, pop_max)
	return {
		population = init_pop,
		birth_rate = 37.0/1000.0,
		death_rate = 37.0/1000.0,
	}
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
	civ := new_civ()

	printfln("Civ founded in year 0 with %d people", civ.population)

	for year in 0..<10 {
		civ = civ_plus_1_year(civ)
		printfln("Year %d: New population %d", year, civ.population)
	}
}
