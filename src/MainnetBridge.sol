// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC20} from "oz/token/ERC20/IERC20.sol";
import {SafeERC20} from "oz/token/ERC20/utils/SafeERC20.sol";

import {Initializable} from "upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlDefaultAdminRulesUpgradeable} from "upgradeable/access/AccessControlDefaultAdminRulesUpgradeable.sol";
import {PausableUpgradeable} from "upgradeable/security/PausableUpgradeable.sol";

import {IPolygonZkEVMBridge} from "./IPolygonZkEVMBridge.sol";
import {PolygonERC20BridgeLibUpgradeable} from "./PolygonERC20BridgeLibUpgradeable.sol";

/**
 * @title MainnetBridge
 * @author sepyke.eth
 * @notice Main smart contract to bridge wstETH from Ethereum to Polygon zkEVM
 */
contract MainnetBridge is
  Initializable,
  UUPSUpgradeable,
  AccessControlDefaultAdminRulesUpgradeable,
  PausableUpgradeable,
  PolygonERC20BridgeLibUpgradeable
{
  using SafeERC20 for IERC20;

  /// @notice Role identifiers
  bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

  /// @notice wstETH contract
  IERC20 public originTokenAddress;

  /// @notice wstETH origin from mainnet = 0; if from zkEVM then 1
  uint32 public originTokenNetwork = 0;

  /// @notice Disable initializer on deploy
  constructor() {
    _disableInitializers();
  }

  /**
   * @notice MainnetBridge initializer
   * @param _adminAddress The admin address
   * @param _emergencyRoleAddress The emergency role address
   * @param _originTokenAddress The wstETH address
   * @param _polygonZkEVMBridge The Polygon zkEVM bridge address
   * @param _counterpartContract The token address on the Polygon zkEVM network
   * @param _counterpartNetwork The Polygon zkEVM ID on the bridge
   */
  function initialize(
    address _adminAddress,
    address _emergencyRoleAddress,
    address _originTokenAddress,
    IPolygonZkEVMBridge _polygonZkEVMBridge,
    address _counterpartContract,
    uint32 _counterpartNetwork
  ) public initializer {
    __AccessControlDefaultAdminRules_init(3 days, _adminAddress);
    __UUPSUpgradeable_init();
    __Pausable_init();
    __PolygonERC20BridgeLib_init(_polygonZkEVMBridge, _counterpartContract, _counterpartNetwork);

    _grantRole(EMERGENCY_ROLE, _emergencyRoleAddress);

    originTokenAddress = IERC20(_originTokenAddress);
  }

  /**
   * @dev The MainnetBridge can only be upgraded by the owner
   * @param v new MainnetBridge implementation
   */
  function _authorizeUpgrade(address v) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

  /**
   * @notice Pause the bridge
   * @dev Only EMERGENCY_ROLE can pause the bridge
   */
  function pause() external virtual onlyRole(EMERGENCY_ROLE) {
    _pause();
  }

  /**
   * @notice Resume the bridge
   * @dev Only EMERGENCY_ROLE can resume the bridge
   */
  function unpause() external virtual onlyRole(EMERGENCY_ROLE) {
    _unpause();
  }

  /**
   * @dev Handle the reception of the tokens
   * @param amount Token amount
   */
  function _receiveTokens(uint256 amount) internal virtual override whenNotPaused {
    originTokenAddress.safeTransferFrom(msg.sender, address(this), amount);
  }

  /**
   * @dev Handle the transfer of the tokens
   * @param destinationAddress Address destination that will receive the tokens on the other network
   * @param amount Token amount
   */
  function _transferTokens(address destinationAddress, uint256 amount) internal virtual override whenNotPaused {
    originTokenAddress.safeTransfer(destinationAddress, amount);
  }
}