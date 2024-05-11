// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { AutomationCompatibleInterface } from
    "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";

import { IERC3156FlashBorrower } from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IGhoFlashMinter } from "gho-core/contracts/facilitators/flashMinter/interfaces/IGhoFlashMinter.sol";
import { IGsm } from "gho-core/contracts/facilitators/gsm/interfaces/IGsm.sol";
import { IGhoToken } from "gho-core/contracts/gho/interfaces/IGhoToken.sol";
import { GhoArbAutomationCompatible } from "src/GhoArbAutomationCompatible.sol";
import { IGhoArb } from "src/interfaces/IGhoArb.sol";
import { ISwapRouter02 } from "src/interfaces/external/uniswapV3/ISwapRouter02.sol";

import { ITypeAndVersion } from "src/interfaces/ITypeAndVersion.sol";

import { GsmAsset } from "src/libraries/DataTypes.sol";
import { Errors } from "src/libraries/Errors.sol";

/**
 * @title GhoArb
 * @author vnavascues
 * @notice A permissioned smart contract to arbitrage GHO using GHO FlashMinter, GHO Stabilitiy Modules and Uniswap V3
 * pools.
 */
contract GhoArb is IGhoArb, Ownable2Step, GhoArbAutomationCompatible, ITypeAndVersion {
    using SafeERC20 for IERC20;

    IGhoToken private immutable GHO;
    IGhoFlashMinter private immutable GHO_FLASHMINTER;
    IGsm private immutable GSM_USDC;
    IGsm private immutable GSM_USDT;
    IERC20 private immutable USDC;
    IERC20 private immutable USDT;
    ISwapRouter02 private immutable SWAP_ROUTER;

    /**
     * @param flashMinter The `GhoFlashMinter` address (aka. GHO FlashMinter).
     * @param gsmUsdc The USDC `Gsm` address (aka. GHO USDC Stability Module).
     * @param gsmUsdt The USDT `Gsm` address (aka. GHO USDT Stability Module).
     * @param swapRouter The Uniswap V3 `SwapRouter02` address.
     * See: https://docs.uniswap.org/contracts/v3/reference/deployments/ethereum-deployments
     */
    constructor(
        IGhoFlashMinter flashMinter,
        IGsm gsmUsdc,
        IGsm gsmUsdt,
        ISwapRouter02 swapRouter
    )
        Ownable(msg.sender)
    {
        setForwarder(msg.sender, true);
        GHO_FLASHMINTER = flashMinter;
        GHO = GHO_FLASHMINTER.GHO_TOKEN();
        GSM_USDC = gsmUsdc;
        GSM_USDT = gsmUsdt;
        USDC = IERC20(GSM_USDC.UNDERLYING_ASSET());
        USDT = IERC20(GSM_USDT.UNDERLYING_ASSET());
        SWAP_ROUTER = swapRouter;

        // Infinite approvals
        // Required in `onFlashLoan` step 2 (Swap GHO for USDC)
        GHO.approve(address(SWAP_ROUTER), type(uint256).max);
        // Required in `onFlashLoan` step 3 (Sell USDC for GHO via GHO USDC Stability Module)
        USDC.approve(address(GSM_USDC), type(uint256).max);
        // Required in `onFlashLoan` step 3 (Sell USDT for GHO via GHO USDT Stability Module)
        USDT.forceApprove(address(GSM_USDT), type(uint256).max);
        // Required in `onFlashLoan` step 5 (allow GHO FlashMinter claim their GHO)
        GHO.approve(address(GHO_FLASHMINTER), type(uint256).max);
    }

    /// @inheritdoc AutomationCompatibleInterface
    /// @dev `checkData` is composed by: `abi.encode(
    ///   <uint256:amount>,
    ///   <bytes:abi.encode(<enum:GsmAsset>,<uint256:minProfit>,<bytes:path>)
    /// )`. Where `path` contains the multiple pool swaps encoded (see
    /// https://docs.uniswap.org/contracts/v3/guides/swaps/multihop-swaps#input-parameters).
    /// @dev `checkUpkeep` can't be `view` due to `execute()` state changes. Therefore, `cannotExecute` modifier must be
    /// used instead.
    /// @dev Handle gracefully reverts by returning `(false, 0x)`.
    function checkUpkeep(bytes calldata checkData) external override cannotExecute returns (bool, bytes memory) {
        // NB: Re-encode `incompleteData` including `blockDeadline` (from `block.number`)
        (uint256 amount, bytes memory incompleteData) = abi.decode(checkData, (uint256, bytes));
        (GsmAsset gsmAsset, uint256 minProfit, bytes memory path) =
            abi.decode(incompleteData, (GsmAsset, uint256, bytes));
        bytes memory data = abi.encode(gsmAsset, minProfit, block.number, path);

        bool success; // NB: defaults to `false`
        bytes memory performData; // NB: defaults to `0x`

        try this.execute(amount, data) {
            success = true;
            performData = data;
            // solhint-disable-next-line no-empty-blocks
        } catch {
            // no-op;
        }

        return (success, performData);
    }

    /// @inheritdoc AutomationCompatibleInterface
    function performUpkeep(bytes calldata performData) external override onlyForwarder {
        (uint256 amount, bytes memory data) = abi.decode(performData, (uint256, bytes));
        execute(amount, data);
    }

    /// @inheritdoc IGhoArb
    function execute(uint256 amount, bytes memory data) public onlyForwarder {
        bool success = GHO_FLASHMINTER.flashLoan(this, address(GHO), amount, data);
        // NB: an unsuccessful flash mint should revert rather than return `false`, but just in case its logic is
        // updated
        if (!success) {
            revert Errors.GhoArb_ArbitrageFailed();
        }
    }

    /// @inheritdoc IERC3156FlashBorrower
    /// @dev `data` is composed by: `abi.encode(
    ///   <enum:GsmAsset>,<uint256:minProfit>,<uint256:blockDeadline>,<bytes:path>)
    /// )`. Where `path` contains the multiple pool swaps encoded (see
    /// https://docs.uniswap.org/contracts/v3/guides/swaps/multihop-swaps#input-parameters).
    function onFlashLoan(
        address,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    )
        external
        returns (bytes32)
    {
        (GsmAsset gsmAsset, uint256 minProfit, uint256 blockDeadline, bytes memory path) =
            abi.decode(data, (GsmAsset, uint256, uint256, bytes));

        // 1. Check params
        if (block.number > blockDeadline) {
            revert Errors.GhoArb_BlockDeadlineIsGtBlockNumber(blockDeadline, block.number);
        }

        IGsm gsm;
        // Requires supported GsmAsset
        if (gsmAsset == GsmAsset.USDC) {
            gsm = GSM_USDC;
        } else if (gsmAsset == GsmAsset.USDT) {
            gsm = GSM_USDT;
        } else {
            revert Errors.GhoArb_GsmAssetIsNotSupported(gsmAsset);
        }
        // Requires msg sender is GHO_FLASHMINTER
        if (msg.sender != address(GHO_FLASHMINTER)) {
            revert Errors.GhoArb_MsgSenderIsNotFlashMinter(msg.sender);
        }
        // Requires token param is GHO
        if (token != address(GHO)) {
            revert Errors.GhoArb_TokenIsNotSupported(token);
        }

        // 2. Swap GHO for USDC||USDT using UniswapV3 Multihop Swap
        ISwapRouter02.ExactInputParams memory swapParams = ISwapRouter02.ExactInputParams({
            path: path,
            recipient: address(this),
            amountIn: amount,
            amountOutMinimum: 0 // NB: not needed as long as profit invariants are checked later on
         });
        uint256 swapAmountOut = SWAP_ROUTER.exactInput(swapParams);

        // 3. Sell USDC||USDT for GHO via GHO USDC||USDT Stability Module
        (uint256 swapAmountSold, uint256 ghoBought) = gsm.sellAsset(swapAmountOut, address(this));

        // 4. Check that the entire swap is profitable (function invariants)
        uint256 repayAmount = amount + fee;
        if (ghoBought < repayAmount || ghoBought - repayAmount < minProfit) {
            revert Errors.GhoArb_ProfitIsBelowMinProfit(
                minProfit, amount, fee, swapAmountOut, swapAmountSold, ghoBought
            );
        }

        emit Arbitraged(gsmAsset, minProfit, path, amount, fee, swapAmountOut, swapAmountSold, ghoBought);

        return GHO_FLASHMINTER.CALLBACK_SUCCESS();
    }

    /// @inheritdoc IGhoArb
    function setAllowance(IERC20 token, address spender, bool isSet) external onlyOwner {
        token.forceApprove(spender, isSet ? type(uint256).max : 0);
        emit AllowanceSet(token, spender, isSet);
    }

    /// @inheritdoc IGhoArb
    function withdraw(IERC20 token, address to, uint256 amount) external onlyOwner {
        token.safeTransfer(to, amount);
        emit FundsWithdrawn(token, to, amount);
    }

    /// @inheritdoc ITypeAndVersion
    function typeAndVersion() external pure returns (string memory) {
        return "GhoArb 1.0.0";
    }
}
