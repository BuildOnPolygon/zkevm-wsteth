pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "oz/token/ERC20/IERC20.sol";

import {WstETHBridgeL1} from "src/WstETHBridgeL1.sol";
import {WstETHBridgeL1UUPSProxy} from "src/proxies/WstETHBridgeL1UUPSProxy.sol";

import {WstETHBridgeL2} from "src/WstETHBridgeL2.sol";
import {WstETHBridgeL2UUPSProxy} from "src/proxies/WstETHBridgeL2UUPSProxy.sol";

import {NativeConverter} from "src/NativeConverter.sol";
import {NativeConverterUUPSProxy} from "src/proxies/NativeConverterUUPSProxy.sol";

import {WstETHWrapped} from "src/WstETHWrapped.sol";
import {WstETHWrappedV2} from "src/WstETHWrappedV2.sol";
import {WstETHWrappedUUPSProxy} from "src/proxies/WstETHWrappedUUPSProxy.sol";

import {IAccessControlUpgradeable} from "upgradeable/access/IAccessControlUpgradeable.sol";
import {ICREATE3Factory} from "src/interfaces/ICREATE3Factory.sol";

contract TestGrantRevokeRoles is Test {
  ICREATE3Factory _create3Factory = ICREATE3Factory(0x93FEC2C00BfE902F733B57c5a6CeeD7CD1384AE1);

  address _bridge = 0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe;
  address _deployer = vm.addr(0xC14C13);
  address _admin = vm.addr(0xB453D);
  address _emergency = vm.addr(0xD4DD1);
  address _nonMinter = vm.addr(0xB0B);
  address _joe = address(4);
  uint32 _l1NetworkId = 0;
  uint32 _l2NetworkId = 1;
  address _migrator = vm.addr(0xEEEEE);
  address _l1Escrow = address(5);
  IERC20 _bwWstETH = IERC20(0x5D8cfF95D7A57c0BF50B30b43c7CC0D52825D4a9);
  IERC20 _originToken = IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);

  bytes32 _emergencyRole = keccak256("EMERGENCY_ROLE");

  function testAdminCanGrantRevokeWstEthWrapped() external {
    // deploy the wsteth impl+proxy
    vm.selectFork(vm.createFork(vm.envString("ZKEVM_RPC_URL")));
    vm.startPrank(_deployer);
    WstETHWrapped _wstEthV2 = (
      WstETHWrappedV2(
        address(
          new WstETHWrappedUUPSProxy(
            address(new WstETHWrappedV2()), // impl
            abi.encodeWithSelector( // init data
            WstETHWrapped.initialize.selector, _admin, _emergency, _joe)
          )
        )
      )
    );
    vm.stopPrank();

    // pre-check: not a pauser
    vm.expectRevert(
      "AccessControl: account 0x0000000000000000000000000000000000000004 is missing role 0xbf233dd2aafeb4d50879c4aa5c81e96d92f6e6945c906a58f9f2d1c1631b4b26"
    );
    vm.startPrank(_joe);
    _wstEthV2.pause();
    vm.stopPrank();

    // grant emergency role
    vm.startPrank(_admin);
    _wstEthV2.grantRole(_emergencyRole, _joe);
    vm.stopPrank();

    // can pause now
    vm.startPrank(_joe);
    _wstEthV2.pause();
    vm.stopPrank();

    // revoke emergency role
    vm.startPrank(_admin);
    _wstEthV2.revokeRole(_emergencyRole, _joe);
    vm.stopPrank();

    // no longer a pauser
    vm.expectRevert(
      "AccessControl: account 0x0000000000000000000000000000000000000004 is missing role 0xbf233dd2aafeb4d50879c4aa5c81e96d92f6e6945c906a58f9f2d1c1631b4b26"
    );
    vm.startPrank(_joe);
    _wstEthV2.pause();
    vm.stopPrank();
  }

  function testAdminCanGrantRevokeNativeConverter() external {
    vm.selectFork(vm.createFork(vm.envString("ZKEVM_RPC_URL")));
    vm.startPrank(_deployer);
    // deploy the wsteth impl+proxy
    WstETHWrapped _wstEthV2 = (
      WstETHWrappedV2(
        address(
          new WstETHWrappedUUPSProxy(
            address(new WstETHWrappedV2()), // impl
            abi.encodeWithSelector( // init data
            WstETHWrapped.initialize.selector, _admin, _emergency, _joe)
          )
        )
      )
    );

    // deploy the nc impl+proxy
    NativeConverter _nativeConverter = NativeConverter(
      address(
        new NativeConverterUUPSProxy(
          address(new NativeConverter()),
          abi.encodeWithSelector(
            NativeConverter.initialize.selector,
            _admin,
            _emergency,
            _migrator,
            _bridge,
            _l1NetworkId,
            _l1Escrow,
            address(_bwWstETH),
            address(_wstEthV2)
          )
        )
      )
    );
    vm.stopPrank();

    // pre-check: not a pauser
    vm.expectRevert(
      "AccessControl: account 0x0000000000000000000000000000000000000004 is missing role 0xbf233dd2aafeb4d50879c4aa5c81e96d92f6e6945c906a58f9f2d1c1631b4b26"
    );
    vm.startPrank(_joe);
    _nativeConverter.pause();
    vm.stopPrank();

    // grant emergency role
    vm.startPrank(_admin);
    _nativeConverter.grantRole(_emergencyRole, _joe);
    vm.stopPrank();

    // can pause now
    vm.startPrank(_joe);
    _nativeConverter.pause();
    vm.stopPrank();

    // revoke emergency role
    vm.startPrank(_admin);
    _nativeConverter.revokeRole(_emergencyRole, _joe);
    vm.stopPrank();

    // no longer a pauser
    vm.expectRevert(
      "AccessControl: account 0x0000000000000000000000000000000000000004 is missing role 0xbf233dd2aafeb4d50879c4aa5c81e96d92f6e6945c906a58f9f2d1c1631b4b26"
    );
    vm.startPrank(_joe);
    _nativeConverter.pause();
    vm.stopPrank();
  }

  function testAdminCanGrantRevokeWstETHBridgeL1() external {
    vm.selectFork(vm.createFork(vm.envString("ETH_RPC_URL")));
    vm.startPrank(_deployer);
    WstETHBridgeL1 implementation = new WstETHBridgeL1();
    bytes memory data = abi.encodeWithSelector(
      WstETHBridgeL1.initialize.selector,
      _admin,
      _emergency,
      _create3Factory.getDeployed(_deployer, keccak256(bytes("WstETHWrapped"))),
      _originToken,
      _bridge,
      _create3Factory.getDeployed(_deployer, keccak256(bytes("WstETHBridgeL2"))),
      _l2NetworkId
    );
    bytes32 salt = keccak256(bytes("WstETHBridgeL1"));
    bytes memory creationCode =
      abi.encodePacked(type(WstETHBridgeL1UUPSProxy).creationCode, abi.encode(address(implementation), data));
    WstETHBridgeL1 _bridgeL1 = WstETHBridgeL1(_create3Factory.deploy(salt, creationCode));
    vm.stopPrank();

    // pre-check: not a pauser
    vm.expectRevert(
      "AccessControl: account 0x0000000000000000000000000000000000000004 is missing role 0xbf233dd2aafeb4d50879c4aa5c81e96d92f6e6945c906a58f9f2d1c1631b4b26"
    );
    vm.startPrank(_joe);
    _bridgeL1.pause();
    vm.stopPrank();

    // grant emergency role
    vm.startPrank(_admin);
    _bridgeL1.grantRole(_emergencyRole, _joe);
    vm.stopPrank();

    // can pause now
    vm.startPrank(_joe);
    _bridgeL1.pause();
    vm.stopPrank();

    // revoke emergency role
    vm.startPrank(_admin);
    _bridgeL1.revokeRole(_emergencyRole, _joe);
    vm.stopPrank();

    // no longer a pauser
    vm.expectRevert(
      "AccessControl: account 0x0000000000000000000000000000000000000004 is missing role 0xbf233dd2aafeb4d50879c4aa5c81e96d92f6e6945c906a58f9f2d1c1631b4b26"
    );
    vm.startPrank(_joe);
    _bridgeL1.pause();
    vm.stopPrank();
  }

  function testAdminCanGrantRevokeWstETHBridgeL2() external {
    vm.selectFork(vm.createFork(vm.envString("ZKEVM_RPC_URL")));
    vm.startPrank(_deployer);
    WstETHBridgeL2 implementation = new WstETHBridgeL2();
    bytes memory data = abi.encodeWithSelector(
      WstETHBridgeL2.initialize.selector,
      _admin,
      _emergency,
      _create3Factory.getDeployed(_deployer, keccak256(bytes("WstETHWrapped"))),
      _originToken,
      _bridge,
      _create3Factory.getDeployed(_deployer, keccak256(bytes("WstETHBridgeL1"))),
      _l1NetworkId
    );
    bytes32 salt = keccak256(bytes("WstETHBridgeL2"));
    bytes memory creationCode =
      abi.encodePacked(type(WstETHBridgeL2UUPSProxy).creationCode, abi.encode(address(implementation), data));
    WstETHBridgeL2 _bridgeL2 = WstETHBridgeL2(_create3Factory.deploy(salt, creationCode));
    vm.stopPrank();

    // pre-check: not a pauser
    vm.expectRevert(
      "AccessControl: account 0x0000000000000000000000000000000000000004 is missing role 0xbf233dd2aafeb4d50879c4aa5c81e96d92f6e6945c906a58f9f2d1c1631b4b26"
    );
    vm.startPrank(_joe);
    _bridgeL2.pause();
    vm.stopPrank();

    // grant emergency role
    vm.startPrank(_admin);
    _bridgeL2.grantRole(_emergencyRole, _joe);
    vm.stopPrank();

    // can pause now
    vm.startPrank(_joe);
    _bridgeL2.pause();
    vm.stopPrank();

    // revoke emergency role
    vm.startPrank(_admin);
    _bridgeL2.revokeRole(_emergencyRole, _joe);
    vm.stopPrank();

    // no longer a pauser
    vm.expectRevert(
      "AccessControl: account 0x0000000000000000000000000000000000000004 is missing role 0xbf233dd2aafeb4d50879c4aa5c81e96d92f6e6945c906a58f9f2d1c1631b4b26"
    );
    vm.startPrank(_joe);
    _bridgeL2.pause();
    vm.stopPrank();
  }
}
