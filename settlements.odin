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
	A:f32 = 2.0 // Admin efficiency
	B:f32 = 100 // 
	N:f32 = 1.1
	m:f32 = 0.0
	f:f32 = 1-m
	FUDGE :: 1.0

	test_pops := [?]f32{
		10, 100, 1000, 2000, 3000, 4000, 5000, 6000, 10000

	}

	test_ms := [?]f32{ 0.0, 0.01, 0.05, 0.1, 0.3, 0.7, 1.0}

	for x in test_pops
	{
		DEBUG("POP:", x)
		baseline : f32
		for m in test_ms
		{
			f := 1-m
			produced := N*f*x
			surplus := produced - x
			if surplus > 0 {
				collected := (A*m*x + B) * (1-math.exp(-surplus/(FUDGE*A*m*x + B)))
				if m == 0.0 do baseline = collected

				DEBUG("m", int(100*m), "%",
					"surp", int(surplus),
					"coll", int(collected),
					"loss", int(100*(surplus-collected)/surplus), "%",
					"base", int(100*(collected-baseline)/baseline), "%")
			} else {
				DEBUG("m", int(100*m), "deficit")
			}
		}
	}
}

tick_settlement_year :: proc(idx:int)
{
	/* DEBUG("TICKING", idx) */
	settlement := &global.settlements[idx]

	if settlement.surplus > 0 {
		unspoiled := math.pow(settlement.surplus, 1/SURP_STORE_PEN_COEFF)
		spoilage := settlement.surplus - unspoiled
		/* DEBUG("start surp", settlement.surplus) */
		/* DEBUG(int(100*(spoilage/settlement.surplus)), "% of stored surplus spoiled.") */
		settlement.surplus -= spoilage
		/* DEBUG("end surp", settlement.surplus) */
	}

	// Formula for food collected is
	//// y = (Amx+B)*(1-e^(-Nfx/(3Amx+B)))
	// where x is population, m is proportion of managers, n, f is proportion of farmers
	// A = admin efficiency, B = base collection cap, N = yield

	A:f32 = 0.1
	B:f32 = 50.0
	N := rand.float32_normal(AGRI_YIELD_MEAN, AGRI_YIELD_SD)
	m := settlement.job_allocation[.Manager]
	f := settlement.job_allocation[.Farmer]
	x := f32(settlement.population)
	FUDGE :: 1.0

	produced := N*f*x
	surplus := produced - x
	/* DEBUG("yield", int(100*N), "% produced", int(produced), "surplus", int(surplus)) */
	is_deficit := surplus < 1

	if is_deficit {
		deficit := -surplus
		if settlement.surplus > deficit {
			settlement.surplus -= deficit
			/* DEBUG("covered deficit") */
		} else {
			deaths := (deficit-settlement.surplus)
			settlement.surplus = 0
			settlement.population -= int(deaths)
			/* DEBUG("uncovered deficit,", int(deaths), "die") */
			// TODO: Managers don't die, only farmers
		}
	} else {
		collected := (A*m*x + B) * (1-math.exp(-surplus/(FUDGE*A*m*x + B)))
		/* DEBUG("coll", collected, "loss", int(100*(surplus-collected)/surplus), "%") */

		settlement.surplus += collected
		growth_percent := rand.float32_normal(GROWTH_RATE_MEAN, GROWTH_RATE_SD) / 100
		/* DEBUG("Growth %", growth_percent*100) */
		new_pop := int(f32(settlement.population)*(1+growth_percent))
		settlement.population = new_pop

		m2 := m+0.01
		f2 := f-0.01
		hypo_surp := (N*f2*x) - x
		hypo_coll := (A*m2*x + B) * (1-math.exp(-hypo_surp/(FUDGE*A*m2*x + B)))
		if hypo_coll > collected {
			DEBUG("ASSIGNING MANAGERS, now", int(100*m2), "% managers", int(f32(settlement.population)*m2), "total")
			settlement.job_allocation[.Farmer] = f2
			settlement.job_allocation[.Manager] = m2
		}

		if m > 0 {
			m3 := m-0.01
			f3 := f+0.01
			hypo_surp := (N*f3*x) - x
			hypo_coll := (A*m3*x + B) * (1-math.exp(-hypo_surp/(FUDGE*A*m3*x + B)))
			if hypo_coll > collected {
				DEBUG("DEASSIGNING MANAGERS, now", int(100*m3), "% managers", int(f32(settlement.population)*m3), "total")
				settlement.job_allocation[.Farmer] = f3
				settlement.job_allocation[.Manager] = m3
			}
		}

		DEBUG("p", int(settlement.population), "s", int(surplus), "M+1% delta", int(100*(hypo_coll-collected)/collected), "%")
	}

	/* DEBUG("new pop", settlement.population, "new surp", int(settlement.surplus), "coverage", int(f32(settlement.surplus)/f32(settlement.population)*100),"%") */
}
