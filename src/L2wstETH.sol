// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {AccessControlDefaultAdminRulesUpgradeable} from
  "upgradeable/access/AccessControlDefaultAdminRulesUpgradeable.sol";
import {ERC20PermitUpgradeable} from
  "upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {ERC20Upgradeable} from "upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {Initializable} from "upgradeable/proxy/utils/Initializable.sol";
import {PausableUpgradeable} from
  "upgradeable/security/PausableUpgradeable.sol";
import {SignatureCheckerUpgradeable} from
  "upgradeable/utils/cryptography/SignatureCheckerUpgradeable.sol";
import {UUPSUpgradeable} from "upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {IBridge} from "./IBridge.sol";

/**
 * @title L2wstETH
 * @author sepyke.eth
 * @notice Main smart contract to bridge wstETH from Polygon zkEVM to Ethereum
 */
contract L2wstETH is
  Initializable,
  UUPSUpgradeable,
  AccessControlDefaultAdminRulesUpgradeable,
  ERC20Upgradeable,
  ERC20PermitUpgradeable,
  PausableUpgradeable
{
  using SignatureCheckerUpgradeable for address;

  /// @notice Role identifiers
  bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

  /// @dev EIP-2612
  bytes32 private constant PERMIT_TYPEHASH = keccak256(
    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
  );

  /// @notice The Polygon zkEVM bridge contract
  IBridge public zkEvmBridge;

  /// @notice L1Escrow contract address on Ethereum mainnet
  address public destAddress;

  /// @notice Network ID of Ethereum mainnet on the Polygon zkEVM bridge
  uint32 public destId;

  /// @notice This event is emitted when the wstETH is bridged
  event TokenBridged(
    address indexed sender, address indexed recipient, uint256 amount
  );

  /// @notice This event is emitted when the wstETH is claimed
  event TokenClaimed(
    address indexed sender, address indexed recipient, uint256 amount
  );

  /// @notice This error is raised if message from the bridge is invalid
  error MessageInvalid();

  /// @notice This error is raised if bridged amount is invalid
  error BridgeAmountInvalid();

  /// @notice This error is raised if ownership is renounced
  error RenounceInvalid();

  /// @notice This error is raised if deadline is invalid
  error DeadlineInvalid();

  /// @notice This error is raised if signature is invalid
  error SignatureInvalid();

  /// @notice Disable initializer on deploy
  constructor() {
    _disableInitializers();
  }

  /**
   * @notice L2wstETH initializer
   * @dev This initializer should be called via UUPSProxy constructor
   * @param _adminAddress The contract owner
   * @param _emergencyRoleAddress The emergency role address
   * @param _bridgeAddress The Polygon zkEVM bridge address
   * @param _destAddress The contract address of L1Escrow
   * @param _destId ID of Ethereum mainnet on the Polygon zkEVM bridge
   */
  function initialize(
    address _adminAddress,
    address _emergencyRoleAddress,
    address _bridgeAddress,
    address _destAddress,
    uint32 _destId
  ) public initializer {
    __AccessControlDefaultAdminRules_init(3 days, _adminAddress);
    __UUPSUpgradeable_init();
    __Pausable_init();
    __ERC20_init("Wrapped liquid staked Ether 2.0", "wstETH");
    __ERC20Permit_init("Wrapped liquid staked Ether 2.0");

    _grantRole(EMERGENCY_ROLE, _emergencyRoleAddress);

    zkEvmBridge = IBridge(_bridgeAddress);
    destAddress = _destAddress;
    destId = _destId;
  }

  /**
   * @dev The L2wstETH can only be upgraded by the admin
   * @param v new L2wstETH version
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

  /// @dev Support EIP-2612 & EIP-1271
  function permit(
    address owner,
    address spender,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) public virtual override {
    if (block.timestamp >= deadline) revert DeadlineInvalid();

    bytes32 structHash = keccak256(
      abi.encode(
        PERMIT_TYPEHASH, owner, spender, value, _useNonce(owner), deadline
      )
    );

    bytes32 hash = _hashTypedDataV4(structHash);
    bytes memory signature = abi.encodePacked(r, s, v);
    bool isValid = owner.isValidSignatureNow(hash, signature);
    if (!isValid) revert SignatureInvalid();

    _approve(owner, spender, value);
  }

  /**
   * @notice Bridge wstETH from Polygon zkEVM to Ethereum mainnet
   * @param recipient The recipient of the bridged token
   * @param amount wstETH amount
   * @param forceUpdateGlobalExitRoot Indicates if the global exit root is
   *        updated or not
   */
  function bridgeToken(
    address recipient,
    uint256 amount,
    bool forceUpdateGlobalExitRoot
  ) public virtual whenNotPaused {
    if (amount < 1 ether) revert BridgeAmountInvalid();

    _burn(msg.sender, amount);
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
    _mint(recipient, amount);

    emit TokenClaimed(msg.sender, recipient, amount);
  }
}
