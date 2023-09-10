// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "oz/token/ERC20/IERC20.sol";
import {SafeERC20} from "oz/token/ERC20/utils/SafeERC20.sol";

import {L1Escrow} from "src/L1Escrow.sol";
import {BridgeMock} from "./BridgeMock.sol";
import {UUPSProxy} from "./UUPSProxy.sol";

/**
 * @title L1EscrowV2Mock
 * @author sepyke.eth
 * @notice Mock contract to test upgradeability of L1Escrow smart contract
 */
contract L1EscrowV2Mock is L1Escrow {
  /// @dev Update bridgeToken logic for testing purpose
  function bridgeToken(address, uint256, bool) external pure override {
    require(false, "test new logic");
  }

  /// @dev Add new function for testing purpose
  function getToken() public view returns (address b) {
    b = address(wstETH);
  }
}

/**
 * @title L1EscrowTest
 * @author sepyke.eth
 * @notice Unit tests for L1Escrow
 */
contract L1EscrowTest is Test {
  using SafeERC20 for IERC20;

  string ETH_RPC_URL = vm.envString("ETH_RPC_URL");

  address void = address(0);
  address admin = vm.addr(0xB453D);
  address emergency = vm.addr(0xD4DD1);
  address alice = vm.addr(0xA11CE);
  address bob = vm.addr(0xB0B);
  address beneficiary = vm.addr(0xC001);

  address wsteth = address(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
  address bridgeAddress = address(0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe);
  address l2Address = address(4);

  L1Escrow v1;
  L1Escrow proxyV1;
  L1Escrow mockedV1;
  L1Escrow mockedProxyV1;
  L1EscrowV2Mock v2;
  L1EscrowV2Mock proxyV2;
  BridgeMock bridge;

  function setUp() public {
    uint256 mainnetFork = vm.createFork(ETH_RPC_URL);
    vm.selectFork(mainnetFork);

    v1 = new L1Escrow();
    bytes memory v1Data = abi.encodeWithSelector(
      L1Escrow.initialize.selector,
      admin,
      emergency,
      wsteth,
      bridgeAddress,
      1,
      l2Address
    );
    UUPSProxy proxy = new UUPSProxy(address(v1), v1Data);
    proxyV1 = L1Escrow(address(proxy));

    mockedV1 = new L1Escrow();
    bridge = new BridgeMock();
    bytes memory mockedV1Data = abi.encodeWithSelector(
      L1Escrow.initialize.selector,
      admin,
      emergency,
      wsteth,
      address(bridge),
      1,
      l2Address
    );
    UUPSProxy mockedProxy = new UUPSProxy(address(v1), mockedV1Data);
    mockedProxyV1 = L1Escrow(address(mockedProxy));
    v2 = new L1EscrowV2Mock();
    proxyV2 = L1EscrowV2Mock(address(proxyV1));
  }

  // ==========================================================================
  // == Upgradeability ========================================================
  // ==========================================================================

  /// @notice Upgrade as admin; make sure it works as expected
  function testUpgradeAsAdmin() public {
    vm.startPrank(admin);
    proxyV1.upgradeTo(address(v2));
    vm.expectRevert("test new logic");
    proxyV2.bridgeToken(alice, 1 ether, true);

    // Post-upgrade check
    // Make sure new function exists
    assertEq(proxyV2.getToken(), wsteth);
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
    IERC20(wsteth).safeApprove(address(proxyV1), 1 ether);
    vm.expectRevert(
      abi.encodeWithSelector(L1Escrow.BridgeAmountInvalid.selector)
    );
    proxyV1.bridgeToken(alice, 0, false);
  }

  /// @notice Make sure it revert if bridghe is paused
  function testBridgeWithPausedState() public {
    vm.startPrank(emergency);
    proxyV1.pause();
    vm.stopPrank();

    vm.startPrank(alice);
    IERC20(wsteth).safeApprove(address(proxyV1), 1 ether);
    vm.expectRevert(bytes("Pausable: paused"));
    proxyV1.bridgeToken(alice, 1 ether, false);
  }

  /// @notice Make sure L1Escrow submit correct message to the bridge
  function testBridgeWithMockedBridge(uint256 bridgeAmount) public {
    vm.assume(bridgeAmount > 1 ether);
    vm.assume(bridgeAmount < 1_000_000_000 ether);

    vm.startPrank(alice);
    deal(wsteth, alice, bridgeAmount);
    IERC20(wsteth).safeApprove(address(mockedProxyV1), bridgeAmount);
    mockedProxyV1.bridgeToken(alice, bridgeAmount, false);
    vm.stopPrank();

    assertEq(IERC20(wsteth).balanceOf(alice), 0);
    assertEq(IERC20(wsteth).balanceOf(address(mockedProxyV1)), bridgeAmount);

    assertEq(bridge.destId(), 1);
    assertEq(bridge.destAddress(), l2Address);
    assertEq(bridge.forceUpdateGlobalExitRoot(), false);
    assertEq(bridge.recipient(), alice);
    assertEq(bridge.amount(), bridgeAmount);
  }

  /// @notice Make sure L1Escrow can interact with the bridge
  function testBridgeWithRealBridge(uint256 bridgeAmount) public {
    vm.assume(bridgeAmount > 1 ether);
    vm.assume(bridgeAmount < 1_000_000_000 ether);

    vm.startPrank(alice);
    deal(wsteth, alice, bridgeAmount);
    IERC20(wsteth).safeApprove(address(proxyV1), bridgeAmount);
    proxyV1.bridgeToken(alice, bridgeAmount, false);
    vm.stopPrank();

    assertEq(IERC20(wsteth).balanceOf(alice), 0);
    assertEq(IERC20(wsteth).balanceOf(address(proxyV1)), bridgeAmount);
  }

  // ==========================================================================
  // == onMessageReceived =====================================================
  // ==========================================================================

  /// @notice Make sure to revert if message is invalid
  function testOnMessageReceivedInvalidMessage(uint256 bridgeAmount) public {
    vm.assume(bridgeAmount > 1 ether);
    vm.assume(bridgeAmount < 1_000_000_000 ether);

    vm.startPrank(alice);
    deal(wsteth, alice, bridgeAmount);
    IERC20(wsteth).safeApprove(address(proxyV1), bridgeAmount);
    proxyV1.bridgeToken(alice, bridgeAmount, false);
    vm.stopPrank();

    address currentBridgeAddress = address(proxyV1.zkEvmBridge());
    address originAddress = proxyV1.destAddress();
    uint32 originNetwork = proxyV1.destId();
    bytes memory metadata = abi.encode(bob, 1 ether);

    // Invalid caller
    vm.startPrank(bob);
    vm.expectRevert(abi.encodeWithSelector(L1Escrow.MessageInvalid.selector));
    proxyV1.onMessageReceived(originAddress, originNetwork, metadata);
    vm.stopPrank();

    // Valid caller; invalid origin address
    vm.startPrank(currentBridgeAddress);
    vm.expectRevert(abi.encodeWithSelector(L1Escrow.MessageInvalid.selector));
    proxyV1.onMessageReceived(address(0), originNetwork, metadata);
    vm.stopPrank();

    // Valid caller; invalid origin network
    vm.startPrank(currentBridgeAddress);
    vm.expectRevert(abi.encodeWithSelector(L1Escrow.MessageInvalid.selector));
    proxyV1.onMessageReceived(originAddress, 0, metadata);
    vm.stopPrank();

    // Valid caller; invalid metadata
    vm.startPrank(currentBridgeAddress);
    vm.expectRevert();
    proxyV1.onMessageReceived(originAddress, originNetwork, "");
    vm.stopPrank();
  }

  /// @notice Make sure user can claim the DAI
  function testOnMessageReceivedValidMessage(uint256 bridgeAmount) public {
    vm.assume(bridgeAmount > 1 ether);
    vm.assume(bridgeAmount < 1_000_000_000 ether);

    vm.startPrank(alice);
    deal(wsteth, alice, bridgeAmount);
    IERC20(wsteth).safeApprove(address(proxyV1), bridgeAmount);
    proxyV1.bridgeToken(bob, bridgeAmount, false);
    vm.stopPrank();

    address currentBridgeAddress = address(proxyV1.zkEvmBridge());
    address originAddress = proxyV1.destAddress();
    uint32 originNetwork = proxyV1.destId();
    bytes memory messageData = abi.encode(bob, bridgeAmount);

    vm.startPrank(currentBridgeAddress);
    proxyV1.onMessageReceived(originAddress, originNetwork, messageData);
    vm.stopPrank();

    assertEq(IERC20(wsteth).balanceOf(bob), bridgeAmount);
  }
}
