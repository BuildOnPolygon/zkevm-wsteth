// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Script.sol";

import {NativeConverter} from "src/NativeConverter.sol";
import {WstETHWrappedV2} from "src/WstETHWrappedV2.sol";

import {ICREATE3Factory} from "./ICREATE3Factory.sol";
import {UUPSProxy} from "./UUPSProxy.sol";

// forge script script/DeployNativeConverter.s.sol:DeployNativeConverter --rpc-url ... -vvvvv --verify
contract DeployNativeConverter is Script {
  address internal constant _ADMIN = 0x2be7b3e7b9BFfbB38B85f563f88A34d84Dc99c9f;
  address internal constant _PAUSER = 0x2be7b3e7b9BFfbB38B85f563f88A34d84Dc99c9f;
  address internal constant _MIGRATOR = 0x2be7b3e7b9BFfbB38B85f563f88A34d84Dc99c9f;
  address internal constant _BRIDGE = 0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe;
  uint32 internal constant _L1_NETWORK_ID = 0;
  address internal constant _L1_ESCROW = 0xf0CDE1E7F0FAD79771cd526b1Eb0A12F69582C01;
  address internal constant _L2_BW_WSTETH = 0x5D8cfF95D7A57c0BF50B30b43c7CC0D52825D4a9;
  address internal constant _L2_WSTETH_WRAPPED = 0xbf6De60Ccd9D22a5820A658fbE9fc87975EA204f;

  function run() external {
    // deploy and init native converter
    vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));
    NativeConverter nc = new NativeConverter();
    bytes memory ncInitData = abi.encodeWithSelector(
      NativeConverter.initialize.selector,
      _ADMIN,
      _PAUSER,
      _MIGRATOR,
      _BRIDGE,
      _L1_NETWORK_ID,
      _L1_ESCROW,
      _L2_BW_WSTETH,
      _L2_WSTETH_WRAPPED
    );
    bytes32 salt = keccak256(bytes("WstEthNativeConverter"));
    bytes memory proxyCreationCode = abi.encodePacked(type(UUPSProxy).creationCode, abi.encode(address(nc), ncInitData));
    ICREATE3Factory(0x93FEC2C00BfE902F733B57c5a6CeeD7CD1384AE1).deploy(salt, proxyCreationCode);
    vm.stopBroadcast();
  }
}
