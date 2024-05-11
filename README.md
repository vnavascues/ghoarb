# GHO Arb

## Summary

A smart contract that arbitrages GHO using GHO FlashMinter, GHO Stabilitiy Modules and Uniswap V3 pools.

**BEWARE**: the code in this repository is not intended to be used in production, but to showcase/inspire how to use
multiple GHO services in DeFi.

## Design

### GhoArb

Arbitrage flow:

1. Caller mints an `amount` of GHO using GHO FlashMint.

- Few arbitrage params are encoded in `data` (as `abi.encode(<enum:GsmAsset>,<uint256:minProfit>,<bytes:path>)`):
  - `gsmAsset`: either USDC or USDT mode.
  - `minProfit`: the expected profit after the arbitrage.
  - `path`: the Uniswap V3 swap path (1..N pools).

2. `GhoArb` trades GHO either for USDC or USDT on Uniswap V3 leveraging
   [Exact Input Multi Hop Swaps](https://docs.uniswap.org/contracts/v3/guides/swaps/multihop-swaps#exact-input-multi-hop-swaps).

- Multi-hop swaps allows triangular arbitrage.

3. `GhoArb` sells either USDC or USDT for GHO on the GHO Stability Modules (GSM USDC or GSM USDT).
4. `GhoArb` repays the minted GHO (plus fee) to the GHO FlashMint, and keeps the benefits.

- It will revert under the following circumstances:
  - The arbitrage is gonna be executed after the block deadline.
  - If the resulting GHO amount from selling either USDC or USDT to the GSM Stability Module is less than the amount
    required to repay the GHO FlashMinter.
  - If the abitrage GHO profit is less than the expected one (`minProfits`).

Other highlights:

- `GhoArb` is compatible with Chainlink Automation 2.0 via `AutomationCompatible`. Currently registration has to be done
  via UI.

## What's next

Short-term:

- ADD A PROPER TEST SUITE!.
- Double-check function invariants (this benefits from a good test suite).

To be explored/considered:

- Adding support for other AMMs (Curve DeFi GHO pools!!!
  [Uniswap V3 pools have low liquidity](https://aave.tokenlogic.com.au/liquidity-pools)).
- Make it more MEV resistant (e.g. a factory that deploys a GhoArb that arbitrages in the constructor).
- Improve Chainlink Automation integration:
  - Add support for register/unregister the keeper programmatically.
  - Leverage gasless `checkUpkeep()` function to allow more than one Uniswap V3 swap path and arbitrage params. The
    logic should pick the most suitable one.
  - Take into account the Automation cost in `minProfit`.
- Make execution fail fast (and with a comprehensive error message) if the involved GSM module can't sell GHO (expected
  to revert).
- Unsetting the forwarder when ownership is transferred.
- Add support for other kinds of [GHO arbitrage](https://docs.gho.xyz/concepts/fundamental-concepts/arbitrage) (e.g.
  using AAVEv3 `Pool.supply()` and `Pool.repay()`).

## Usage

BEWARE: this repository is built on top of
[PaulRBerg's foundry-template](https://github.com/PaulRBerg/foundry-template). See its
[Usage section](https://github.com/PaulRBerg/foundry-template/blob/main/README.md#usage) for further comprehension.

### Install dependencies

First install [bun](https://bun.sh/package-manager), a Node.js package manager alternative to Foundry git submodules.

Then install `package.json` dependencies by running:

```sh
bun install
```

### Test GhoArb

Run the tests:

```sh
$ forge test
```

Alternatively (currently there is only one test contract):

```sh
forge test --match-contract GhoArb_Fork_Mainnet_Test -vv
```

### Deploy GhoArb

Deploy to Anvil:

```sh
$ forge script script/DeployEthereumMainnet.s.sol --broadcast --fork-url http://localhost:8545
```

For this script to work, you need to have a `MNEMONIC` environment variable set to a valid
[BIP39 mnemonic](https://iancoleman.io/bip39/).

For instructions on how to deploy to a testnet or mainnet, check out the
[Solidity Scripting](https://book.getfoundry.sh/tutorials/solidity-scripting.html) tutorial.
