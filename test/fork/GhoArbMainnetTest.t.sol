// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { AaveV3EthereumAssets } from "aave-address-book/src/AaveV3Ethereum.sol";
import { MiscEthereum } from "aave-address-book/src/MiscEthereum.sol";
import { GhoArb } from "src/GhoArb.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Test } from "forge-std/src/Test.sol";

import { IGhoFlashMinter } from "gho-core/contracts/facilitators/flashMinter/interfaces/IGhoFlashMinter.sol";

import { IGsm } from "gho-core/contracts/facilitators/gsm/interfaces/IGsm.sol";
import { IGhoToken } from "gho-core/contracts/gho/interfaces/IGhoToken.sol";

import { INonfungiblePositionManager } from "src/interfaces/external/uniswapV3/INonfungiblePositionManager.sol";
import { ISwapRouter02 } from "src/interfaces/external/uniswapV3/ISwapRouter02.sol";

import { GsmAsset } from "src/libraries/DataTypes.sol";
import { Errors } from "src/libraries/Errors.sol";
import { Token1 } from "test/helper/token/Token1.sol";
import { UniV3DataTypes } from "test/helper/uniswapV3/UniV3DataTypes.sol";
import { IUniswapV3Factory } from "uniswap-v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import { IUniswapV3Pool } from "uniswap-v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import { IQuoterV2 } from "uniswap-v3-periphery/contracts/interfaces/IQuoterV2.sol";

