// SPDX-License-Identifier: MIT
// solhint-disable-next-line
pragma solidity ^0.8.0;

import { IERC3156FlashBorrower } from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { GsmAsset } from "src/libraries/DataTypes.sol";

/**
 * @title IGhoArb
 * @author vnavascues
 * @notice A permissioned smart contract to arbitrage GHO using GHO FlashMinter, GHO Stabilitiy Modules and Uniswap V3
 * pools.
 */
interface IGhoArb is IERC3156FlashBorrower {
    /// @notice Emitted when an ERC20 allowance has been set via `IGhoArb.setAllowance()`.
    event AllowanceSet(IERC20 indexed token, address indexed spender, bool isSet);

    /// @notice Emitted when GHO has been arbitraged via `IGhoArb.execute()`.
    event Arbitraged(
        GsmAsset gsmAsset,
        uint256 minProfit,
        bytes path,
        uint256 amount,
        uint256 fee,
        uint256 swapAmountOut,
        uint256 swapAmountSold,
        uint256 boughtGho
    );

    /// @notice Emitted when an ERC20 has been transferred via `IGhoArb.withdraw()`.
    event FundsWithdrawn(IERC20 indexed token, address indexed to, uint256 amount);

    /**
     * @notice Perform a GHO arbitrage.
     * @dev Only callable by the `GhoArb` forwarders.
     * @dev Reverts with `Errors.GhoArb_ArbitrageFailed` if the `GhoFlashMinter.flashLoan()` call is unsuccessful and it
     * does not revert.
     * @dev Reverts with `Errors.GhoArb_BlockDeadlineIsGtBlockNumber` if the `GhoFlashMinter.onFlashLoan()` call is
     * executed in a block greater than the current one (via `IGhoArb.onFlashLoan()` callback).
     * @dev Reverts with `Errors.GhoArb_GsmAssetIsNotSupported` if the `GsmAsset` encoded in the `data` parameter is not
     * supported (via `IGhoArb.onFlashLoan()` callback).
     * @dev Reverts with `Errors.GhoArb_MsgSenderIsNotFlashMinter` if the `IGhoArb.onFlashLoan()` caller is not the
     * `GhoFlashMinter` (via `IGhoArb.onFlashLoan()` callback).
     * @dev Reverts with `Errors.GhoArb_TokenIsNotSupported` if the `IGhoArb.onFlashLoan()` `token` parameter is not the
     * GHO token (via `IGhoArb.onFlashLoan()` callback).
     * @dev Reverts with `Errors.GhoArb_ProfitIsBelowMinProfit` if the arbitrage is not profitable (via
     * `IGhoArb.onFlashLoan()` callback). Cases:
     * 1. The GHO amount bought at the `Gsm` (GHO Stability Modules) is below the GHO amount to be repaid to the
     * `GhoFlashMinter`.
     * 2. The resulting profit is below the minimum one (encoded in `data`).
     * @dev Emits an `Arbitraged` event.
     * @param amount The amount of GHO tokens to borrow from `GhoFlashMinter`.
     * @param data The arbitrage configuration parameters encoded as `bytes32` and composed by:
     * `abi.encode(<enum:GsmAsset>,<uint256:minProfit>,<uint256:blockDeadline>,<bytes:path>)`. Where `path` contains
     * the multiple pool swaps encoded (see
     * https://docs.uniswap.org/contracts/v3/guides/swaps/multihop-swaps#input-parameters).
     */
    function execute(uint256 amount, bytes memory data) external;

    /**
     * @notice Toggle approval of infinite or zero allowance from `GhoArb` to `spender`.
     * @dev Only callable by the `GhoArb` owner.
     * @dev This function calls `SafeERC20.forceApprove()` to support non-standard ERC20 (e.g. USDT).
     * @dev Emits an `AllowanceSet` event.
     * @param token The ERC20 token address.
     * @param spender The address allowed to spend tokens on behalf of `GhoArb`.
     * @param isSet The boolean indicating whether the allowance is infinite or zero.
     */
    function setAllowance(IERC20 token, address spender, bool isSet) external;

    /**
     * @notice Transfer ERC20 tokens from `GhoArb` to an address.
     * @dev Only callable by the `GhoArb` owner.
     * @dev It allows to recover any ERC20 token sent by mistake to `GhoArb`.
     * @dev Emits a `FundsWithdrawn` event.
     * @param token The ERC20 token address.
     * @param to The address where to send the ERC20 tokens.
     * @param amount The amount of ERC20 tokens to withdraw.
     */
    function withdraw(IERC20 token, address to, uint256 amount) external;
}
