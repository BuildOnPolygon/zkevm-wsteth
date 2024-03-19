// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import {WstETHWrappedV2} from "src/WstETHWrappedV2.sol";

/*
forge script script/DeployWstETHWrappedV2.s.sol:DeployWstETHWrappedV2 \
  --rpc-url https://zkevm-rpc.com/ \
  --chain-id 1101 \
  --verify \
  --verifier etherscan \
  --etherscan-api-key ... \
  -vvvvv \
  --broadcast
*/
contract DeployWstETHWrappedV2 is Script {
  function run() external {
    vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));
    new WstETHWrappedV2(); // deploy new implementation
    vm.stopBroadcast();
  }
}
