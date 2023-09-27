// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "oz/token/ERC20/IERC20.sol";
import {SafeERC20} from "oz/token/ERC20/utils/SafeERC20.sol";

import {MainnetBridge} from "src/MainnetBridge.sol";
import {BridgeMock} from "./BridgeMock.sol";
import {UUPSProxy} from "./UUPSProxy.sol";

/**
 * @title MainnetBridgeV2Mock
 * @author sepyke.eth
 * @notice Mock contract to test upgradeability of MainnetBridge smart contract
 */
contract MainnetBridgeV2Mock is MainnetBridge {
  function _receiveTokens(uint256) internal view override whenNotPaused {
    require(false, "test new logic");
  }

  /// @dev Add new function for testing purpose
  function getToken() public view returns (address b) {
    b = address(originTokenAddress);
  }
}

/**
 * @title MainnetBridgeTest
 * @author sepyke.eth
 * @notice Unit tests for MainnetBridge
 */
contract MainnetBridgeTest is Test {
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

  MainnetBridge v1;
  MainnetBridge proxyV1;
  MainnetBridge mockedV1;
  MainnetBridge mockedProxyV1;
  MainnetBridgeV2Mock v2;
  MainnetBridgeV2Mock proxyV2;

  function setUp() public {
    uint256 mainnetFork = vm.createFork(ETH_RPC_URL);
    vm.selectFork(mainnetFork);

    v1 = new MainnetBridge();
    bytes memory v1Data = abi.encodeWithSelector(MainnetBridge.initialize.selector, admin, emergency, wsteth, bridgeAddress, l2Address, 1);
    UUPSProxy proxy = new UUPSProxy(address(v1), v1Data);
    proxyV1 = MainnetBridge(address(proxy));

    v2 = new MainnetBridgeV2Mock();
    proxyV2 = MainnetBridgeV2Mock(address(proxyV1));
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

  /// @notice Make sure MainnetBridge can interact with the bridge
  function testBridgeToken(uint256 bridgeAmount) public {
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

  /// @notice Make sure user can claim the DAI
  function testOnMessageReceivedValidMessage(uint256 bridgeAmount) public {
    vm.assume(bridgeAmount > 1 ether);
    vm.assume(bridgeAmount < 1_000_000_000 ether);

    vm.startPrank(alice);
    deal(wsteth, alice, bridgeAmount);
    IERC20(wsteth).safeApprove(address(proxyV1), bridgeAmount);
    proxyV1.bridgeToken(bob, bridgeAmount, false);
    vm.stopPrank();

    address currentBridgeAddress = address(proxyV1.polygonZkEVMBridge());
    address originAddress = proxyV1.counterpartContract();
    uint32 originNetwork = proxyV1.counterpartNetwork();
    bytes memory messageData = abi.encode(bob, bridgeAmount);

    vm.startPrank(currentBridgeAddress);
    proxyV1.onMessageReceived(originAddress, originNetwork, messageData);
    vm.stopPrank();

    assertEq(IERC20(wsteth).balanceOf(bob), bridgeAmount);
  }
}
