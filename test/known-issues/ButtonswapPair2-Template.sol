// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {IButtonswapPairEvents, IButtonswapPairErrors} from "../../src/interfaces/IButtonswapPair/IButtonswapPair.sol";
import {ButtonswapPair2} from "../../src/ButtonswapPair2.sol";
import {Math} from "../../src/libraries/Math.sol";
import {MockERC20} from "mock-contracts/MockERC20.sol";
import {ICommonMockRebasingERC20} from "mock-contracts/interfaces/ICommonMockRebasingERC20/ICommonMockRebasingERC20.sol";
import {MockButtonswapFactory} from "../mocks/MockButtonswapFactory.sol";
import {Utils} from "../utils/Utils.sol";
import {PairMath} from "../utils/PairMath.sol";
import {PriceAssertion} from "../utils/PriceAssertion.sol";
import {UQ112x112} from "../../src/libraries/UQ112x112.sol";

// This defines the tests but this contract is abstract because multiple implementations using different rebasing token types run them
abstract contract ButtonswapPair2Test is Test, IButtonswapPairEvents, IButtonswapPairErrors {
    struct TestVariables {
        address zeroAddress;
        address feeToSetter;
        address feeTo;
        address minter1;
        address minter2;
        address swapper1;
        address swapper2;
        address receiver;
        address burner1;
        address burner2;
        address exploiter;
        MockButtonswapFactory factory;
        ButtonswapPair2 pair;
        MockERC20 token0;
        MockERC20 token1;
        ICommonMockRebasingERC20 rebasingToken0;
        ICommonMockRebasingERC20 rebasingToken1;
        uint256 amount0In;
        uint256 amount1In;
        uint256 amount0Out;
        uint256 amount1Out;
        uint256 liquidity1;
        uint256 liquidity2;
        uint256 pool0;
        uint256 pool1;
        uint256 reservoir0;
        uint256 reservoir1;
    }

    MockERC20 public tokenA;
    MockERC20 public tokenB;
    ICommonMockRebasingERC20 public rebasingTokenA;
    ICommonMockRebasingERC20 public rebasingTokenB;
    address public userA = 0x000000000000000000000000000000000000000A;
    address public userB = 0x000000000000000000000000000000000000000b;
    address public userC = 0x000000000000000000000000000000000000000C;
    address public userD = 0x000000000000000000000000000000000000000d;
    address public userE = 0x000000000000000000000000000000000000000E;

    function getTokenA() public virtual returns (MockERC20) {
        return new MockERC20("TokenA", "TKNA");
    }

    function getTokenB() public virtual returns (MockERC20) {
        return new MockERC20("TokenB", "TKNB");
    }

    function getRebasingTokenA() public virtual returns (ICommonMockRebasingERC20) {
        return ICommonMockRebasingERC20(address(0));
    }

    function getRebasingTokenB() public virtual returns (ICommonMockRebasingERC20) {
        return ICommonMockRebasingERC20(address(0));
    }

    function setUp() public {
        tokenA = getTokenA();
        tokenA.initialize();
        tokenB = getTokenB();
        tokenB.initialize();
        rebasingTokenA = getRebasingTokenA();
        rebasingTokenA.initialize();
        rebasingTokenB = getRebasingTokenB();
        rebasingTokenB.initialize();
    }

    // TODO progress cutoff point

    function test_exploit_CanMintUsingUnaccountedSurplusIfSyncNotCalled(
        uint256 amount00,
        uint256 amount01,
        uint256 rebaseNumerator,
        uint256 rebaseDenominator
    ) public {
        // Make sure the amounts aren't liable to overflow 2**112
        // Divide by 4 so that it can handle a second mint
        // Divide by 1000 so that it can handle a rebase
        vm.assume(amount00 < (uint256(2 ** 112) / (4 * 1000)));
        vm.assume(amount01 < (uint256(2 ** 112) / (4 * 1000)));
        // Amounts must be non-zero
        // They must also be sufficient for equivalent liquidity to exceed the MINIMUM_LIQUIDITY
        vm.assume(Math.sqrt(amount00 * amount01) > 1000);
        // Keep rebase factor in sensible range
        vm.assume(rebaseNumerator > 0 && rebaseNumerator < 1000);
        vm.assume(rebaseDenominator > 0 && rebaseDenominator < 1000);
        // Requires positive rebase
        vm.assume(rebaseNumerator > rebaseDenominator);

        TestVariables memory vars;
        vars.feeToSetter = userA;
        vars.feeTo = userB;
        vars.minter1 = userC;
        vars.exploiter = userD;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair(vars.factory.createPair(address(rebasingTokenA), address(tokenB)));
        vars.rebasingToken0 = ICommonMockRebasingERC20(vars.pair.token0());
        vars.token1 = MockERC20(vars.pair.token1());
        vm.assume(amount00 < vars.rebasingToken0.mintableBalance());
        vars.rebasingToken0.mint(vars.minter1, amount00);
        vars.token1.mint(vars.minter1, amount01);

        // Mint initial liquidity
        vm.startPrank(vars.minter1);
        vars.rebasingToken0.transfer(address(vars.pair), amount00);
        vars.token1.transfer(address(vars.pair), amount01);
        vars.liquidity1 = vars.pair.mint(vars.minter1);
        vm.stopPrank();

        // Rebase
        vars.rebasingToken0.applyMultiplier(rebaseNumerator, rebaseDenominator);
        // Sync to make a reservoir have non-zero value
        vars.pair.sync();
        // Rebase again
        vars.rebasingToken0.applyMultiplier(rebaseNumerator, rebaseDenominator);
        // Don't call sync this time

        (vars.pool0, vars.pool1,) = vars.pair.getPools();
        (vars.reservoir0, vars.reservoir1) = vars.pair.getReservoirs();
        // Calculate how much the unaccounted surplus is
        uint256 amount10 = vars.rebasingToken0.balanceOf(address(vars.pair)) - vars.pool0 - vars.reservoir0;
        // Calculate the amount of the other token required to mint liquidity against the surplus amount
        uint256 amount11 = (amount10 * vars.pool1) / vars.pool0;
        // Mint the exploiter this token amount
        vm.assume(amount11 < vars.token1.mintableBalance());
        vars.token1.mint(vars.exploiter, amount11);

        // Save off exploiter token holdings value in terms of 0
        uint256 originalExploiterHoldingsInTermsOf0 = vars.rebasingToken0.balanceOf(vars.exploiter);
        originalExploiterHoldingsInTermsOf0 += (vars.token1.balanceOf(vars.exploiter) * vars.pool0) / vars.pool1;

        // Exploiter mints using unaccounted surplus
        vm.startPrank(vars.exploiter);
        // Despite being a dual sided mint we only transfer in one token to match the unaccounted rebase surplus
        vars.token1.transfer(address(vars.pair), amount11);
        vars.liquidity2 = vars.pair.mint(vars.exploiter);
        vm.stopPrank();

        // Exploiter burns liquidity
        vm.startPrank(vars.exploiter);
        // Exploiter sends back the liquidity tokens it just minted
        vars.pair.transfer(address(vars.pair), vars.pair.balanceOf(vars.exploiter));
        vars.pair.burn(vars.exploiter);
        vm.stopPrank();

        // Calculate new exploiter token holdings value in terms of 0
        (vars.pool0, vars.pool1,) = vars.pair.getPools();
        uint256 newExploiterHoldingsInTermsOf0 = vars.rebasingToken0.balanceOf(vars.exploiter);
        newExploiterHoldingsInTermsOf0 += (vars.token1.balanceOf(vars.exploiter) * vars.pool0) / vars.pool1;

        // If there was no exploit the exploiter would have not gained value during this
        assertLe(newExploiterHoldingsInTermsOf0, originalExploiterHoldingsInTermsOf0, "Exploiter has not gained value");
    }

    function test__mintFee_DoesNotCollectFeeFromRebasing(
        uint256 mintAmount00,
        uint256 mintAmount01,
        uint256 rebaseNumerator0,
        uint256 rebaseDenominator0,
        uint256 rebaseNumerator1,
        uint256 rebaseDenominator1
    ) public {
        // Make sure the amounts aren't liable to overflow 2**112
        // Div by 2 to have room for two mints
        vm.assume(mintAmount00 < uint256(2 ** 112) / 2);
        vm.assume(mintAmount01 < uint256(2 ** 112) / 2);
        // Amounts must be non-zero, and must exceed minimum liquidity
        vm.assume(mintAmount00 > 1000);
        vm.assume(mintAmount01 > 1000);
        // Keep rebase factor in sensible range
        rebaseNumerator0 = bound(rebaseNumerator0, 1, 1000);
        rebaseDenominator0 = bound(rebaseDenominator0, 1, 1000);
        rebaseNumerator1 = bound(rebaseNumerator1, 1, 1000);
        rebaseDenominator1 = bound(rebaseDenominator1, 1, 1000);

        TestVariables memory vars;
        vars.feeToSetter = userA;
        vars.feeTo = userB;
        vars.minter1 = userC;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair(vars.factory.createPair(address(rebasingTokenA), address(rebasingTokenB)));
        vars.rebasingToken0 = ICommonMockRebasingERC20(vars.pair.token0());
        vars.rebasingToken1 = ICommonMockRebasingERC20(vars.pair.token1());
        vm.assume(mintAmount00 <= vars.rebasingToken0.mintableBalance());
        vars.rebasingToken0.mint(vars.minter1, mintAmount00);
        vm.assume(mintAmount01 <= vars.rebasingToken1.mintableBalance());
        vars.rebasingToken1.mint(vars.minter1, mintAmount01);

        // Mint initial liquidity
        vm.startPrank(vars.minter1);
        vars.rebasingToken0.transfer(address(vars.pair), mintAmount00);
        vars.rebasingToken1.transfer(address(vars.pair), mintAmount01);
        vars.pair.mint(vars.minter1);
        vm.stopPrank();

        // Stash the current K value
        (vars.pool0, vars.pool1,) = vars.pair.getPools();
        uint256 kLast = vars.pool0 * vars.pool1;

        // Apply rebase
        vars.rebasingToken0.applyMultiplier(rebaseNumerator0, rebaseDenominator0);
        vars.rebasingToken1.applyMultiplier(rebaseNumerator1, rebaseDenominator1);
        // Do sync
        vars.pair.sync();

        // Estimate fee
        (vars.pool0, vars.pool1,) = vars.pair.getPools();
        (vars.reservoir0, vars.reservoir1) = vars.pair.getReservoirs();
        uint256 k = vars.pool0 * vars.pool1;
        // K must increase for the fee calculation to work
        vm.assume(k > kLast);
        uint256 expectedFeeToBalance = PairMath.getProtocolFeeLiquidityMinted(vars.pair.totalSupply(), kLast, k);
        // Filter for scenarios where the gain in tokens from rebase would cause protocol fee to be generated if K is handled naively
        vm.assume(expectedFeeToBalance > 0);

        // Grant the minter tokens for a second mint
        // Scale down by 10
        uint256 mintAmount10 = vars.pool0 / 10;
        uint256 mintAmount11 = (mintAmount10 * vars.pool1) / vars.pool0;
        vm.assume(mintAmount10 <= vars.rebasingToken0.mintableBalance());
        vars.rebasingToken0.mint(vars.minter1, mintAmount10);
        vm.assume(mintAmount11 <= vars.rebasingToken1.mintableBalance());
        vars.rebasingToken1.mint(vars.minter1, mintAmount11);

        // Calculate expected liquidity amount to make sure it's non-zero
        uint256 liquidityNew = PairMath.getNewDualSidedLiquidityAmount(
            vars.pair.totalSupply(), mintAmount11, vars.pool1, vars.pool0, vars.reservoir1, vars.reservoir0
        );
        vm.assume(liquidityNew > 0);

        // Mint liquidity again to trigger the protocol fee being updated
        vm.startPrank(vars.minter1);
        vars.rebasingToken0.transfer(address(vars.pair), mintAmount10);
        vars.rebasingToken1.transfer(address(vars.pair), mintAmount11);
        vars.pair.mint(vars.minter1);
        vm.stopPrank();

        // Confirm new state is as expected
        assertEq(vars.pair.balanceOf(vars.feeTo), 0);
    }

    function test_mint_FullRebasingSecondMint(
        uint256 amount00,
        uint256 amount01,
        uint256 rebaseNumerator0,
        uint256 rebaseDenominator0,
        uint256 rebaseNumerator1,
        uint256 rebaseDenominator1
    ) public {
        // Make sure the amounts aren't liable to overflow 2**112
        // Divide by 4 so that it can handle a second mint
        // Divide by 1000 so that it can handle a rebase
        vm.assume(amount00 < (uint256(2 ** 112) / (4 * 1000)));
        vm.assume(amount01 < (uint256(2 ** 112) / (4 * 1000)));
        // Amounts must be non-zero
        // They must also be sufficient for equivalent liquidity to exceed the MINIMUM_LIQUIDITY
        vm.assume(Math.sqrt(amount00 * amount01) > 1000);
        // Keep rebase factor in sensible range
        rebaseNumerator0 = bound(rebaseNumerator0, 1, 1000);
        rebaseDenominator0 = bound(rebaseDenominator0, 1, 1000);
        rebaseNumerator1 = bound(rebaseNumerator1, 1, 1000);
        rebaseDenominator1 = bound(rebaseDenominator1, 1, 1000);

        TestVariables memory vars;
        vars.feeToSetter = userA;
        // @TODO test does not currently work due to bug in contract where fee is collected on rebases, not only swaps
        vars.feeTo = userB;
        vars.minter1 = userC;
        vars.minter2 = userD;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair(vars.factory.createPair(address(rebasingTokenA), address(rebasingTokenB)));
        vars.rebasingToken0 = ICommonMockRebasingERC20(vars.pair.token0());
        vars.rebasingToken1 = ICommonMockRebasingERC20(vars.pair.token1());
        vm.assume(amount00 < vars.rebasingToken0.mintableBalance());
        vm.assume(amount01 < vars.rebasingToken1.mintableBalance());
        vars.rebasingToken0.mint(vars.minter1, amount00);
        vars.rebasingToken1.mint(vars.minter1, amount01);

        vm.startPrank(vars.minter1);
        vars.rebasingToken0.transfer(address(vars.pair), amount00);
        vars.rebasingToken1.transfer(address(vars.pair), amount01);
        vars.liquidity1 = vars.pair.mint(vars.minter1);
        vm.stopPrank();

        // Rebase
        vars.rebasingToken0.applyMultiplier(rebaseNumerator0, rebaseDenominator0);
        vars.rebasingToken1.applyMultiplier(rebaseNumerator1, rebaseDenominator1);
        // Sync
        vars.pair.sync();

        (vars.pool0, vars.pool1,) = vars.pair.getPools();
        (vars.reservoir0, vars.reservoir1) = vars.pair.getReservoirs();
        // Ignore edge cases where negative rebase removes all liquidity
        vm.assume(vars.pool0 > 0 && vars.pool1 > 0);

        // Second mint needs to match new price ratio
        uint256 amount10 = vars.pool0 * 3;
        uint256 amount11 = vars.pool1 * 3;
        vm.assume(amount10 < vars.rebasingToken0.mintableBalance());
        vm.assume(amount11 < vars.rebasingToken1.mintableBalance());
        vars.rebasingToken0.mint(vars.minter2, amount10);
        vars.rebasingToken1.mint(vars.minter2, amount11);

        // Calculate expected values to assert against
        (vars.pool0, vars.pool1,) = vars.pair.getPools();
        (vars.reservoir0, vars.reservoir1) = vars.pair.getReservoirs();
        uint256 pool0New = vars.pool0 + amount10;
        uint256 pool1New = vars.pool1 + amount11;
        uint256 reservoir0New = vars.reservoir0;
        uint256 reservoir1New = vars.reservoir1;
        // After first mint subsequent liquidity is calculated based on ratio of value added to value already in pair
        uint256 liquidityNew = PairMath.getNewDualSidedLiquidityAmount(
            vars.pair.totalSupply(), amount11, vars.pool1, vars.pool0, vars.reservoir1, vars.reservoir0
        );
        vm.assume(liquidityNew > 0);

        vm.startPrank(vars.minter2);
        vars.rebasingToken0.transfer(address(vars.pair), amount10);
        vars.rebasingToken1.transfer(address(vars.pair), amount11);
        vm.expectEmit(true, true, true, true);
        emit Mint(vars.minter2, amount10, amount11);
        vars.liquidity2 = vars.pair.mint(vars.minter2);
        vm.stopPrank();

        // 1000 liquidity was minted to zero address instead of minter1
        assertEq(vars.pair.totalSupply(), vars.liquidity1 + vars.liquidity2 + 1000, "totalSupply");
        assertEq(vars.pair.balanceOf(vars.zeroAddress), 1000);
        assertEq(vars.pair.balanceOf(vars.feeToSetter), 0);
        // There should be no fee collected on balance increases that occur outside of a swap
        // @TODO test does not currently work due to bug in contract where fee is collected on rebases, not only swaps
        assertEq(vars.pair.balanceOf(vars.feeTo), 0);
        assertEq(vars.pair.balanceOf(vars.minter1), vars.liquidity1);
        assertEq(vars.pair.balanceOf(vars.minter2), vars.liquidity2);
        (vars.pool0, vars.pool1,) = vars.pair.getPools();
        (vars.reservoir0, vars.reservoir1) = vars.pair.getReservoirs();
        assertEq(vars.pool0, pool0New, "pool0");
        assertEq(vars.pool1, pool1New, "pool1");
        assertEq(vars.reservoir0, reservoir0New, "reservoir0");
        assertEq(vars.reservoir1, reservoir1New, "reservoir1");
        assertEq(vars.liquidity2, liquidityNew, "liquidity2");
    }

    // TODO doesn't fail every time but with enough runs fuzzer will pick values that result in price change tolerance being violated
    function test_sync_FullRebasing(
        uint256 mintAmount0,
        uint256 mintAmount1,
        address syncer,
        uint256 rebaseNumerator0,
        uint256 rebaseDenominator0,
        uint256 rebaseNumerator1,
        uint256 rebaseDenominator1
    ) public {
        // Make sure the amounts aren't liable to overflow 2**112
        vm.assume(mintAmount0 < (2 ** 111));
        vm.assume(mintAmount1 < (2 ** 111));
        // Amounts must be non-zero, and must exceed minimum liquidity
        vm.assume(mintAmount0 > 1000);
        vm.assume(mintAmount1 > 1000);
        // Keep rebase factor in sensible range
        rebaseNumerator0 = bound(rebaseNumerator0, 1, 1000);
        rebaseDenominator0 = bound(rebaseDenominator0, 1, 1000);
        rebaseNumerator1 = bound(rebaseNumerator1, 1, 1000);
        rebaseDenominator1 = bound(rebaseDenominator1, 1, 1000);

        TestVariables memory vars;
        vars.feeToSetter = userA;
        vars.feeTo = userB;
        vars.minter1 = userC;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair(vars.factory.createPair(address(rebasingTokenA), address(rebasingTokenB)));
        vars.rebasingToken0 = ICommonMockRebasingERC20(vars.pair.token0());
        vars.rebasingToken1 = ICommonMockRebasingERC20(vars.pair.token1());
        vm.assume(mintAmount0 <= vars.rebasingToken0.mintableBalance());
        vars.rebasingToken0.mint(vars.minter1, mintAmount0);
        vm.assume(mintAmount1 <= vars.rebasingToken1.mintableBalance());
        vars.rebasingToken1.mint(vars.minter1, mintAmount1);

        // Mint initial liquidity
        vm.startPrank(vars.minter1);
        vars.rebasingToken0.transfer(address(vars.pair), mintAmount0);
        vars.rebasingToken1.transfer(address(vars.pair), mintAmount1);
        vars.pair.mint(vars.minter1);
        vm.stopPrank();

        // Store current state for later comparison
        (uint112 pool0, uint112 pool1,) = vars.pair.getPools();
        (uint112 reservoir0, uint112 reservoir1) = vars.pair.getReservoirs();
        uint112 pool0Previous = pool0;
        uint112 pool1Previous = pool1;

        // Apply rebase
        vars.rebasingToken0.applyMultiplier(rebaseNumerator0, rebaseDenominator0);
        vars.rebasingToken1.applyMultiplier(rebaseNumerator1, rebaseDenominator1);

        // Do sync
        vm.prank(syncer);
        // Predicting final pool and reservoir values is too complex to test
        vm.expectEmit(false, false, false, false);
        emit Sync(0, 0);
        vm.expectEmit(false, false, false, false);
        emit SyncReservoir(0, 0);
        vars.pair.sync();

        // Confirm final state meets expectations
        (pool0, pool1,) = vars.pair.getPools();
        (reservoir0, reservoir1) = vars.pair.getReservoirs();
        // At least one reservoir is 0
        assert(reservoir0 == 0 || reservoir1 == 0);
        // Price hasn't changed
        assertEq(
            PriceAssertion.isPriceUnchanged(reservoir0, pool0Previous, pool1Previous, pool0, pool1),
            true,
            "New price outside of tolerance"
        );
    }
}
