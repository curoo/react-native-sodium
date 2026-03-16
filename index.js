/**
 * @providesModule Sodium
 * @flow
 */

import { NativeModules } from 'react-native'

export default NativeModules.Sodium || NativeModules.RCTSodium;
