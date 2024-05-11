// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { GsmAsset } from "./DataTypes.sol";

library Errors {
    /* ========== GhoArb ========== */

    /// @dev Thrown when the `GhoFlashMinter.flashLoan()` call is unsuccessful and it does not revert.
    error GhoArb_ArbitrageFailed();

    /// @dev Thrown when the `IGhoArb.onFlashLoan()` is executed in a block greater than the `blockDeadline`.
    error GhoArb_BlockDeadlineIsGtBlockNumber(uint256 blockDeadline, uint256 blockNumber);

    /// @dev Thrown when the asset is not supported by the `GsmAsset` enum.
    error GhoArb_GsmAssetIsNotSupported(GsmAsset gsmAsset);

    /// @dev Thrown when the `IGhoArb.onFlashLoan()` caller is not the `GhoFlashMinter`.
    error GhoArb_MsgSenderIsNotFlashMinter(address msgSender);

    /// @dev Thrown when the arbitrage is not profitable.
    error GhoArb_ProfitIsBelowMinProfit(
        uint256 minProfit, uint256 amount, uint256 fee, uint256 swapAmountOut, uint256 swapAmountSold, uint256 boughtGho
    );

    /// @dev Thrown when an ERC20 token is not supported.
    error GhoArb_TokenIsNotSupported(address token);
}
