package history

import "core:math/rand"

AGRI_YIELD_MEAN :: 1.02
AGRI_YIELD_SD :: 0.04
SURP_COLLECT_PEN_COEFF :: 1
SURP_STORE_PEN_COEFF :: 1
GROWTH_RATE_MEAN :: 5 // percent
GROWTH_RATE_SD :: 3 // percent

Job :: enum
{
	Farmer, Manager,
}

Settlement :: struct
{
	population:int,
	job_allocation:[Job]f32,
	surplus:f32,
}

new_settlement :: proc() -> int
{
	idx := len(global.settlements)
	s : Settlement
	s.population = rand.int_range(400, 1000)
	s.job_allocation = {.Farmer=1.0, .Manager=0.0}
	DEBUG("created settlement", idx, "with pop", s.population)
	append(&global.settlements, s)
	return idx
}

tick_settlement_year :: proc(idx:int)
{
	settlement := &global.settlements[idx]

	yield := rand.float32_normal(AGRI_YIELD_MEAN, AGRI_YIELD_SD)
	DEBUG("ticking", idx)
	surplus := f32(settlement.population)*(yield-1)
	DEBUG("yield", yield, "surplus", surplus)
	is_deficit := yield < 1

	if is_deficit {
		deficit := -surplus
		if settlement.surplus > deficit {
			settlement.surplus -= deficit
			DEBUG("covered deficit")
		} else {
			deaths := (deficit-settlement.surplus)
			settlement.surplus = 0
			settlement.population -= int(deaths)
			DEBUG("uncovered deficit,", f32(settlement.population)*(1-yield), "die")
		}
	} else {
		settlement.surplus += surplus
		growth_percent := rand.float32_normal(GROWTH_RATE_MEAN, GROWTH_RATE_SD) / 100
		DEBUG("Growth %", growth_percent*100)
		new_pop := int(f32(settlement.population)*(1+growth_percent))
		settlement.population = new_pop
	}
	DEBUG("new pop", settlement.population, "new surp", settlement.surplus, "coverage", int(f32(settlement.surplus)/f32(settlement.population)*100),"%")
}
