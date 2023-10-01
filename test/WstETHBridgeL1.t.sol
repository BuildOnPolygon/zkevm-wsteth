// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "oz/token/ERC20/IERC20.sol";
import {ICREATE3Factory} from "../src/interfaces/ICREATE3Factory.sol";

import {WstETHBridgeL1} from "../src/WstETHBridgeL1.sol";
import {WstETHBridgeL1UUPSProxy} from
  "../src/proxies/WstETHBridgeL1UUPSProxy.sol";

/**
 * @title WstETHBridgeL1V2Mock
 * @author sepyke.eth
 * @notice Mock contract to test upgradeability of WstETHBridgeL1
 */
contract WstETHBridgeL1V2Mock is WstETHBridgeL1 {
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
 * @title WstETHBridgeL1
 * @author sepyke.eth
 * @notice Unit tests for WstETHBridgeL1
 */
contract WstETHBridgeL1Test is Test {
  string ETH_RPC_URL = vm.envString("ETH_RPC_URL");

  ICREATE3Factory create3Factory =
    ICREATE3Factory(0x93FEC2C00BfE902F733B57c5a6CeeD7CD1384AE1);

  address deployer = vm.addr(0xC14C13);
  address admin = vm.addr(0xB453D);
  address emergency = vm.addr(0xD4DD1);
  address alice = vm.addr(0xA11CE);
  address bob = vm.addr(0xB0B);
  IERC20 originToken = IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);

  WstETHBridgeL1 bridgeL1;

  function _getWstETHBridgeL2Address() internal returns (address) {
    return
      create3Factory.getDeployed(deployer, keccak256(bytes("WstETHBridgeL2")));
  }

  function _deployWstETHBridgeL1() internal returns (WstETHBridgeL1 bridge) {
    vm.startPrank(deployer);

    WstETHBridgeL1 implementation = new WstETHBridgeL1();

    address polygonZkEVMBridge = 0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe;
    address counterpartContract = _getWstETHBridgeL2Address();
    uint32 counterpartNetwork = 1;
    bytes memory data = abi.encodeWithSelector(
      WstETHBridgeL1.initialize.selector,
      admin,
      emergency,
      originToken,
      polygonZkEVMBridge,
      counterpartContract,
      counterpartNetwork
    );
    bytes32 salt = keccak256(bytes("WstETHBridgeL1"));
    bytes memory creationCode = abi.encodePacked(
      type(WstETHBridgeL1UUPSProxy).creationCode,
      abi.encode(address(implementation), data)
    );
    address deployedAddress = create3Factory.deploy(salt, creationCode);
    bridge = WstETHBridgeL1(deployedAddress);

    vm.stopPrank();
  }

  function setUp() public {
    uint256 ethFork = vm.createFork(ETH_RPC_URL);
    vm.selectFork(ethFork);

    bridgeL1 = _deployWstETHBridgeL1();
  }

  // ==========================================================================
  // == Upgradeability ========================================================
  // ==========================================================================

  /// @notice Upgrade as admin; make sure it works as expected
  function testUpgradeAsAdmin() public {
    // Deploy new implementation
    WstETHBridgeL1V2Mock v2 = new WstETHBridgeL1V2Mock();

    vm.startPrank(admin);
    bridgeL1.upgradeTo(address(v2));
    vm.stopPrank();

    WstETHBridgeL1V2Mock bridgeL1V2 = WstETHBridgeL1V2Mock(address(bridgeL1));
    bridgeL1V2.setValue(2);
    assertEq(bridgeL1V2.getValue(), 2);
  }

  /// @notice Upgrade as non-admin; make sure it reverted
  function testUpgradeAsNonAdmin() public {
    vm.startPrank(alice);
    vm.expectRevert(
      bytes(
        "AccessControl: account 0xe05fcc23807536bee418f142d19fa0d21bb0cff7 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
      )
    );
    bridgeL1.upgradeTo(vm.addr(2));
  }

  // ==========================================================================
  // == bridgeToken ===========================================================
  // ==========================================================================

  /// @notice Test bridge token as Alice
  function testBridgeToken() public {
    deal(address(originToken), alice, 10 ether);

    vm.startPrank(alice);
    originToken.approve(address(bridgeL1), 10 ether);
    bridgeL1.bridgeToken(alice, 10 ether, true);
    vm.stopPrank();

    assertEq(originToken.balanceOf(alice), 0);
  }

  // ==========================================================================
  // == Pausability ===========================================================
  // ==========================================================================

  /// @notice Make sure emergency role can pause the bridge
  function testPauseAsEmergencyRole() public {
    vm.startPrank(emergency);
    bridgeL1.pause();
    vm.stopPrank();

    deal(address(originToken), alice, 10 ether);

    vm.startPrank(alice);
    vm.expectRevert("Pausable: paused");
    bridgeL1.bridgeToken(alice, 10 ether, true);
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
    bridgeL1.pause();
    vm.stopPrank();
  }
}
