// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25 <0.9.0;

import { BaseScript } from "./Base.s.sol";
import { MiscEthereum } from "aave-address-book/src/MiscEthereum.sol";

import { IGhoFlashMinter } from "gho-core/contracts/facilitators/flashMinter/interfaces/IGhoFlashMinter.sol";
import { IGsm } from "gho-core/contracts/facilitators/gsm/interfaces/IGsm.sol";
import { GhoArb } from "src/GhoArb.sol";

import { ISwapRouter02 } from "src/interfaces/external/uniswapV3/ISwapRouter02.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract DeployEthereumMainnet is BaseScript {
    IGhoFlashMinter private constant GHO_FLASHMINTER = IGhoFlashMinter(MiscEthereum.GHO_FLASHMINTER_FACILITATOR);
    IGsm private constant GSM_USDC = IGsm(MiscEthereum.GSM_USDC);
    IGsm private constant GSM_USDT = IGsm(MiscEthereum.GSM_USDT);
    // NB: https://docs.uniswap.org/contracts/v3/reference/deployments/ethereum-deployments
    ISwapRouter02 private immutable SWAP_ROUTER = ISwapRouter02(0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45); // NB:
        // SwapRouter02

    function run() public broadcast returns (GhoArb) {
        GhoArb ghoArb = new GhoArb(GHO_FLASHMINTER, GSM_USDC, GSM_USDT, SWAP_ROUTER);
        return ghoArb;
    }
}
