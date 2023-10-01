// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Initializable} from "upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlDefaultAdminRulesUpgradeable} from "upgradeable/access/AccessControlDefaultAdminRulesUpgradeable.sol";

import {PausableUpgradeable} from "upgradeable/security/PausableUpgradeable.sol";
import {ERC20PermitUpgradeable} from "upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {ERC20PermitUpgradeable} from "upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";

/**
 * @title WstETH
 * @author sepyke.eth
 * @notice WstETH on Polygon zkEVM
 */
contract WstETH is Initializable, UUPSUpgradeable, AccessControlDefaultAdminRulesUpgradeable, ERC20PermitUpgradeable, PausableUpgradeable {
  /// @notice Role identifiers
  bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

  /// @notice WstETHBridgeNonNativeChain
  address public wstETHBridgeNonNativeChain;

  /// @notice Disable initializer on deploy
  constructor() {
    _disableInitializers();
  }

  /**
   * @notice WstETH initializer
   * @param _adminAddress The admin address
   * @param _emergencyRoleAddress The emergency role address
   * @param _wstETHBridgeNonNativeChain The bridge address on Polygon zkEVM
   */
  function initialize(address _adminAddress, address _emergencyRoleAddress, address _wstETHBridgeNonNativeChain) public initializer {
    __AccessControlDefaultAdminRules_init(3 days, _adminAddress);
    __UUPSUpgradeable_init();
    __ERC20_init("Wrapped liquid staked Ether 2.0", "wstETH");
    __ERC20Permit_init("Wrapped liquid staked Ether 2.0");
    _grantRole(EMERGENCY_ROLE, _emergencyRoleAddress);
    wstETHBridgeNonNativeChain = _wstETHBridgeNonNativeChain;
  }

  /**
   * @dev The WstETH can only be upgraded by the admin
   * @param v new WstETH version
   */
  function _authorizeUpgrade(address v) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

  /**
   * @notice Pause the WstETH
   * @dev Only EMERGENCY_ROLE can pause the bridge
   */
  function pause() external virtual onlyRole(EMERGENCY_ROLE) {
    _pause();
  }

  /**
   * @notice Resume the WstETH
   * @dev Only EMERGENCY_ROLE can resume the bridge
   */
  function unpause() external virtual onlyRole(EMERGENCY_ROLE) {
    _unpause();
  }

  /**
   * @notice _beforeTokenTransfer hook to pause the transfer
   */
  function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override whenNotPaused {
    super._beforeTokenTransfer(from, to, amount);
  }
}
