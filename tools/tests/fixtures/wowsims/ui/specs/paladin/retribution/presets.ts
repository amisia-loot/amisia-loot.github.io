import * as PresetUtils from '@app/preset_utils';
import { PseudoStat, Stat } from '@generated/proto/common';
import { Stats } from '@sim/proto/stats';

export const HolyShockEpWeights = PresetUtils.makePresetEpWeights(
	'Holy Shock',
	Stats.fromMap(
		{
			[Stat.StatStrength]: 2.5,
			[Stat.StatAttackPower]: 1,
			[Stat.StatHitRating]: 10.25,
		},
		{
			[PseudoStat.PseudoStatMainHandDps]: 13.04,
			[PseudoStat.PseudoStatSchoolHitPercentHoly]: 2.32 * Mechanics.HIT_RATING_PER_HIT_PERCENT,
		},
	),
);
