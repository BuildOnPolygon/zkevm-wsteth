// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {NativeConverter} from "src/NativeConverter.sol";

// forge script script/Convert.s.sol:ConvertBwWstEthToWstEthV2 --rpc-url ... -vvvvv
contract ConvertBwWstEthToWstEthV2 is Script {
  function run() external {
    address bwWstEth = 0x5D8cfF95D7A57c0BF50B30b43c7CC0D52825D4a9;

    address ncAddr = 0x0000000000000000000000000000000000000000; // TODO: CHANGE THIS
    uint256 amount = 10 ** 15; // TODO: CHANGE THIS (0.001 bw WstETH)
    uint256 myPk = vm.envUint("TESTER_PRIVATE_KEY");
    address myAddr = vm.addr(myPk);

    vm.startBroadcast(myPk);
    NativeConverter nc = NativeConverter(ncAddr);
    IERC20(bwWstEth).approve(ncAddr, amount);
    nc.convert(myAddr, amount);
    vm.stopBroadcast();
  }
}
