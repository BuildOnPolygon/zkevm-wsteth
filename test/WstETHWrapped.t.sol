// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";

import {ICREATE3Factory} from "../src/interfaces/ICREATE3Factory.sol";
import {WstETHWrapped} from "../src/WstETHWrapped.sol";
import {WstETHWrappedUUPSProxy} from "../src/proxies/WstETHWrappedUUPSProxy.sol";

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
 * @title WstETHWrapped
 * @author sepyke.eth
 * @notice Unit tests for WstETHWrapped
 */
contract WstETHWrappedTest is Test {
  string ZKEVM_RPC_URL = vm.envString("ZKEVM_RPC_URL");

  ICREATE3Factory create3Factory = ICREATE3Factory(0x93FEC2C00BfE902F733B57c5a6CeeD7CD1384AE1);

  address deployer = vm.addr(0xC14C13);
  address admin = vm.addr(0xB453D);
  address emergency = vm.addr(0xD4DD1);
  address alice = vm.addr(0xA11CE);
  address bob = vm.addr(0xB0B);
  address wstETHBridgeAddress;

  WstETHWrapped wrappedToken;

  function _getWstETHBridgeL2Address() internal returns (address) {
    return create3Factory.getDeployed(deployer, keccak256(bytes("WstETHBridgeL2")));
  }

  function _deployWstETHWrapped() internal returns (WstETHWrapped token) {
    vm.startPrank(deployer);

    wstETHBridgeAddress = _getWstETHBridgeL2Address();
    WstETHWrapped implementation = new WstETHWrapped();
    bytes memory data = abi.encodeWithSelector(WstETHWrapped.initialize.selector, admin, emergency, wstETHBridgeAddress);
    bytes32 salt = keccak256(bytes("WstETHWrapped"));
    bytes memory creationCode =
      abi.encodePacked(type(WstETHWrappedUUPSProxy).creationCode, abi.encode(address(implementation), data));
    address deployedAddress = create3Factory.deploy(salt, creationCode);
    token = WstETHWrapped(deployedAddress);

    vm.stopPrank();
  }

  function setUp() public {
    uint256 zkEvmFork = vm.createFork(ZKEVM_RPC_URL);
    vm.selectFork(zkEvmFork);

    wrappedToken = _deployWstETHWrapped();
  }

  // ==========================================================================
  // == Upgradeability ========================================================
  // ==========================================================================

  /// @notice Upgrade as admin; make sure it works as expected
  function testUpgradeAsAdmin() public {
    // Deploy new implementation
    WstETHWrappedV2Mock v2 = new WstETHWrappedV2Mock();

    vm.startPrank(admin);
    wrappedToken.upgradeTo(address(v2));
    vm.stopPrank();

    WstETHWrappedV2Mock wrappedTokenV2 = WstETHWrappedV2Mock(address(wrappedToken));
    wrappedTokenV2.setValue(2);
    assertEq(wrappedTokenV2.getValue(), 2);
  }

  /// @notice Upgrade as non-admin; make sure it reverted
  function testUpgradeAsNonAdmin() public {
    vm.startPrank(alice);
    vm.expectRevert(
      bytes(
        "AccessControl: account 0xe05fcc23807536bee418f142d19fa0d21bb0cff7 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
      )
    );
    wrappedToken.upgradeTo(vm.addr(2));
  }

  // ==========================================================================
  // == Pausability ===========================================================
  // ==========================================================================

  /// @notice Pause as emergency role; make sure it works as expected
  function testPauseAsEmergencyRole() public {
    vm.startPrank(emergency);
    wrappedToken.pause();
    vm.stopPrank();

    deal(address(wrappedToken), alice, 10 ether);
    vm.startPrank(alice);
    vm.expectRevert("Pausable: paused");
    wrappedToken.transfer(bob, 10 ether);

    assertTrue(wrappedToken.paused());
  }

  /// @notice Pause as non-emergency role; make sure it reverted
  function testPauseAsNonEmergencyRole() public {
    vm.startPrank(alice);
    vm.expectRevert(
      bytes(
        "AccessControl: account 0xe05fcc23807536bee418f142d19fa0d21bb0cff7 is missing role 0xbf233dd2aafeb4d50879c4aa5c81e96d92f6e6945c906a58f9f2d1c1631b4b26"
      )
    );
    wrappedToken.pause();
  }

  // ==========================================================================
  // == ERC-2612 ==============================================================
  // ==========================================================================

  /// @notice Make sure it support ERC-2612
  function testERC2612Compliant() public {
    assertEq(wrappedToken.nonces(alice), 0);
    assertTrue(wrappedToken.DOMAIN_SEPARATOR() != "");
  }

  // ==========================================================================
  // == Mint ==================================================================
  // ==========================================================================

  /// @notice Mint as bridge
  function testBridgeMintAsBridge() public {
    vm.startPrank(wstETHBridgeAddress);
    wrappedToken.bridgeMint(alice, 1 ether);
    vm.stopPrank();

    assertEq(wrappedToken.balanceOf(alice), 1 ether);
  }

  /// @notice Mint as non bridge
  function testBridgeMintAsNonBridge() public {
    vm.startPrank(alice);
    vm.expectRevert("CustomERC20Wrapped::onlyBridge: Not PolygonZkEVMBridge");
    wrappedToken.bridgeMint(alice, 1 ether);
  }

  // ==========================================================================
  // == Burn ==================================================================
  // ==========================================================================

  /// @notice Burn as bridge
  function testBridgeBurnAsBridge() public {
    vm.startPrank(wstETHBridgeAddress);
    wrappedToken.bridgeMint(alice, 1 ether);
    wrappedToken.bridgeBurn(alice, 1 ether);
    vm.stopPrank();

    assertEq(wrappedToken.balanceOf(alice), 0);
  }

  /// @notice Burn as non bridge
  function testBridgeBurnAsNonBridge() public {
    vm.startPrank(alice);
    vm.expectRevert("CustomERC20Wrapped::onlyBridge: Not PolygonZkEVMBridge");
    wrappedToken.bridgeBurn(alice, 1 ether);
  }
}
