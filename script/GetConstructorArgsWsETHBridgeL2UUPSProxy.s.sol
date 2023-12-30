// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {WstETHBridgeL2} from "src/WstETHBridgeL2.sol";

import {UUPSProxy} from "./UUPSProxy.sol";
import {ICREATE3Factory} from "./ICREATE3Factory.sol";

contract GetConstructorArgsWsETHBridgeL2UUPSProxy is Script {
  address deployerAddress = 0x17C8acE2dBa0d3060a7400B5AF79094a714d1537;
  address adminAddress = 0x2be7b3e7b9BFfbB38B85f563f88A34d84Dc99c9f;
  address emergencyRoleAddress = 0x2be7b3e7b9BFfbB38B85f563f88A34d84Dc99c9f;
  address polygonZkEVMBridgeAddress =
    0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe;
  address originTokenAddress = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

  address wrappedTokenAddress;
  address counterpartContract;

  uint32 counterpartNetwork = 0; // zkEVM -> Ethereum

  // CREATE3 Factory
  ICREATE3Factory factory =
    ICREATE3Factory(0x93FEC2C00BfE902F733B57c5a6CeeD7CD1384AE1);

  function setUp() public {
    wrappedTokenAddress =
      factory.getDeployed(deployerAddress, keccak256(bytes("WstETHWrapped")));
    counterpartContract =
      factory.getDeployed(deployerAddress, keccak256(bytes("WstETHBridgeL1")));
  }

  function run() public view {
    bytes memory data = abi.encodeWithSelector(
      WstETHBridgeL2.initialize.selector,
      adminAddress,
      emergencyRoleAddress,
      wrappedTokenAddress,
      originTokenAddress,
      polygonZkEVMBridgeAddress,
      counterpartContract,
      counterpartNetwork
    );
    bytes memory args =
      abi.encode(0x18FED1E19dC564DC917D203be9d40790472D22e9, data);
    console.logBytes(args);
  }
}
