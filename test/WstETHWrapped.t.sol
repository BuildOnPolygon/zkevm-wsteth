// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";

import {WstETHWrapped} from "../src/WstETHWrapped.sol";
import {WstETHWrappedUUPSProxy} from
  "../src/proxies/WstETHWrappedUUPSProxy.sol";

/**
 * @title WstETHV2Mock
 * @author sepyke.eth
 * @notice Mock contract to test upgradeability of WstETH smart contract
 */
contract WstETHWrappedV2Mock is WstETHWrapped {
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
 * @title WstETH
 * @author sepyke.eth
 * @notice Unit tests for WstETH
 */
contract WstETHTest is Test {
  string ZKEVM_RPC_URL = vm.envString("ZKEVM_RPC_URL");

  address admin = vm.addr(0xB453D);
  address emergency = vm.addr(0xD4DD1);
  address alice = vm.addr(0xA11CE);
  address bob = vm.addr(0xB0B);
  address wstETHBridgeNonNativeChain = vm.addr(0xB121D);

  WstETHWrapped v1;
  WstETHWrapped proxyV1;
  WstETHWrappedV2Mock v2;
  WstETHWrappedV2Mock proxyV2;

  function setUp() public {
    uint256 zkEvmFork = vm.createFork(ZKEVM_RPC_URL);
    vm.selectFork(zkEvmFork);

    v1 = new WstETHWrapped();
    bytes memory v1Data = abi.encodeWithSelector(
      WstETHWrapped.initialize.selector,
      admin,
      emergency,
      wstETHBridgeNonNativeChain
    );
    WstETHWrappedUUPSProxy proxy =
      new WstETHWrappedUUPSProxy(address(v1), v1Data);
    proxyV1 = WstETHWrapped(address(proxy));

    v2 = new WstETHWrappedV2Mock();
    proxyV2 = WstETHWrappedV2Mock(address(proxyV1));
  }

  // ==========================================================================
  // == Upgradeability ========================================================
  // ==========================================================================

  /// @notice Upgrade as admin; make sure it works as expected
  function testUpgradeAsAdmin() public {
    vm.startPrank(admin);
    proxyV1.upgradeTo(address(v2));
    vm.stopPrank();

    proxyV2.setValue(2);
    assertEq(proxyV2.getValue(), 2);
  }

  /// @notice Upgrade as non-admin; make sure it reverted
  function testUpgradeAsNonAdmin() public {
    vm.startPrank(alice);
    vm.expectRevert(
      bytes(
        "AccessControl: account 0xe05fcc23807536bee418f142d19fa0d21bb0cff7 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
      )
    );
    proxyV1.upgradeTo(address(v2));
  }

  // ==========================================================================
  // == Pausability ===========================================================
  // ==========================================================================

  /// @notice Pause as emergency role; make sure it works as expected
  function testPauseAsEmergencyRole() public {
    vm.startPrank(emergency);
    proxyV1.pause();
    vm.stopPrank();

    deal(address(proxyV1), alice, 10 ether);
    vm.startPrank(alice);
    vm.expectRevert("Pausable: paused");
    proxyV1.transfer(bob, 10 ether);

    assertTrue(proxyV1.paused());
  }

  /// @notice Pause as non-emergency role; make sure it reverted
  function testPauseAsNonEmergencyRole() public {
    vm.startPrank(alice);
    vm.expectRevert(
      bytes(
        "AccessControl: account 0xe05fcc23807536bee418f142d19fa0d21bb0cff7 is missing role 0xbf233dd2aafeb4d50879c4aa5c81e96d92f6e6945c906a58f9f2d1c1631b4b26"
      )
    );
    proxyV1.pause();
  }

  // ==========================================================================
  // == ERC-2612 ==============================================================
  // ==========================================================================

  /// @notice Make sure it support ERC-2612
  function testERC2612Compliant() public {
    assertEq(proxyV1.nonces(alice), 0);
    assertTrue(proxyV1.DOMAIN_SEPARATOR() != "");
  }
}
