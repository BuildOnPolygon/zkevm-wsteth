// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ERC1967Proxy} from "oz/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title WstETHBridgeL1UUPSProxy
 * @author sepyke.eth
 * @notice UUPS proxy smart contract
 */
contract WstETHBridgeL1UUPSProxy is ERC1967Proxy {
  constructor(address _implementation, bytes memory _data)
    ERC1967Proxy(_implementation, _data)
  {}
}
