// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {AccessControlDefaultAdminRulesUpgradeable} from "upgradeable/access/AccessControlDefaultAdminRulesUpgradeable.sol";
import {ERC20PermitUpgradeable} from "upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {ERC20Upgradeable} from "upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {Initializable} from "upgradeable/proxy/utils/Initializable.sol";
import {PausableUpgradeable} from "upgradeable/security/PausableUpgradeable.sol";
import {SignatureCheckerUpgradeable} from "upgradeable/utils/cryptography/SignatureCheckerUpgradeable.sol";
import {UUPSUpgradeable} from "upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {IPolygonZkEVMBridge} from "./interfaces/IPolygonZkEVMBridge.sol";
import {PolygonERC20BridgeLibUpgradeable} from "./base/PolygonERC20BridgeLibUpgradeable.sol";

/**
 * @title WstETHBridgeNonNativeChain
 * @author sepyke.eth
 * @notice Main smart contract to bridge wstETH from Polygon zkEVM to Ethereum
 */
contract WstETHBridgeNonNativeChain is
  Initializable,
  UUPSUpgradeable,
  AccessControlDefaultAdminRulesUpgradeable,
  ERC20Upgradeable,
  ERC20PermitUpgradeable,
  PausableUpgradeable,
  PolygonERC20BridgeLibUpgradeable
{
  using SignatureCheckerUpgradeable for address;

  /// @notice Role identifiers
  bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

  /// @dev EIP-2612
  bytes32 private constant PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

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
   * @notice WstETHBridgeNonNativeChain initializer
   * @dev This initializer should be called via UUPSProxy constructor
   * @param _adminAddress The contract owner
   * @param _emergencyRoleAddress The emergency role address
   * @param _polygonZkEVMBridge The Polygon zkEVM bridge address
   * @param _counterpartContract The contract address of L1Escrow
   * @param _counterpartNetwork ID of Ethereum mainnet on the Polygon zkEVM bridge
   */
  function initialize(
    address _adminAddress,
    address _emergencyRoleAddress,
    IPolygonZkEVMBridge _polygonZkEVMBridge,
    address _counterpartContract,
    uint32 _counterpartNetwork
  ) public initializer {
    __AccessControlDefaultAdminRules_init(3 days, _adminAddress);
    __UUPSUpgradeable_init();
    __Pausable_init();
    __ERC20_init("Wrapped liquid staked Ether 2.0", "wstETH");
    __ERC20Permit_init("Wrapped liquid staked Ether 2.0");
    __PolygonERC20BridgeLib_init(_polygonZkEVMBridge, _counterpartContract, _counterpartNetwork);

    _grantRole(EMERGENCY_ROLE, _emergencyRoleAddress);
  }

  /**
   * @dev The WstETHBridgeNonNativeChain can only be upgraded by the admin
   * @param v new WstETHBridgeNonNativeChain version
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

  /// @dev Support EIP-2612 & EIP-1271
  function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
    public
    virtual
    override
    whenNotPaused
  {
    if (block.timestamp >= deadline) revert DeadlineInvalid();

    bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, _useNonce(owner), deadline));

    bytes32 hash = _hashTypedDataV4(structHash);
    bytes memory signature = abi.encodePacked(r, s, v);
    bool isValid = owner.isValidSignatureNow(hash, signature);
    if (!isValid) revert SignatureInvalid();

    _approve(owner, spender, value);
  }

  /**
   * @dev Handle the reception of the tokens
   * @param amount Token amount
   */
  function _receiveTokens(uint256 amount) internal virtual override whenNotPaused {
    //
  }

  /**
   * @dev Handle the transfer of the tokens
   * @param destinationAddress Address destination that will receive the tokens on the other network
   * @param amount Token amount
   */
  function _transferTokens(address destinationAddress, uint256 amount) internal virtual override whenNotPaused {
    //
  }
}
