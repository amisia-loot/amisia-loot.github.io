// A cut of wowsims/forever ui/specs/priest/dps/presets.ts (MIT) for tools/tests/test_wowsims_weights.py.
import * as PresetUtils from '@app/preset_utils';
import { Stat } from '@generated/proto/common';
import { Stats } from '@sim/proto/stats';

export const ShadowEpWeights = PresetUtils.makePresetEpWeights(
	'Shadow',
	Stats.fromMap({
		[Stat.StatIntellect]: 0.24,
		[Stat.StatSpellDamage]: 1.0,
		[Stat.StatShadowDamage]: 1.0,
		[Stat.StatSpirit]: 0.01,
		[Stat.StatHitRating]: 1.14,
		[Stat.StatCritRating]: 0.84,
		[Stat.StatHasteRating]: 0.73,
	}),
);

// a preset the tool does not know by name: left out with a log line
export const OtherEpWeights = PresetUtils.makePresetEpWeights('Mind Flay Only', Stats.fromMap({ [Stat.StatIntellect]: 1 }));

export const SmiteEpWeights = PresetUtils.makePresetEpWeights(
	'Smite',
	Stats.fromMap({
		[Stat.StatIntellect]: 0.58,
		[Stat.StatSpellDamage]: 1.0,
		[Stat.StatHolyDamage]: 0.81,
		[Stat.StatMP5]: 1.46,
		[Stat.StatFancyNewStat]: 2,
		[Stat.StatArmorPenetration]: 0.1,
	}),
);
