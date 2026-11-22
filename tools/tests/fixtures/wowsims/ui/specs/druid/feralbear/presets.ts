import * as PresetUtils from '@app/preset_utils';
import { BearEp, HybridEp } from '../feral_ep';

export const DefaultEp = BearEp;
export const DefaultEpWeights = PresetUtils.makePresetEpWeights('Bear', DefaultEp);
export const HybridEpWeights = PresetUtils.makePresetEpWeights('Hybrid', HybridEp);
