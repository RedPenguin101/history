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

test_collection_loss :: proc()
{
	calc :: proc(x, k: f32) -> f32
	{
		return k * (1 - math.exp(-x / k))
	}

	// Food produced is p = 1.1F (where F is the number of farmers)
	// Surplus is       s = p-x
	// Collected is     c = b(1-e^s/b)
	// b is maximum amount that can be collected, which is the
	// base  + 10√M (where M is the number of managers)

	pops := [?]f32{100, 250, 500, 750, 1000, 2000, 4000, 8000, 16000, 32000, 64000, 100000}
	mans := [?]f32{0, 0.01, 0.02, 0.03, 0.04, 0.05, 0.06, 0.07, 0.08, 0.09, 0.10, 0.2, 0.4, 0.5}
	BASE:f32= 50

	for population in pops {
		for m in mans {
			managers := m*population
			farmers := (1-m)*population
			produced := 1.1*farmers
			surplus := produced - population
			if surplus < 0 {
				printfln("Mng: %4d\t Pop: %d\t Surp: %d\t DEFICIT",
					int(managers), int(population), int(surplus))
			} else {
				b := BASE+10.0*math.sqrt(managers)
				collected := calc(surplus, b)
				printfln("Mng: %4d\t Pop: %d\t Surp: %d\t b: %d\t coll: %d\t loss: %d",
					int(managers), int(population), int(surplus), int(b), int(collected),
					int(100*(surplus-collected)/surplus))
			}
		}
	}
}

tick_settlement_year :: proc(idx:int)
{
	/* DEBUG("TICKING", idx) */
	settlement := &global.settlements[idx]

	calc :: proc(x, k: f32) -> f32
	{
		return k * (1 - math.exp(-x / k))
	}

	// Food produced is p = 1.1F (where F is the number of farmers)
	// Surplus is       s = p-x
	// Collected is     c = b(1-e^s/b)
	// b is maximum amount that can be collected, which is the
	// base  + 10√M (where M is the number of managers)

	yield:f32 = rand.float32_normal(1.1, 0.2)
	/* DEBUG("YIELD", yield) */
	population := f32(settlement.population)
	farmers := population * settlement.job_allocation[.Farmer]
	managers := population * settlement.job_allocation[.Manager]

	BASE :: 20.0
	XTRA_COLL_PER_MGR :: 8
	b_calc :: proc(managers:f32) -> f32 {
		return BASE + managers*XTRA_COLL_PER_MGR
	}

	produced := farmers * yield
	surplus := produced - population
	is_deficit := surplus < 1

	if is_deficit {
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
		b := b_calc(managers)
		collected := calc(surplus, b)

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
			DELTA :: 0.001
			m_delta := population * DELTA
			farmers -= m_delta
			managers += m_delta
			produced = farmers * yield
			surplus = produced - population
			b = b_calc(managers)

			new_collected := calc(surplus, b)
			/* println("\tM_delta", int(m_delta), "new surp", int(surplus), "new coll", int(new_collected)) */
			if int(m_delta) >= 1 && new_collected > collected {
				settlement.job_allocation[.Manager] += DELTA
				settlement.job_allocation[.Farmer] -= DELTA
			}
		}
	}
}
