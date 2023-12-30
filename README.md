# Polygon zkEVM wstETH Bridge

wstETH Bridge leveraging LxLy for between zkEVM and Mainnet.

## Get started

### Requirements

This repository is using foundry. You can install foundry via
[foundryup](https://book.getfoundry.sh/getting-started/installation).

### Setup

Clone the repository:

```sh
git clone git@github.com:pyk/zkevm-wsteth.git
cd zkevm-wsteth/
```

Install the dependencies:

```sh
forge install
```

### Tests

Create `.env` with the following contents:

```
ETH_RPC_URL=""
ETH_RPC_URL="https://zkevm-rpc.com"
ETHERSCAN_API_KEY=""
```

Use the following command to run the test:

```sh
forge test
```

You can also run individual test using the following command:

```sh
forge test --fork-url $ETH_RPC_URL --match-test bridgeToken -vvvv

forge test --fork-url "https://zkevm-rpc.com" --match-path test/L2wstETH.t.sol --match-test testBridgeWithMockedBridge -vvvv
```

> **Note**
> You can set `ETHERSCAN_API_KEY` to helps you debug the call trace.

## Contract addresses

| Smart contract       | Network       | Address                                                                                                                             |
| -------------------- | ------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| wstETH               | Mainnet       | [0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0](https://etherscan.io/address/0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0)               |
| Polygon ZkEVM Bridge | Mainnet       | [0x2a3dd3eb832af982ec71669e178424b10dca2ede](https://etherscan.io/address/0x2a3dd3eb832af982ec71669e178424b10dca2ede)               |
|                      | zkEVM Mainnet | [0x2a3dd3eb832af982ec71669e178424b10dca2ede](https://zkevm.polygonscan.com/address/0x2a3dd3eb832af982ec71669e178424b10dca2ede)      |
| WstETHBridgeL1       | Mainnet       | [0xf0cde1e7f0fad79771cd526b1eb0a12f69582c01](https://etherscan.io/address/0xf0cde1e7f0fad79771cd526b1eb0a12f69582c01#code)          |
| WstETHBridgeL2       | zkEVM Mainnet | [0xDB5D9c10FD2a92692DB51853e06058EE0436d69B](https://zkevm.polygonscan.com/address/0xdb5d9c10fd2a92692db51853e06058ee0436d69b#code) |
| WstETHWrapped        | zkEVM Mainnet | [0xbf6De60Ccd9D22a5820A658fbE9fc87975EA204f](https://zkevm.polygonscan.com/address/0xbf6De60Ccd9D22a5820A658fbE9fc87975EA204f#code) |
