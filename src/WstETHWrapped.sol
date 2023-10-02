// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Initializable} from "upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlDefaultAdminRulesUpgradeable} from
  "upgradeable/access/AccessControlDefaultAdminRulesUpgradeable.sol";

import {PausableUpgradeable} from
  "upgradeable/security/PausableUpgradeable.sol";
import {ERC20PermitUpgradeable} from
  "upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";

/**
 * @title WstETHWrapped
 * @author sepyke.eth
 * @notice WstETH on Polygon zkEVM
 */
contract WstETHWrapped is
  Initializable,
  UUPSUpgradeable,
  AccessControlDefaultAdminRulesUpgradeable,
  PausableUpgradeable,
  ERC20PermitUpgradeable
{
  /// @notice wstETHBridge address on polygon zkEVM
  address public wstETHBridge;

  /// @notice Role identifiers
  bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

  /// @notice Add origin token network

  /// @notice Disable initializer on deploy
  constructor() {
    _disableInitializers();
  }

  /**
   * @dev Modifier to make sure the caller is a bridge
   */
  modifier onlyBridge() {
    require(
      msg.sender == wstETHBridge,
      "CustomERC20Wrapped::onlyBridge: Not PolygonZkEVMBridge"
    );
    _;
  }

  /**
   * @notice WstETH initializer
   * @param _adminAddress The admin address
   * @param _emergencyRoleAddress The emergency role address
   * @param _wstETHBridgeAddress The WstETH bridge address on Polygon zkEVM
   */
  function initialize(
    address _adminAddress,
    address _emergencyRoleAddress,
    address _wstETHBridgeAddress
  ) public initializer {
    __AccessControlDefaultAdminRules_init(3 days, _adminAddress);
    __UUPSUpgradeable_init();
    __ERC20_init("Wrapped liquid staked Ether 2.0", "wstETH");
    __ERC20Permit_init("Wrapped liquid staked Ether 2.0");
    _grantRole(EMERGENCY_ROLE, _emergencyRoleAddress);
    wstETHBridge = _wstETHBridgeAddress;
  }

  /**
   * @dev The WstETH can only be upgraded by the admin
   * @param v new WstETH version
   */
  function _authorizeUpgrade(address v)
    internal
    override
    onlyRole(DEFAULT_ADMIN_ROLE)
  {}

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
  function _beforeTokenTransfer(address from, address to, uint256 amount)
    internal
    virtual
    override
    whenNotPaused
  {
    super._beforeTokenTransfer(from, to, amount);
  }

  /**
   * @notice Mint token as bridge
   * @param to the recipeint address
   * @param value the token amount
   */
  function bridgeMint(address to, uint256 value) external onlyBridge {
    _mint(to, value);
  }

  /**
   * @notice Burn token as bridge
   * @param account the owner address
   * @param value the token amount
   */
  function bridgeBurn(address account, uint256 value) external onlyBridge {
    _burn(account, value);
  }
}
