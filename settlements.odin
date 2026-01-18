package history

import "core:math/rand"
import "core:math"

AGRI_YIELD_MEAN :: 1.02
AGRI_YIELD_SD :: 0.04

GROWTH_RATE_MEAN :: 5 // percent
GROWTH_RATE_SD :: 3 // percent

SURP_COLLECT_PEN_COEFF :: 1.1

SURP_STORE_PEN_COEFF :: 1.05

Job :: enum
{
	Farmer, Manager,
}

Settlement :: struct
{
	population:int,
	job_allocation:[Job]f32,
	surplus:f32,
	civilization:int,
	name:string,
}

new_settlement :: proc(civ:int, name:string) -> int
{
	idx := len(global.settlements)
	s : Settlement
	s.civilization = civ
	s.name = name
	s.population = rand.int_range(400, 1000)
	s.job_allocation = {.Farmer=1.0, .Manager=0.0}
	append(&global.settlements, s)
	return idx
}

tick_settlement_year :: proc(idx:int)
{
	BASE_COLL_MAX :: 20.0
	XTRA_COLL_PER_MGR :: 8

	YIELD_MEAN :: 1.1
	YIELD_SD :: 0.2

	M_ADJUST_DELTA :: 0.001

	collection_amount :: proc(available, max_collectable: f32) -> f32
	{
		return max_collectable * (1 - math.exp(- available / max_collectable))
	}

	max_collectable :: proc(managers:f32) -> f32
	{
		return BASE_COLL_MAX + managers*XTRA_COLL_PER_MGR
	}

	settlement := &global.settlements[idx]

	yield:f32 = rand.float32_normal(YIELD_MEAN, YIELD_SD)
	population := f32(settlement.population)
	farmers := population * settlement.job_allocation[.Farmer]
	managers := population * settlement.job_allocation[.Manager]

	produced := farmers * yield
	surplus := produced - population
	is_deficit := surplus < 1

	if is_deficit {
		// TODO: shrink managers on deaths? They shrink proportionally anyway, maybe it's OK
		// TODO: managers make the distribution of surplus more effective
		deficit := -surplus
		deaths:f32 = 0
		if settlement.surplus > deficit {
			settlement.surplus -= deficit
		} else {
			deaths = (deficit-settlement.surplus)
			settlement.surplus = 0
			settlement.population -= int(deaths)
			/* TODO: Managers don't die, only farmers */
		}
		/* printfln("Mng: %4d\t Pop: %d\t Surp: %4d (%4d)\t DEFICIT deaths %d", */
			/* int(managers), int(population), int(surplus), int(settlement.surplus), int(deaths)) */
	} else {
		b := max_collectable(managers)
		collected := collection_amount(surplus, b)

		settlement.surplus += collected
		growth_percent := rand.float32_normal(GROWTH_RATE_MEAN, GROWTH_RATE_SD) / 100
		net_births := population * growth_percent

		settlement.population += int(net_births)
		settlement.job_allocation[.Farmer] = (farmers+net_births)/(population+net_births)
		settlement.job_allocation[.Manager] = (managers)/(population+net_births)

		/* printfln("Mng: %4d\t Pop: %d\t Surp: %4d (%4d)\t coll: %d\t loss: %d", */
		/* 	int(managers), int(population), int(surplus), int(settlement.surplus), int(collected), */
		/* 	int(100*(surplus-collected)/surplus)) */

		ADJUST :: true
		if ADJUST {
			m_delta := population * M_ADJUST_DELTA
			farmers -= m_delta
			managers += m_delta
			produced = farmers * yield
			surplus = produced - population
			b = max_collectable(managers)

			new_collected := collection_amount(surplus, b)
			/* println("\tM_delta", int(m_delta), "new surp", int(surplus), "new coll", int(new_collected)) */
			if int(m_delta) >= 1 && new_collected > collected {
				settlement.job_allocation[.Manager] += M_ADJUST_DELTA
				settlement.job_allocation[.Farmer] -= M_ADJUST_DELTA
			}
		}
	}
}
