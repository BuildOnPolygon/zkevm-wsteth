// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC20} from "oz/token/ERC20/IERC20.sol";
import {SafeERC20} from "oz/token/ERC20/utils/SafeERC20.sol";

import {Initializable} from "upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlDefaultAdminRulesUpgradeable} from
  "upgradeable/access/AccessControlDefaultAdminRulesUpgradeable.sol";
import {PausableUpgradeable} from "upgradeable/security/PausableUpgradeable.sol";

import {IPolygonZkEVMBridge} from "./interfaces/IPolygonZkEVMBridge.sol";

import {WstETHWrappedV2} from "./WstETHWrappedV2.sol";

contract NativeConverter is AccessControlDefaultAdminRulesUpgradeable, PausableUpgradeable, UUPSUpgradeable {
  using SafeERC20 for IERC20;

  bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
  bytes32 public constant MIGRATOR_ROLE = keccak256("MIGRATOR_ROLE");

  event Convert(address indexed from, address indexed to, uint256 amount);
  event Deconvert(address indexed from, address indexed to, uint256 amount);
  event Migrate(uint256 amount);

  IPolygonZkEVMBridge public zkEvmBridge;
  uint32 public l1NetworkId;
  address public l1Escrow;

  IERC20 public bwWstETH;
  WstETHWrappedV2 public nativeWstETHV2;

  constructor() {
    _disableInitializers();
  }

  function _authorizeUpgrade(address v) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

  function initialize(
    address admin_,
    address _emergencyRoleAddress,
    address _migratorRoleAddress,
    address bridge_,
    uint32 l1NetworkId_,
    address l1Escrow_,
    address bwWstETH_,
    address nativeWstETHV2_
  ) public initializer {
    __AccessControlDefaultAdminRules_init(3 days, admin_);
    __Pausable_init();
    __UUPSUpgradeable_init();

    _grantRole(EMERGENCY_ROLE, _emergencyRoleAddress);
    _grantRole(MIGRATOR_ROLE, _migratorRoleAddress);

    zkEvmBridge = IPolygonZkEVMBridge(bridge_);
    l1NetworkId = l1NetworkId_;
    l1Escrow = l1Escrow_;

    bwWstETH = IERC20(bwWstETH_);
    nativeWstETHV2 = WstETHWrappedV2(nativeWstETHV2_);
  }

  function pause() external virtual onlyRole(EMERGENCY_ROLE) {
    _pause();
  }

  function unpause() external virtual onlyRole(DEFAULT_ADMIN_ROLE) {
    _unpause();
  }

  /// @notice Converts BridgeWrapped wstETH to Native wstETHV2
  function convert(address receiver, uint256 amount) external whenNotPaused {
    require(receiver != address(0), "INVALID_RECEIVER");
    require(amount > 0, "INVALID_AMOUNT");

    // transfer bridge-wrapped wstETH to converter
    bwWstETH.safeTransferFrom(msg.sender, address(this), amount);
    // and mint native wstETH to user
    nativeWstETHV2.mint(receiver, amount);

    emit Convert(msg.sender, receiver, amount);
  }

  /// @notice Deconverts nativeWstETHV2 back to BridgeWrapped wstETH
  /// Note: The nativeWstETHV2 is burned in the process.
  function deconvert(address receiver, uint256 amount) external whenNotPaused {
    require(receiver != address(0), "INVALID_RECEIVER");
    require(amount > 0, "INVALID_AMOUNT");
    require(amount <= bwWstETH.balanceOf(address(this)), "AMOUNT_TOO_LARGE");

    // transfer native wstETH from user to the converter, and burn it
    IERC20(address(nativeWstETHV2)).safeTransferFrom(msg.sender, address(this), amount);
    nativeWstETHV2.burn(amount);
    // and then send bridge-wrapped wstETH to the user
    bwWstETH.safeTransfer(receiver, amount);

    emit Deconvert(msg.sender, receiver, amount);
  }

  /// @notice Migrates the L2 BridgeWrapped wstETH to L1
  /// The L1 wstETH will be sent to the L1Escrow.
  function migrate() external onlyRole(MIGRATOR_ROLE) whenNotPaused {
    uint256 amount = bwWstETH.balanceOf(address(this));

    if (amount > 0) {
      bwWstETH.safeApprove(address(zkEvmBridge), amount);

      zkEvmBridge.bridgeAsset(
        l1NetworkId,
        l1Escrow,
        amount,
        address(bwWstETH),
        true, // forceUpdateGlobalExitRoot
        "" // empty permitData because we're doing approve
      );

      emit Migrate(amount);
    }
  }
}
