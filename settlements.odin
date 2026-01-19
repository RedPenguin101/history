package history

import "core:math/rand"
import "core:math"

GROWTH_RATE_MEAN :: 5 // percent
GROWTH_RATE_SD :: 3 // percent

SURP_COLLECT_PEN_COEFF :: 1.1

SURP_STORE_PEN_COEFF :: 1.05

Job :: enum
{
	Farmer, Manager,
}

Yield :: struct {
	job:Job, mean, sd:f32
}

Product :: enum
{
	Food,
	Wool,
	Cloth,
	Clothes,
}

// mean and standard deviation of item produced by 1 individual
yields := [Product]Yield {
	.Food = {.Farmer, 1.02, 0.04}, // output measured in fed-person/year
	.Wool = {.Farmer, 0.1, 0.001},
	.Cloth = {.Farmer, 0, 0},
	.Clothes = {.Farmer, 0, 0},
}

Settlement :: struct
{
	population:int,
	job_allocation:[Job]f32,
	inventory:[Product]f32,
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
	collection_amount :: proc(available, max_collectable: f32) -> f32
	{
		return max_collectable * (1 - math.exp(- available / max_collectable))
	}

	max_collectable :: proc(managers:f32) -> f32
	{
		return BASE_COLL_MAX + managers*XTRA_COLL_PER_MGR
	}

	settlement := &global.settlements[idx]
	population := f32(settlement.population)
	farmers := population * settlement.job_allocation[.Farmer]
	managers := population * settlement.job_allocation[.Manager]
	yield : f32
	collected : f32

	{
		// SEC: Food production and collection

		yield_mean := yields[.Food].mean
		yield_sd := yields[.Food].sd
		yield = rand.float32_normal(yield_mean, yield_sd)

		produced := farmers * yield
		surplus := produced - population
		is_deficit := surplus < 1

		if is_deficit {
			// TODO: shrink managers on deaths? They shrink proportionally anyway, maybe it's OK
			// TODO: managers make the distribution of surplus more effective
			deficit := -surplus
			deaths:f32 = 0
			if settlement.inventory[.Food] > deficit {
				settlement.inventory[.Food] -= deficit
			} else {
				deaths = (deficit-settlement.inventory[.Food])
				settlement.inventory[.Food] = 0
				settlement.population -= int(deaths)
				/* TODO: Managers don't die, only farmers */
			}
			/* printfln("Mng: %4d\t Pop: %d\t Surp: %4d (%4d)\t DEFICIT deaths %d", */
			/* int(managers), int(population), int(surplus), int(settlement.surplus), int(deaths)) */
		} else {
			b := max_collectable(managers)
			collected = collection_amount(surplus, b)

			settlement.inventory[.Food] += collected
			growth_percent := rand.float32_normal(GROWTH_RATE_MEAN, GROWTH_RATE_SD) / 100
			net_births := population * growth_percent

			settlement.population += int(net_births)
			settlement.job_allocation[.Farmer] = (farmers+net_births)/(population+net_births)
			settlement.job_allocation[.Manager] = (managers)/(population+net_births)
		}
	}

	{
		// SEC: Manager Adjustment calculation
		M_ADJUST_DELTA :: 0.001

		m_delta := population * M_ADJUST_DELTA
		farmers -= m_delta
		managers += m_delta
		b := max_collectable(managers)
		produced := farmers * yield
		surplus := produced - population

		new_collected := collection_amount(surplus, b)
		if int(m_delta) >= 1 && new_collected > collected {
			settlement.job_allocation[.Manager] += M_ADJUST_DELTA
			settlement.job_allocation[.Farmer] -= M_ADJUST_DELTA
		}
	}
}
