// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {WstETHWrapped} from "src/WstETHWrapped.sol";

contract GetConstructorArgsWsETHWrappedUUPSProxy is Script {
  address deployerAddress = 0x17C8acE2dBa0d3060a7400B5AF79094a714d1537;
  address adminAddress = 0x2be7b3e7b9BFfbB38B85f563f88A34d84Dc99c9f;
  address emergencyRoleAddress = 0x2be7b3e7b9BFfbB38B85f563f88A34d84Dc99c9f;
  address wstETHBridgeAddress = 0xDB5D9c10FD2a92692DB51853e06058EE0436d69B;

  function run() public view {
    bytes memory data = abi.encodeWithSelector(
      WstETHWrapped.initialize.selector,
      adminAddress,
      emergencyRoleAddress,
      wstETHBridgeAddress
    );
    bytes memory args =
      abi.encode(0xF2400233954CA016882D1fe3C1aC07c10719d719, data);
    console.logBytes(args);
  }
}
