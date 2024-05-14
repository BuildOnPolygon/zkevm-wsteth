// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Script.sol";

import {WstETHBridgeL1} from "src/WstETHBridgeL1.sol";

import {UUPSProxy} from "./UUPSProxy.sol";
import {ICREATE3Factory} from "./ICREATE3Factory.sol";

/**
 * @title DeployWstETHBridgeL1
 * @author sepyke.eth
 * @notice Script to deploy WstETHBridgeL1
 */
contract DeployWstETHBridgeL1 is Script {
  address deployerAddress = 0x17C8acE2dBa0d3060a7400B5AF79094a714d1537;
  address adminAddress = 0xf694C9e3a34f5Fa48b6f3a0Ff186C1c6c4FcE904;
  address emergencyRoleAddress = 0xf694C9e3a34f5Fa48b6f3a0Ff186C1c6c4FcE904;
  address originTokenAddress = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
  address polygonZkEVMBridgeAddress = 0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe;

  address wrappedTokenAddress;
  address counterpartContract;

  uint32 counterpartNetwork = 1; // Ethereum -> zkEVM

  // CREATE3 Factory
  ICREATE3Factory factory = ICREATE3Factory(0x93FEC2C00BfE902F733B57c5a6CeeD7CD1384AE1);

  function setUp() public {
    wrappedTokenAddress = factory.getDeployed(deployerAddress, keccak256(bytes("WstETHWrapped")));
    counterpartContract = factory.getDeployed(deployerAddress, keccak256(bytes("WstETHBridgeL2")));
  }

  function run() public returns (address proxy) {
    uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

    vm.startBroadcast(deployerPrivateKey);

    WstETHBridgeL1 wstETHBridgeL1 = new WstETHBridgeL1();
    bytes memory data = abi.encodeWithSelector(
      WstETHBridgeL1.initialize.selector,
      adminAddress,
      emergencyRoleAddress,
      wrappedTokenAddress,
      originTokenAddress,
      polygonZkEVMBridgeAddress,
      counterpartContract,
      counterpartNetwork
    );
    bytes32 salt = keccak256(bytes("WstETHBridgeL1"));
    bytes memory creationCode =
      abi.encodePacked(type(UUPSProxy).creationCode, abi.encode(address(wstETHBridgeL1), data));
    proxy = factory.deploy(salt, creationCode);

    vm.stopBroadcast();
  }
}
