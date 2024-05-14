// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";

import {ICREATE3Factory} from "../src/interfaces/ICREATE3Factory.sol";
import {WstETHWrapped} from "../src/WstETHWrapped.sol";
import {WstETHWrappedUUPSProxy} from "../src/proxies/WstETHWrappedUUPSProxy.sol";

import {WstETHBridgeL2} from "../src/WstETHBridgeL2.sol";
import {WstETHBridgeL2UUPSProxy} from "../src/proxies/WstETHBridgeL2UUPSProxy.sol";

/**
 * @title WstETHBridgeL2V2Mock
 * @author sepyke.eth
 * @notice Mock contract to test upgradeability of WstETHBridgeL2
 */
contract WstETHBridgeL2V2Mock is WstETHBridgeL2 {
  uint256 public some;

  /// @dev Add new function for testing purpose
  function setValue(uint256 _some) public {
    some = _some;
  }

  /// @dev Add new function for testing purpose
  function getValue() public view returns (uint256 b) {
    b = some;
  }
}

/**
 * @title WstETHBridgeL2
 * @author sepyke.eth
 * @notice Unit tests for WstETHBridgeL2
 */
contract WstETHBridgeL2Test is Test {
  string ZKEVM_RPC_URL = vm.envString("ZKEVM_RPC_URL");

  ICREATE3Factory create3Factory = ICREATE3Factory(0x93FEC2C00BfE902F733B57c5a6CeeD7CD1384AE1);

  address deployer = vm.addr(0xC14C13);
  address admin = vm.addr(0xB453D);
  address emergency = vm.addr(0xD4DD1);
  address alice = vm.addr(0xA11CE);
  address bob = vm.addr(0xB0B);

  address polygonZkEVMBridge = 0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe;
  WstETHWrapped wrappedToken;
  WstETHBridgeL2 bridgeL2;

  function _getWstETHWrappedAddress() internal returns (address) {
    return create3Factory.getDeployed(deployer, keccak256(bytes("WstETHWrapped")));
  }

  function _getWstETHBridgeL2Address() internal returns (address) {
    return create3Factory.getDeployed(deployer, keccak256(bytes("WstETHBridgeL2")));
  }

  function _getWstETHBridgeL1Address() internal returns (address) {
    return create3Factory.getDeployed(deployer, keccak256(bytes("WstETHBridgeL1")));
  }

  function _deployWstETHWrapped() internal returns (WstETHWrapped token) {
    vm.startPrank(deployer);

    address wstETHBridgeAddress = _getWstETHBridgeL2Address();
    WstETHWrapped implementation = new WstETHWrapped();
    bytes memory data = abi.encodeWithSelector(WstETHWrapped.initialize.selector, admin, emergency, wstETHBridgeAddress);
    bytes32 salt = keccak256(bytes("WstETHWrapped"));
    bytes memory creationCode =
      abi.encodePacked(type(WstETHWrappedUUPSProxy).creationCode, abi.encode(address(implementation), data));
    address deployedAddress = create3Factory.deploy(salt, creationCode);
    token = WstETHWrapped(deployedAddress);

    vm.stopPrank();
  }

  function _deployWstETHBridgeL2() internal returns (WstETHBridgeL2 bridge) {
    vm.startPrank(deployer);

    address wstETHBridgeL1 = _getWstETHBridgeL1Address();
    address wrappedTokenAddress = _getWstETHWrappedAddress();
    uint32 counterpartNetwork = 0;
    WstETHBridgeL2 implementation = new WstETHBridgeL2();
    address originToken = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

    bytes memory data = abi.encodeWithSelector(
      WstETHBridgeL2.initialize.selector,
      admin,
      emergency,
      wrappedTokenAddress,
      originToken,
      polygonZkEVMBridge,
      wstETHBridgeL1,
      counterpartNetwork
    );
    bytes32 salt = keccak256(bytes("WstETHBridgeL2"));
    bytes memory creationCode =
      abi.encodePacked(type(WstETHBridgeL2UUPSProxy).creationCode, abi.encode(address(implementation), data));
    address deployedAddress = create3Factory.deploy(salt, creationCode);
    bridge = WstETHBridgeL2(deployedAddress);

    vm.stopPrank();
  }

  function setUp() public {
    uint256 zkEvmFork = vm.createFork(ZKEVM_RPC_URL);
    vm.selectFork(zkEvmFork);

    wrappedToken = _deployWstETHWrapped();
    bridgeL2 = _deployWstETHBridgeL2();
  }

  // ==========================================================================
  // == Upgradeability ========================================================
  // ==========================================================================

  /// @notice Upgrade as admin; make sure it works as expected
  function testUpgradeAsAdmin() public {
    // Deploy new implementation
    WstETHBridgeL2V2Mock v2 = new WstETHBridgeL2V2Mock();

    vm.startPrank(admin);
    bridgeL2.upgradeTo(address(v2));
    vm.stopPrank();

    WstETHBridgeL2V2Mock bridgeL2V2 = WstETHBridgeL2V2Mock(address(bridgeL2));
    bridgeL2V2.setValue(2);
    assertEq(bridgeL2V2.getValue(), 2);
  }

  /// @notice Upgrade as non-admin; make sure it reverted
  function testUpgradeAsNonAdmin() public {
    vm.startPrank(alice);
    vm.expectRevert(
      bytes(
        "AccessControl: account 0xe05fcc23807536bee418f142d19fa0d21bb0cff7 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
      )
    );
    bridgeL2.upgradeTo(vm.addr(2));
  }

  // ==========================================================================
  // == bridgeToken ===========================================================
  // ==========================================================================

  /// @notice Test bridge token as Alice
  function testBridgeToken() public {
    deal(address(wrappedToken), alice, 10 ether);

    vm.startPrank(alice);
    bridgeL2.bridgeToken(alice, 10 ether, true);
    vm.stopPrank();

    assertEq(wrappedToken.balanceOf(alice), 0);
  }

  // ==========================================================================
  // == Pausability ===========================================================
  // ==========================================================================

  /// @notice Make sure emergency role can pause the bridge
  function testPauseAsEmergencyRole() public {
    vm.startPrank(emergency);
    bridgeL2.pause();
    vm.stopPrank();

    deal(address(wrappedToken), alice, 10 ether);

    vm.startPrank(alice);
    vm.expectRevert("Pausable: paused");
    bridgeL2.bridgeToken(alice, 10 ether, true);
    vm.stopPrank();
  }

  /// @notice Make sure non emergency role cannot pause the bridge
  function testPauseAsNonEmergencyRole() public {
    vm.startPrank(alice);
    vm.expectRevert(
      bytes(
        "AccessControl: account 0xe05fcc23807536bee418f142d19fa0d21bb0cff7 is missing role 0xbf233dd2aafeb4d50879c4aa5c81e96d92f6e6945c906a58f9f2d1c1631b4b26"
      )
    );
    bridgeL2.pause();
    vm.stopPrank();
  }
}
