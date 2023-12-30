// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Script.sol";

import {WstETHWrapped} from "src/WstETHWrapped.sol";

import {UUPSProxy} from "./UUPSProxy.sol";
import {ICREATE3Factory} from "./ICREATE3Factory.sol";

/**
 * @title DeployWstETHWrapped
 * @author sepyke.eth
 * @notice Script to deploy WstETHWrapped
 */
contract DeployWstETHWrapped is Script {
  address deployerAddress = 0x17C8acE2dBa0d3060a7400B5AF79094a714d1537;
  address adminAddress = 0x2be7b3e7b9BFfbB38B85f563f88A34d84Dc99c9f;
  address emergencyRoleAddress = 0x2be7b3e7b9BFfbB38B85f563f88A34d84Dc99c9f;
  address wstETHBridgeAddress = 0xDB5D9c10FD2a92692DB51853e06058EE0436d69B;

  // CREATE3 Factory
  ICREATE3Factory factory =
    ICREATE3Factory(0x93FEC2C00BfE902F733B57c5a6CeeD7CD1384AE1);

  function run() public returns (address proxy) {
    uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

    vm.startBroadcast(deployerPrivateKey);

    WstETHWrapped wstETHWrapped = new WstETHWrapped();
    bytes memory data = abi.encodeWithSelector(
      WstETHWrapped.initialize.selector,
      adminAddress,
      emergencyRoleAddress,
      wstETHBridgeAddress
    );
    bytes32 salt = keccak256(bytes("WstETHWrapped"));
    bytes memory creationCode = abi.encodePacked(
      type(UUPSProxy).creationCode, abi.encode(address(wstETHWrapped), data)
    );
    proxy = factory.deploy(salt, creationCode);

    vm.stopBroadcast();
  }
}
