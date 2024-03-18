// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import {UUPSUpgradeable} from "upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {WstETHWrappedV2} from "src/WstETHWrappedV2.sol";

// forge script script/UpgradeToWstETHWrappedV2.s.sol:DeployAndUpgradeV2 --rpc-url ... -vvvvv --verify
contract DeployAndUpgradeV2 is Script {
  address internal constant _L2_WSTETH_WRAPPED_PROXY = 0xbf6De60Ccd9D22a5820A658fbE9fc87975EA204f;

  function run() external {
    vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));

    WstETHWrappedV2 v2 = new WstETHWrappedV2(); // deploy new implementation
    UUPSUpgradeable proxy = UUPSUpgradeable(_L2_WSTETH_WRAPPED_PROXY); // get proxy
    proxy.upgradeTo(address(v2)); // upgrade proxy to new implementation

    vm.stopBroadcast();
  }
}
