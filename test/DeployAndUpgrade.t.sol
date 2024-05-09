// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {UUPSUpgradeable} from "upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {WstETHWrappedV2} from "src/WstETHWrappedV2.sol";
import {NativeConverter} from "src/NativeConverter.sol";
import {ICREATE3Factory} from "script/ICREATE3Factory.sol";
import {UUPSProxy} from "script/UUPSProxy.sol";

contract TestDeployAndUpgradeV2andNativeConverter is Test {
  function testDeployAndUpgradeWstEthWrappedAndNativeConverter() external {
    vm.selectFork(vm.createFork(vm.envString("ZKEVM_RPC_URL")));

    address wstEthWrappedOwner = 0x2be7b3e7b9BFfbB38B85f563f88A34d84Dc99c9f;
    address l2wstEthWrapped = 0xbf6De60Ccd9D22a5820A658fbE9fc87975EA204f;
    address bwWstEthWrapped = 0x5D8cfF95D7A57c0BF50B30b43c7CC0D52825D4a9;

    vm.deal(wstEthWrappedOwner, 10 ** 18); // fund with 1 eth

    // DEPLOY WstETHWrappedV2 AND UPGRADE THE PROXY
    vm.startPrank(wstEthWrappedOwner);
    WstETHWrappedV2 wstEthWrappedV2 = new WstETHWrappedV2(); // deploy new implementation
    UUPSUpgradeable proxy = UUPSUpgradeable(l2wstEthWrapped); // get proxy
    proxy.upgradeTo(address(wstEthWrappedV2)); // upgrade to new implementation
    vm.stopPrank();

    // DEPLOY NATIVE CONVERTER
    vm.startPrank(wstEthWrappedOwner);
    NativeConverter nc = new NativeConverter();
    bytes memory ncInitData = abi.encodeWithSelector(
      NativeConverter.initialize.selector,
      wstEthWrappedOwner, // admin
      wstEthWrappedOwner, // pauser
      wstEthWrappedOwner, // migrator
      0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe, // bridge
      0, // l1 network id
      0xf0CDE1E7F0FAD79771cd526b1Eb0A12F69582C01, // "l1 escrow"
      bwWstEthWrapped, // bridge-wrapped
      l2wstEthWrapped // v2
    );
    bytes32 salt = keccak256(bytes("WstEthNativeConverter"));
    bytes memory proxyCreationCode = abi.encodePacked(type(UUPSProxy).creationCode, abi.encode(address(nc), ncInitData));
    address ncProxy = ICREATE3Factory(0x93FEC2C00BfE902F733B57c5a6CeeD7CD1384AE1).deploy(salt, proxyCreationCode);
    vm.stopPrank();

    // SET NATIVE CONVERTER AS A MINTER
    vm.startPrank(wstEthWrappedOwner);
    WstETHWrappedV2(l2wstEthWrapped).addMinter(ncProxy, 10 ** 9 * 10 ** 18); // 1B allowance
    vm.stopPrank();

    // TEST NATIVE CONVERTER
    address alice = vm.addr(8);
    uint256 amount = 10 ** 3 * 10 ** 18;
    deal(bwWstEthWrapped, alice, amount); // fund alice with 1k bwWstEthWrapped

    vm.startPrank(alice);
    assertEq(IERC20(l2wstEthWrapped).balanceOf(alice), 0);
    IERC20(bwWstEthWrapped).approve(ncProxy, amount);
    NativeConverter(ncProxy).convert(alice, amount);
    assertEq(IERC20(l2wstEthWrapped).balanceOf(alice), amount);
    vm.stopPrank();
  }
}
