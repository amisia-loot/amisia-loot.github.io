import * as PresetUtils from '@app/preset_utils';
import { Phase } from '@app/constants/other';

import DefaultsJson from './defaults.siml';
import PreRaidArcaneGearJson from './gear_sets/preraid.gear.json';
import PreRaidFireGearJson from './gear_sets/preraidFire.gear.json';
import PreRaidFrostGearJson from './gear_sets/preraidFrost.gear.json';

export const PreRaidArcaneGear = PresetUtils.makePresetGear('Preraid', PreRaidArcaneGearJson, { group: 'Arcane', phase: Phase.Phase1 });
export const PreRaidFireGear = PresetUtils.makePresetGear('Preraid', PreRaidFireGearJson, { group: 'Fire', phase: Phase.Phase1 });
// the same items as the arcane set: left out, the first name kept
export const PreRaidFrostGear = PresetUtils.makePresetGear('Preraid', PreRaidFrostGearJson, { group: 'Frost', phase: Phase.Phase1 });
// no gear_sets file: left out
export const DefaultGear = PresetUtils.makePresetGear('Preraid', DefaultsJson.player.equipment, { group: 'Arcane' });
// no name in SET_NAMES: left out
export const OddGear = PresetUtils.makePresetGear('Odd', PreRaidFireGearJson);