contract GhoArb_Fork_Mainnet_Test is Test {
    IERC20 private constant USDC = IERC20(AaveV3EthereumAssets.USDC_UNDERLYING);
    IERC20 private constant USDT = IERC20(AaveV3EthereumAssets.USDT_UNDERLYING);
    IGhoToken private constant GHO = IGhoToken(AaveV3EthereumAssets.GHO_UNDERLYING);

    IGhoFlashMinter private constant GHO_FLASHMINTER = IGhoFlashMinter(MiscEthereum.GHO_FLASHMINTER_FACILITATOR);

    IGsm private constant GSM_USDC = IGsm(MiscEthereum.GSM_USDC);
    IGsm private constant GSM_USDT = IGsm(MiscEthereum.GSM_USDT);

    IUniswapV3Factory private immutable UNISWAP_FACTORY = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
    // NB: https://docs.uniswap.org/contracts/v3/reference/deployments/ethereum-deployments
    ISwapRouter02 private immutable SWAP_ROUTER = ISwapRouter02(0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45); // NB:
        // SwapRouter02
    IQuoterV2 private immutable QUOTER = IQuoterV2(0x61fFE014bA17989E743c5F6cB21bF9697530B21e);
    INonfungiblePositionManager private immutable POSITION_MANAGER =
        INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

    address private s_user1 = address(1);
    address private s_user2 = address(2);
    address private s_user3 = address(3);

    GhoArb private s_ghoArb;
    Token1 private s_tkn1;

    function setUp() public {
        // 1. Set labels
        vm.label(address(USDC), "USDC");
        vm.label(address(USDT), "USDT");
        vm.label(AaveV3EthereumAssets.GHO_UNDERLYING, "GHO");
        vm.label(MiscEthereum.GHO_FLASHMINTER_FACILITATOR, "GHO FlashMinter");
        vm.label(address(GSM_USDC), "GHO SM USDC");
        vm.label(address(GSM_USDT), "GHO SM USDT");
        vm.label(address(UNISWAP_FACTORY), "UniswapV3 Factory");
        vm.label(address(SWAP_ROUTER), "UniswapV3 SwapRouter02");
        vm.label(address(QUOTER), "UniswapV3 QuoterV2");
        vm.label(address(POSITION_MANAGER), "UniswapV3 PositionManager");
        vm.label(s_user1, "User 1");
        vm.label(s_user2, "User 2");
        vm.label(s_user3, "User 3");

        // NB: from May-11-2024 09:01:59 AM +UTC
        vm.createSelectFork(vm.rpcUrl("mainnet"), 19_845_765);

        // 2. Deploy GHO FlashBorrower
        // Checks for ERC20s fetched addresses during `GhoArb` instantiation
        assertEq(address(GHO_FLASHMINTER.GHO_TOKEN()), address(GHO)); // NB: GHO address is fetched from GHO_FLASHMINTER
        assertEq(GSM_USDC.UNDERLYING_ASSET(), address(USDC)); // NB: USDC address is fetched from GSM_USDC
        assertEq(GSM_USDT.UNDERLYING_ASSET(), address(USDT)); // NB: USDT address is fetched from GSM_USDT

        s_ghoArb = new GhoArb(GHO_FLASHMINTER, GSM_USDC, GSM_USDT, SWAP_ROUTER);
        vm.label(address(s_ghoArb), "GhoArb");

        // 3. Deploy Token1
        // NB: it must be deployed after `s_ghoArb` or `_setUpPool` won't work for an unkwnown reason
        // TODO VN: investigate this
        s_tkn1 = new Token1();
        vm.label(address(s_tkn1), "TKN1");

        // 3. Set up Uniswap V3 pool TKN1:GHO at 10:1 ratio
        uint24 poolFee = uint24(3000); // NB: 500, 3_000 or 10_000
        uint256 poolTkn1Gho_tkn1Liquidity = 1_000_000 ether; // token0
        uint256 poolTkn1Gho_ghoLiquidity = 100_000 ether; // token1
        deal(address(GHO), address(this), poolTkn1Gho_ghoLiquidity);

        // NB: calculated via `encodePriceSqrt(10, 1)`
        uint160 sqrtPriceX96_10_1 = 25_054_144_837_504_793_118_641_380_156;
        address poolTkn1Gho = _setUpPool(
            address(s_tkn1),
            address(GHO),
            poolFee,
            sqrtPriceX96_10_1,
            poolTkn1Gho_tkn1Liquidity,
            poolTkn1Gho_ghoLiquidity
        );
        vm.label(poolTkn1Gho, "UniswapV3 Pool TKN1_GHO");

        // Check TKN1:GHO ratio is 10:1 approx.
        IQuoterV2.QuoteExactInputSingleParams memory quoteParams = IQuoterV2.QuoteExactInputSingleParams({
            tokenIn: address(GHO),
            tokenOut: address(s_tkn1),
            amountIn: 1 ether,
            fee: poolFee,
            sqrtPriceLimitX96: 0
        });
        (uint256 quoteAmountOut,,,) = QUOTER.quoteExactInputSingle(quoteParams);
        assertTrue(quoteAmountOut > 9 ether);

        // 3. Set up Uniswap V3 pool TKN1:USDC at 1:2 ratio
        uint256 poolTkn1Usdc_tkn1Liquidity = 100_000 ether; // token0
        uint256 poolTkn1Usdc_usdcLiquidity = 200_000 * 1e6; // token1
        deal(address(USDC), address(this), poolTkn1Usdc_usdcLiquidity);

        // NB: calculated via `encodePriceSqrt(2, 1000000000000)`
        uint160 sqrtPriceX96_1_2 = 112_045_541_949_572_279_837_463; // NB: calculated via
        address poolTkn1Usdc = _setUpPool(
            address(s_tkn1),
            address(USDC),
            poolFee,
            sqrtPriceX96_1_2,
            poolTkn1Usdc_tkn1Liquidity,
            poolTkn1Usdc_usdcLiquidity
        );
        vm.label(poolTkn1Usdc, "UniswapV3 Pool TKN1_USDC");

        // Check TKN1:GHO ratio is 1:2 approx
        quoteParams = IQuoterV2.QuoteExactInputSingleParams({
            tokenIn: address(s_tkn1),
            tokenOut: address(USDC),
            amountIn: 1 ether,
            fee: poolFee,
            sqrtPriceLimitX96: 0
        });
        (quoteAmountOut,,,) = QUOTER.quoteExactInputSingle(quoteParams);
        assertTrue(quoteAmountOut > 1.9 * 1e6);
    }

    /// @dev sets up a Uniswap V3 pool
    function _setUpPool(
        address token0,
        address token1,
        uint24 fee,
        uint160 sqrtPriceX96,
        uint256 amount0Desired,
        uint256 amount1Desired
    )
        internal
        returns (address)
    {
        address pool = POSITION_MANAGER.createAndInitializePoolIfNecessary(token0, token1, fee, sqrtPriceX96);
        assertEq(IUniswapV3Pool(pool).token0(), token0);
        assertEq(IUniswapV3Pool(pool).token1(), token1);

        IERC20(token0).approve(address(POSITION_MANAGER), amount0Desired);
        IERC20(token1).approve(address(POSITION_MANAGER), amount1Desired);

        INonfungiblePositionManager.MintParams memory mintParams = INonfungiblePositionManager.MintParams({
            token0: token0,
            token1: token1,
            fee: fee,
            tickLower: (UniV3DataTypes.MIN_TICK / UniV3DataTypes.TICK_SPACING) * UniV3DataTypes.TICK_SPACING,
            tickUpper: (UniV3DataTypes.MAX_TICK / UniV3DataTypes.TICK_SPACING) * UniV3DataTypes.TICK_SPACING,
            amount0Desired: amount0Desired,
            amount1Desired: amount1Desired,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(this),
            deadline: block.timestamp
        });
        POSITION_MANAGER.mint(mintParams);

        return pool;
    }

    /// @dev step 1: flashMint (1000 GHO)
    /// @dev step 2: swap1 (1000 GHO -> N TKN1), swap 2 (N TKN1 -> M USDC)
    /// @dev step 3: sells (M USDC -> X GHO)
    function test_successfulSwap1() external {
        // Arrange
        uint256 amount = 1000 ether; // NB: 1000 GHO
        uint256 minProfit = 10 ether; // NB: 10 GHO
        uint256 ghoBalanceBefore = GHO.balanceOf(address(s_ghoArb));
        bytes memory path = abi.encodePacked(address(GHO), uint24(3000), address(s_tkn1), uint24(3000), address(USDC));
        bytes memory data = abi.encode(GsmAsset.USDC, minProfit, block.number, path);

        // Act
        s_ghoArb.execute(amount, data);

        // Assert
        // There is profit
        uint256 ghoBalanceAfter = GHO.balanceOf(address(s_ghoArb));
        assertEq(ghoBalanceAfter, 16_884_388_025_036_000_000_000);
        assertTrue(ghoBalanceAfter >= ghoBalanceBefore + minProfit);

        // Act
        s_ghoArb.withdraw(IERC20(address(GHO)), s_user1, ghoBalanceAfter);

        // Assert
        // GHO was transferred from GhoArb to User 1
        assertEq(GHO.balanceOf(address(s_ghoArb)), 0);
        assertEq(GHO.balanceOf(s_user1), ghoBalanceAfter);
    }

    /// @dev Reverts due to swap not being profitable.
    /// @dev step 1: flashMint (1000 GHO)
    /// @dev step 2: swap1 (1000 GHO -> N TKN1), swap 2 (N TKN1 -> M USDC)
    /// @dev step 3: sells (M USDC -> X GHO)
    function test_unsuccessfulSwap1() external {
        // Arrange
        uint256 expectedProfit = 16_884_388_025_036_000_000_000;
        uint256 expectedSwapAmountOut = 17_920_228_482;
        uint256 expectedSwapAmountSold = 17_920_228_482;
        uint256 expectedGhoBought = 17_884_388_025_036_000_000_000;
        uint256 fee = GHO_FLASHMINTER.getFee();
        uint256 amount = 1000 ether; // NB: 1000 GHO
        uint256 minProfit = expectedProfit + 1; // NB: force revert
        bytes memory path = abi.encodePacked(address(GHO), uint24(3000), address(s_tkn1), uint24(3000), address(USDC));
        bytes memory data = abi.encode(GsmAsset.USDC, minProfit, block.number, path);

        // Act
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.GhoArb_ProfitIsBelowMinProfit.selector,
                minProfit,
                amount,
                fee,
                expectedSwapAmountOut,
                expectedSwapAmountSold,
                expectedGhoBought
            )
        );
        s_ghoArb.execute(amount, data);

        // Assert
        assertEq(GHO.balanceOf(address(s_ghoArb)), 0);
    }

    /// @dev Reverts due to `block.number > blockDeadline`.
    /// @dev step 1: flashMint (1000 GHO)
    /// @dev step 2: swap1 (1000 GHO -> N TKN1), swap 2 (N TKN1 -> M USDC)
    /// @dev step 3: sells (M USDC -> X GHO)
    function test_unsuccessfulSwap2() external {
        // Arrange
        uint256 amount = 1000 ether; // NB: 1000 GHO
        uint256 minProfit = 10 ether; // NB: 10 GHO
        uint256 blockNumber = block.number;
        uint256 blockDeadline = blockNumber - 1; // NB: force revert
        bytes memory path = abi.encodePacked(address(GHO), uint24(3000), address(s_tkn1), uint24(3000), address(USDC));
        bytes memory data = abi.encode(GsmAsset.USDC, minProfit, blockDeadline, path);

        // Act
        vm.expectRevert(
            abi.encodeWithSelector(Errors.GhoArb_BlockDeadlineIsGtBlockNumber.selector, blockDeadline, blockNumber)
        );
        s_ghoArb.execute(amount, data);

        // Assert
        assertEq(GHO.balanceOf(address(s_ghoArb)), 0);
    }
}
