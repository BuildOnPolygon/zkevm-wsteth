// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";

import {WstETHWrapped} from "../src/WstETHWrapped.sol";
import {WstETHWrappedV2} from "../src/WstETHWrappedV2.sol";
import {WstETHWrappedUUPSProxy} from
  "../src/proxies/WstETHWrappedUUPSProxy.sol";

contract WstETHWrappedTestV2 is Test {
  address _bridge = 0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe;
  address _deployer = vm.addr(0xC14C13);
  address _admin = vm.addr(0xB453D);
  address _emergency = vm.addr(0xD4DD1);
  address _minter = vm.addr(0xA11CE);
  address _nonMinter = vm.addr(0xB0B);
  address _joe = address(4);
  uint32 _networkId = 0;

  WstETHWrappedV2 _wstEthV2;

  function setUp() public {
    vm.selectFork(vm.createFork(vm.envString("ZKEVM_RPC_URL")));
    vm.startPrank(_deployer);
    _wstEthV2 = WstETHWrappedV2(
      address(
        new WstETHWrappedUUPSProxy(
          address(new WstETHWrappedV2()), // impl
          abi.encodeWithSelector( // init data
          WstETHWrapped.initialize.selector, _admin, _emergency, _joe)
        )
      )
    );
    vm.stopPrank();
  }

  function testOwnerCanAddMinter() external {
    // was not a minter
    vm.startPrank(_minter);
    vm.expectRevert("NOT_MINTER");
    _wstEthV2.mint(_joe, 1000 * 10 ** 18);
    vm.stopPrank();

    // owner sets minter
    vm.startPrank(_emergency);
    _wstEthV2.addMinter(_minter, 10 ** 6 * 10 ** 18); // 1M wstETH allowance
    vm.stopPrank();

    // can mint
    vm.startPrank(_minter);
    _wstEthV2.mint(_joe, 1000 * 10 ** 18);
    vm.stopPrank();

    // it minted
    assertEq(_wstEthV2.balanceOf(_joe), 1000 * 10 ** 18);
  }

  function testOwnerCanRemoveMinter() external {
    // owner sets minter
    vm.startPrank(_emergency);
    _wstEthV2.addMinter(_minter, 10 ** 6 * 10 ** 18); // 1M wstETH allowance
    vm.stopPrank();

    // can mint
    vm.startPrank(_minter);
    _wstEthV2.mint(_joe, 1000 * 10 ** 18);
    vm.stopPrank();

    // it minted
    assertEq(_wstEthV2.balanceOf(_joe), 1000 * 10 ** 18);

    // owner removes minter
    vm.startPrank(_emergency);
    _wstEthV2.removeMinter(_minter);
    vm.stopPrank();

    // cannot mint
    vm.startPrank(_minter);
    vm.expectRevert("NOT_MINTER");
    _wstEthV2.mint(_joe, 1000 * 10 ** 18);
    vm.stopPrank();
  }

  function testNonOwnerCannotAddMinter() external {
    // trying to make itself a minter
    vm.startPrank(_minter);
    vm.expectRevert(
      "AccessControl: account 0xe05fcc23807536bee418f142d19fa0d21bb0cff7 is missing role 0xbf233dd2aafeb4d50879c4aa5c81e96d92f6e6945c906a58f9f2d1c1631b4b26"
    );
    _wstEthV2.addMinter(_minter, 10 ** 6 * 10 ** 18); // 1M DAI
    vm.stopPrank();
  }

  function testNonOwnerCannotRemoveMinter() external {
    // owner sets minter
    vm.startPrank(_emergency);
    _wstEthV2.addMinter(_minter, 10 ** 6 * 10 ** 18); // 1M wstETH allowance
    vm.stopPrank();

    // non-owner tries to remove minter
    vm.startPrank(_minter);
    vm.expectRevert(
      "AccessControl: account 0xe05fcc23807536bee418f142d19fa0d21bb0cff7 is missing role 0xbf233dd2aafeb4d50879c4aa5c81e96d92f6e6945c906a58f9f2d1c1631b4b26"
    );
    _wstEthV2.removeMinter(_minter);
    vm.stopPrank();
  }

  function testMinterCannotMintOverAllowance() external {
    // owner sets minter
    vm.startPrank(_emergency);
    _wstEthV2.addMinter(_minter, 10 ** 6 * 10 ** 18); // 1M wstETH allowance
    vm.stopPrank();

    // can mint 500k
    vm.startPrank(_minter);
    _wstEthV2.mint(_joe, 500_000 * 10 ** 18);
    vm.stopPrank();

    // cannot mint 750k
    vm.startPrank(_minter);
    vm.expectRevert("EXCEEDS_MINT_ALLOWANCE");
    _wstEthV2.mint(_joe, 750_000 * 10 ** 18);
    vm.stopPrank();
  }

  function testNonMinterCannotMint() external {
    // cannot mint
    vm.startPrank(_nonMinter);
    vm.expectRevert("NOT_MINTER");
    _wstEthV2.mint(_joe, 1000 * 10 ** 18);
    vm.stopPrank();
  }

  function testMinterCanBurn() external {
    // owner sets minter
    vm.startPrank(_emergency);
    _wstEthV2.addMinter(_minter, 10 ** 6 * 10 ** 18); // 1M wstETH allowance
    vm.stopPrank();

    // mint 500k and burn 500k
    vm.startPrank(_minter);
    _wstEthV2.mint(_minter, 500_000 * 10 ** 18);
    _wstEthV2.burn(500_000 * 10 ** 18);
    vm.stopPrank();
  }

  function testNonMinterCannotBurn() external {
    // mint 500k and burn 500k
    vm.startPrank(_nonMinter);
    vm.expectRevert("NOT_MINTER");
    _wstEthV2.burn(500_000 * 10 ** 18);
    vm.stopPrank();
  }
}
