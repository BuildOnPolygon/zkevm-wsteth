// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Initializable} from "upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlDefaultAdminRulesUpgradeable} from
  "upgradeable/access/AccessControlDefaultAdminRulesUpgradeable.sol";
import {PausableUpgradeable} from
  "upgradeable/security/PausableUpgradeable.sol";
import {IERC20} from "oz/token/ERC20/IERC20.sol";
import {SafeERC20} from "oz/token/ERC20/utils/SafeERC20.sol";

import {PausableUpgradeable} from
  "upgradeable/security/PausableUpgradeable.sol";

import {IBridge} from "./IBridge.sol";

/**
 * @title L1Escrow
 * @author sepyke.eth
 * @notice Main smart contract to bridge wstETH from Ethereum to Polygon zkEVM
 */
contract L1Escrow is
  Initializable,
  UUPSUpgradeable,
  AccessControlDefaultAdminRulesUpgradeable,
  PausableUpgradeable
{
  using SafeERC20 for IERC20;

  /// @notice Role identifiers
  bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

  /// @notice wstETH contract
  IERC20 public wstETH;

  /// @notice Polygon zkEVM bridge contract
  IBridge public zkEvmBridge;

  /// @notice Native wstETH contract address on Polygon zkEVM
  address public destAddress;

  /// @notice Network ID of Polygon zkEVM on the Polygon zkEVM bridge
  uint32 public destId;

  /// @notice This event is emitted when the DAI is bridged
  event TokenBridged(
    address indexed sender, address indexed recipient, uint256 amount
  );

  /// @notice This event is emitted when the DAI is claimed
  event TokenClaimed(
    address indexed sender, address indexed recipient, uint256 amount
  );

  /// @notice This error is raised if message from the bridge is invalid
  error MessageInvalid();

  /// @notice This error is raised if bridged amount is invalid
  error BridgeAmountInvalid();

  /// @notice Disable initializer on deploy
  constructor() {
    _disableInitializers();
  }

  /**
   * @notice L1Escrow initializer
   * @param _adminAddress The admin address
   * @param _emergencyRoleAddress The emergency role address
   * @param _wstethAddress The wstETH address
   * @param _bridgeAddress The Polygon zkEVM bridge address
   * @param _destId The Polygon zkEVM ID on the bridge
   * @param _destAddress The token address on the Polygon zkEVM network
   */
  function initialize(
    address _adminAddress,
    address _emergencyRoleAddress,
    address _wstethAddress,
    address _bridgeAddress,
    uint32 _destId,
    address _destAddress
  ) public initializer {
    __AccessControlDefaultAdminRules_init(3 days, _adminAddress);
    __UUPSUpgradeable_init();
    __Pausable_init();

    _grantRole(EMERGENCY_ROLE, _emergencyRoleAddress);

    wstETH = IERC20(_wstethAddress);
    zkEvmBridge = IBridge(_bridgeAddress);
    destId = _destId;
    destAddress = _destAddress;
  }

  /**
   * @dev The L1Escrow can only be upgraded by the owner
   * @param v new L1Escrow implementation
   */
  function _authorizeUpgrade(address v)
    internal
    override
    onlyRole(DEFAULT_ADMIN_ROLE)
  {}

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
   * @notice Bridge wstETH from Ethereum mainnet to Polygon zkEVM
   * @param recipient The recipient of the bridged token
   * @param amount wstETH amount
   * @param forceUpdateGlobalExitRoot Indicates if the global exit root is
   *        updated or not
   */
  function bridgeToken(
    address recipient,
    uint256 amount,
    bool forceUpdateGlobalExitRoot
  ) external virtual whenNotPaused {
    if (amount == 0) revert BridgeAmountInvalid();

    wstETH.safeTransferFrom(msg.sender, address(this), amount);

    bytes memory messageData = abi.encode(recipient, amount);
    zkEvmBridge.bridgeMessage(
      destId, destAddress, forceUpdateGlobalExitRoot, messageData
    );
    emit TokenBridged(msg.sender, recipient, amount);
  }

  /**
   * @notice This function will be triggered by the bridge
   * @param originAddress The origin address
   * @param originNetwork The origin network
   * @param metadata Abi encoded metadata
   */
  function onMessageReceived(
    address originAddress,
    uint32 originNetwork,
    bytes memory metadata
  ) external payable virtual whenNotPaused {
    if (msg.sender != address(zkEvmBridge)) revert MessageInvalid();
    if (originAddress != destAddress) revert MessageInvalid();
    if (originNetwork != destId) revert MessageInvalid();

    (address recipient, uint256 amount) =
      abi.decode(metadata, (address, uint256));

    wstETH.safeTransfer(recipient, amount);
    emit TokenClaimed(msg.sender, recipient, amount);
  }
}
