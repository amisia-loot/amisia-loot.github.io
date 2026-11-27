import * as PresetUtils from '@app/preset_utils';

import PreBiSArmsGearJson from './gear_sets/prebis_arms.gear.siml';
import PreBiSFuryGearJson from './gear_sets/prebis_fury.gear.json';

const FURY_PRESET_OPTIONS = {
	group: 'Fury',
	onLoad: (player: Player<Spec.SpecDpsWarrior>) => {
		makeSpecChangeWarningToast([{ condition: isArmsSpec, message: 'Check your gear: a two-handed weapon.' }], player);
	},
};

export const PreBiSFuryGear = PresetUtils.makePresetGear('Pre-BiS', PreBiSFuryGearJson, FURY_PRESET_OPTIONS);
export const PreBiSArmsGear = PresetUtils.makePresetGear('Pre-BiS', PreBiSArmsGearJson, {
	group: 'Arms',
	tooltip: 'Pre-raid, with a two-hander.',
});
