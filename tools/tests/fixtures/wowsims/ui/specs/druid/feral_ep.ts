import { PseudoStat, Stat } from '@generated/proto/common';
import { Stats } from '@sim/proto/stats';

export const BearEp = Stats.fromMap(
	{
		[Stat.StatStamina]: 1.0028749432917183,
		[Stat.StatFeralAttackPower]: 0.22,
		[Stat.StatArmor]: 0.1743755390508764,
		[Stat.StatBonusArmor]: 0.17,
	},
	{
		[PseudoStat.PseudoStatMainHandDps]: 3.0930521753757847,
	},
);

export const CatEp = Stats.fromMap({ [Stat.StatAgility]: 1 });
const hybridCatFraction = 0.46;
export const HybridEp = CatEp.scale(hybridCatFraction).add(BearEp.scale(1 - hybridCatFraction));
