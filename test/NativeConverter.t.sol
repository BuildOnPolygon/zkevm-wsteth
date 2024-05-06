// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "oz/token/ERC20/IERC20.sol";

import {NativeConverter} from "../src/NativeConverter.sol";
import {WstETHWrapped} from "../src/WstETHWrapped.sol";
import {WstETHWrappedV2} from "../src/WstETHWrappedV2.sol";

import {NativeConverterUUPSProxy} from "../src/proxies/NativeConverterUUPSProxy.sol";
import {WstETHWrappedUUPSProxy} from "../src/proxies/WstETHWrappedUUPSProxy.sol";

contract NativeConverterTest is Test {
  address _bridge = 0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe;
  address _deployer = vm.addr(0xC14C13);
  address _admin = vm.addr(0xB453D);
  address _emergency = vm.addr(0xD4DD1);
  address _migrator = vm.addr(0xEEEEE);

  address _alice = vm.addr(0xA11CE);
  address _bob = vm.addr(0xB0B);
  address _l1Escrow = address(4);
  uint32 _l1NetworkId = 0;

  IERC20 _bwWstETH = IERC20(0x5D8cfF95D7A57c0BF50B30b43c7CC0D52825D4a9);
  WstETHWrappedV2 _nativeWstEthV2;
  NativeConverter _nativeConverter;

  function setUp() public {
    vm.selectFork(vm.createFork(vm.envString("ZKEVM_RPC_URL")));

    vm.startPrank(_deployer);

    // deploy WstETHV2
    _nativeWstEthV2 = WstETHWrappedV2(
      address(
        new WstETHWrappedUUPSProxy(
          address(new WstETHWrappedV2()), // impl
          abi.encodeWithSelector( // init data
          WstETHWrapped.initialize.selector, _admin, _emergency, _l1Escrow)
        )
      )
    );

    // deploy NativeConverter
    _nativeConverter = NativeConverter(
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
            address(_nativeWstEthV2)
          )
        )
      )
    );
    vm.stopPrank();

    // configure native converter to be a minter with 1B allowance
    vm.startPrank(_emergency);
    _nativeWstEthV2.addMinter(address(_nativeConverter), 10 ** 9 * 10 ** 18);
    vm.stopPrank();
  }

  function testConvertsWrappedToNative() external {
    // alice has 1M bw-WstETH
    uint256 amount = 1_000_000 * 10 ** 18;
    deal(address(_bwWstETH), _alice, amount);

    // convert to native and send to bob
    vm.startPrank(_alice);
    _bwWstETH.approve(address(_nativeConverter), amount);
    _nativeConverter.convert(_bob, amount);
    vm.stopPrank();

    // alice has no more bw-WstETH
    assertEq(_bwWstETH.balanceOf(_alice), 0);

    // bob has 1M native wstETH
    assertEq(_nativeWstEthV2.balanceOf(_bob), amount);
  }

  function testDeconvertsNativeToWrapped() external {
    // seed the native converter with some bridge-wrapped wstETH
    deal(address(_bwWstETH), address(_nativeConverter), 1_000_000 * 10 ** 18);

    // alice has 800k native wstETH
    uint256 amount = 800_000 * 10 ** 18;
    deal(address(_nativeWstEthV2), _alice, amount);

    // deconvert to bridge-wrapped wstETH and send to bob
    vm.startPrank(_alice);
    _nativeWstEthV2.approve(address(_nativeConverter), amount);
    _nativeConverter.deconvert(_bob, amount);
    vm.stopPrank();

    // alice has no more native wstETH
    assertEq(_nativeWstEthV2.balanceOf(_alice), 0);

    // bob has 800k bridge-wrapped wstETH
    assertEq(_bwWstETH.balanceOf(_bob), amount);
    // native converter has 200k bridge-wrapped wstETH
    assertEq(_bwWstETH.balanceOf(address(_nativeConverter)), 200_000 * 10 ** 18);
  }

  function testOwnerCanMigrate() external {
    // seed the native converter with some bridge-wrapped wstETH
    deal(address(_bwWstETH), address(_nativeConverter), 1_000_000 * 10 ** 18);

    // owner calls migrate
    vm.startPrank(_migrator);
    _nativeConverter.migrate();
    vm.stopPrank();

    // native converter has no more bridge-wrapped wstETH
    assertEq(_bwWstETH.balanceOf(address(_nativeConverter)), 0);

    // and we assume things got transferred to the other network
  }

  function testNonOwnerCannotMigrate() external {
    // seed the native converter with some bridge-wrapped wstETH
    deal(address(_bwWstETH), address(_nativeConverter), 1_000_000 * 10 ** 18);

    // non-owner tries to call migrate, fail
    vm.startPrank(_alice);
    vm.expectRevert(
      "AccessControl: account 0xe05fcc23807536bee418f142d19fa0d21bb0cff7 is missing role 0x600e5f1c60beb469a3fa6dd3814a4ae211cc6259a6d033bae218a742f2af01d3"
    );
    _nativeConverter.migrate();
    vm.stopPrank();
  }

  function testEmergencyCanPauseDefaultAdminCanUnpause() external {
    vm.startPrank(_emergency);

    // unpaused, pause
    assertEq(_nativeConverter.paused(), false);
    _nativeConverter.pause();
    assertEq(_nativeConverter.paused(), true);

    // paused, emergency CANNOT unpause
    vm.expectRevert(
      "AccessControl: account 0x14a1e1e4d8bea80c96edcaf655b8d1f35682c069 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
    );
    _nativeConverter.unpause();
    assertEq(_nativeConverter.paused(), true);
    vm.stopPrank();

    // paused, default admin CAN unpause
    vm.startPrank(_admin);
    _nativeConverter.unpause();
    assertEq(_nativeConverter.paused(), false);

    vm.stopPrank();
  }

  function testNonOwnerCannotPauseUnpause() external {
    vm.startPrank(_alice);

    // unpaused, try to pause, fail
    assertEq(_nativeConverter.paused(), false);
    vm.expectRevert(
      "AccessControl: account 0xe05fcc23807536bee418f142d19fa0d21bb0cff7 is missing role 0xbf233dd2aafeb4d50879c4aa5c81e96d92f6e6945c906a58f9f2d1c1631b4b26"
    );
    _nativeConverter.pause();
    assertEq(_nativeConverter.paused(), false);

    // pause
    vm.startPrank(_emergency);
    assertEq(_nativeConverter.paused(), false);
    _nativeConverter.pause();
    assertEq(_nativeConverter.paused(), true);

    // paused, try to unpause, fail
    changePrank(_alice);
    vm.expectRevert(
      "AccessControl: account 0xe05fcc23807536bee418f142d19fa0d21bb0cff7 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
    );
    _nativeConverter.unpause();
    assertEq(_nativeConverter.paused(), true);
  }

  function testCannotConvertWhenPaused() external {
    vm.startPrank(_emergency);
    _nativeConverter.pause();
    vm.stopPrank();

    // alice has 1M bw-WstETH
    uint256 amount = 1_000_000 * 10 ** 18;
    deal(address(_bwWstETH), _alice, amount);

    // try to convert to native, fail
    vm.startPrank(_alice);
    _bwWstETH.approve(address(_nativeConverter), amount);
    vm.expectRevert("Pausable: paused");
    _nativeConverter.convert(_alice, amount);
    vm.stopPrank();

    // alice still has the bw-WstETH
    assertEq(_bwWstETH.balanceOf(_alice), amount);
  }

  function testCannotDeconvertWhenPaused() external {
    vm.startPrank(_emergency);
    _nativeConverter.pause();
    vm.stopPrank();

    // seed the native converter with some bridge-wrapped wstETH
    deal(address(_bwWstETH), address(_nativeConverter), 1_000_000 * 10 ** 18);

    // alice has 800k native wstETH
    uint256 amount = 800_000 * 10 ** 18;
    deal(address(_nativeWstEthV2), _alice, amount);

    // try to deconvert, fail
    vm.startPrank(_alice);
    _nativeWstEthV2.approve(address(_nativeConverter), amount);
    vm.expectRevert("Pausable: paused");
    _nativeConverter.deconvert(_alice, amount);
    vm.stopPrank();

    // alice has the same native wstETH
    assertEq(_nativeWstEthV2.balanceOf(_alice), amount);
  }

  function testCannotMigrateWhenPaused() external {
    vm.startPrank(_emergency);
    _nativeConverter.pause();
    vm.stopPrank();

    // seed the native converter with some bridge-wrapped wstETH
    uint256 amount = 1_000_000 * 10 ** 18;
    deal(address(_bwWstETH), address(_nativeConverter), amount);

    // owner calls migrate
    vm.startPrank(_migrator);
    vm.expectRevert("Pausable: paused");
    _nativeConverter.migrate();
    vm.stopPrank();

    // native converter has no more bridge-wrapped wstETH
    assertEq(_bwWstETH.balanceOf(address(_nativeConverter)), amount);
  }
}
