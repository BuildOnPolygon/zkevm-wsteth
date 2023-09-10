// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";

import {L2wstETH} from "src/L2wstETH.sol";

import {UUPSProxy} from "./UUPSProxy.sol";
import {BridgeMock} from "./BridgeMock.sol";

/**
 * @title L2wstETHV2Mock
 * @author sepyke.eth
 * @notice Mock contract to test upgradeability of L2wstETH smart contract
 */
contract L2wstETHV2Mock is L2wstETH {
  uint256 public some;

  /// @dev Update onMessageReceived implementation for testing purpose
  function onMessageReceived(address, uint32, bytes memory)
    external
    payable
    override
  {
    some = 42;
  }

  /// @dev Add new function for testing purpose
  function getValue() public view returns (uint256 b) {
    b = some;
  }
}

/**
 * @title L2wstETHTest
 * @author sepyke.eth
 * @notice Unit tests for L2wstETH
 */
contract L2wstETHTest is Test {
  string ZKEVM_RPC_URL = vm.envString("ZKEVM_RPC_URL");

  address admin = vm.addr(0xB453D);
  address emergency = vm.addr(0xD4DD1);
  address alice = vm.addr(0xA11CE);
  address bob = vm.addr(0xB0B);

  address bridgeAddress = address(0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe);
  address destAddress = address(4);
  uint32 destId = 0;

  L2wstETH v1;
  L2wstETH proxyV1;
  L2wstETHV2Mock v2;
  L2wstETHV2Mock proxyV2;
  L2wstETH mockedV1;
  L2wstETH mockedProxyV1;
  BridgeMock bridge;

  function setUp() public {
    uint256 zkEvmFork = vm.createFork(ZKEVM_RPC_URL);
    vm.selectFork(zkEvmFork);

    v1 = new L2wstETH();
    bytes memory v1Data = abi.encodeWithSelector(
      L2wstETH.initialize.selector,
      admin,
      emergency,
      bridgeAddress,
      destAddress,
      destId
    );
    UUPSProxy proxy = new UUPSProxy(address(v1), v1Data);
    proxyV1 = L2wstETH(address(proxy));

    mockedV1 = new L2wstETH();
    bridge = new BridgeMock();
    bytes memory v2Data = abi.encodeWithSelector(
      L2wstETH.initialize.selector,
      admin,
      emergency,
      address(bridge),
      destAddress,
      destId
    );
    UUPSProxy mockedProxy = new UUPSProxy(address(v1), v2Data);
    mockedProxyV1 = L2wstETH(address(mockedProxy));

    v2 = new L2wstETHV2Mock();
    proxyV2 = L2wstETHV2Mock(address(proxyV1));
  }

  // ==========================================================================
  // == Upgradeability ========================================================
  // ==========================================================================

  /// @notice Upgrade as owner; make sure it works as expected
  function testUpgradeAsAdmin() public {
    vm.startPrank(admin);
    proxyV1.upgradeTo(address(v2));
    vm.stopPrank();

    // Post-upgrade check
    proxyV2.onMessageReceived(address(0), 0, "");
    assertEq(proxyV2.getValue(), 42);
  }

  /// @notice Upgrade as non-owner; make sure it reverted
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

  /// @notice Make sure emergency role can pause
  function testPauseAsEmergencyRole() public {
    vm.startPrank(emergency);
    proxyV1.pause();
    assertTrue(proxyV1.paused());
    proxyV1.unpause();
    assertTrue(!proxyV1.paused());
  }

  /// @notice Make sure non emergency role cannot pause
  function testPauseAsNonEmergencyRole() public {
    vm.startPrank(alice);
    vm.expectRevert(
      bytes(
        "AccessControl: account 0xe05fcc23807536bee418f142d19fa0d21bb0cff7 is missing role 0xbf233dd2aafeb4d50879c4aa5c81e96d92f6e6945c906a58f9f2d1c1631b4b26"
      )
    );
    proxyV1.pause();
    vm.stopPrank();

    vm.startPrank(emergency);
    proxyV1.pause();
    vm.stopPrank();

    vm.startPrank(alice);
    vm.expectRevert(
      bytes(
        "AccessControl: account 0xe05fcc23807536bee418f142d19fa0d21bb0cff7 is missing role 0xbf233dd2aafeb4d50879c4aa5c81e96d92f6e6945c906a58f9f2d1c1631b4b26"
      )
    );
    proxyV1.unpause();
    vm.stopPrank();
  }

  // ==========================================================================
  // == bridge ================================================================
  // ==========================================================================

  /// @notice Make sure it revert if amount is invalid
  function testBridgeWithInvalidAmount() public {
    vm.startPrank(alice);
    vm.expectRevert(
      abi.encodeWithSelector(L2wstETH.BridgeAmountInvalid.selector)
    );
    proxyV1.bridgeToken(alice, 0, false);
  }

  /// @notice Make sure it revert if bridghe is paused
  function testBridgeWithPausedState() public {
    vm.startPrank(emergency);
    proxyV1.pause();
    vm.stopPrank();

    vm.startPrank(alice);
    vm.expectRevert(bytes("Pausable: paused"));
    proxyV1.bridgeToken(alice, 1 ether, false);
  }

  /// @notice Make sure L2wstETH submit correct message to the bridge
  function testBridgeWithMockedBridge(uint256 bridgeAmount) public {
    vm.assume(bridgeAmount > 1 ether);
    vm.assume(bridgeAmount < 1_000_000_000 ether);

    // Mint test NativeDAI
    vm.startPrank(address(bridge));
    bytes memory data = abi.encode(alice, bridgeAmount);
    mockedProxyV1.onMessageReceived(destAddress, destId, data);
    vm.stopPrank();

    vm.startPrank(alice);
    mockedProxyV1.bridgeToken(alice, bridgeAmount, false);
    vm.stopPrank();

    assertEq(mockedProxyV1.balanceOf(alice), 0);
    assertEq(mockedProxyV1.totalSupply(), 0);

    assertEq(bridge.destId(), 0);
    assertEq(bridge.destAddress(), destAddress);
    assertEq(bridge.forceUpdateGlobalExitRoot(), false);
    assertEq(bridge.recipient(), alice);
    assertEq(bridge.amount(), bridgeAmount);
  }

  /// @notice Make sure L2wstETH can interact with the bridge
  function testBridgeWithRealBridge(uint256 bridgeAmount) public {
    vm.assume(bridgeAmount > 1 ether);
    vm.assume(bridgeAmount < 1_000_000_000 ether);

    // Mint test NativeDAI
    vm.startPrank(bridgeAddress);
    bytes memory data = abi.encode(alice, bridgeAmount);
    proxyV1.onMessageReceived(destAddress, destId, data);
    vm.stopPrank();

    vm.startPrank(alice);
    proxyV1.bridgeToken(alice, bridgeAmount, false);
    vm.stopPrank();

    assertEq(proxyV1.balanceOf(alice), 0);
    assertEq(proxyV1.totalSupply(), 0);
  }

  // ==========================================================================
  // == onMessageReceived =====================================================
  // ==========================================================================

  /// @notice Make sure to revert if message is invalid
  function testOnMessageReceivedInvalidMessage(uint256 bridgeAmount) public {
    vm.assume(bridgeAmount > 1 ether);
    vm.assume(bridgeAmount < 1_000_000_000 ether);

    // Mint test NativeDAI
    vm.startPrank(bridgeAddress);
    bytes memory data = abi.encode(alice, bridgeAmount);
    proxyV1.onMessageReceived(destAddress, destId, data);
    vm.stopPrank();

    vm.startPrank(alice);
    proxyV1.bridgeToken(alice, bridgeAmount, false);
    vm.stopPrank();

    address currentBridgeAddress = address(proxyV1.zkEvmBridge());
    address originAddress = proxyV1.destAddress();
    uint32 originNetwork = proxyV1.destId();
    bytes memory metadata = abi.encode(bob, 1 ether);

    // Invalid caller
    vm.startPrank(bob);
    vm.expectRevert(abi.encodeWithSelector(L2wstETH.MessageInvalid.selector));
    proxyV1.onMessageReceived(originAddress, originNetwork, metadata);
    vm.stopPrank();

    // Valid caller; invalid origin address
    vm.startPrank(currentBridgeAddress);
    vm.expectRevert(abi.encodeWithSelector(L2wstETH.MessageInvalid.selector));
    proxyV1.onMessageReceived(address(0), originNetwork, metadata);
    vm.stopPrank();

    // Valid caller; invalid origin network
    vm.startPrank(currentBridgeAddress);
    vm.expectRevert(abi.encodeWithSelector(L2wstETH.MessageInvalid.selector));
    proxyV1.onMessageReceived(originAddress, 1, metadata);
    vm.stopPrank();

    // Valid caller; invalid metadata
    vm.startPrank(currentBridgeAddress);
    vm.expectRevert();
    proxyV1.onMessageReceived(originAddress, originNetwork, "");
    vm.stopPrank();
  }

  /// @notice Make sure user can claim the wstETH
  function testOnMessageReceivedValidMessage(uint256 bridgeAmount) public {
    vm.assume(bridgeAmount > 1 ether);
    vm.assume(bridgeAmount < 1_000_000_000 ether);

    // Mint test wstETH
    vm.startPrank(bridgeAddress);
    bytes memory data = abi.encode(alice, bridgeAmount);
    proxyV1.onMessageReceived(destAddress, destId, data);
    vm.stopPrank();

    vm.startPrank(alice);
    proxyV1.bridgeToken(bob, bridgeAmount, false);
    vm.stopPrank();

    address currentBridgeAddress = address(proxyV1.zkEvmBridge());
    address originAddress = proxyV1.destAddress();
    uint32 originNetwork = proxyV1.destId();
    bytes memory messageData = abi.encode(bob, bridgeAmount);

    vm.startPrank(currentBridgeAddress);
    proxyV1.onMessageReceived(originAddress, originNetwork, messageData);
    vm.stopPrank();

    assertEq(proxyV1.balanceOf(bob), bridgeAmount);
    assertEq(proxyV1.totalSupply(), bridgeAmount);
  }
}
