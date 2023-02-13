// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.10;

import "../IButtonswapERC20/IButtonswapERC20Errors.sol";

interface IButtonswapPairErrors is IButtonswapERC20Errors {
    /// @notice Re-entrancy guard prevented method call
    error Locked();

    /// @notice Token transfer failed
    error TransferFailed();

    /// @notice User does not have permission for the attempted operation
    error Forbidden();

    /// @notice Integer maximums exceeded
    error Overflow();

    /// @notice At least one reservoir should always be empty
    error ReservoirInvariant();

    /// @notice Initial deposit not yet made
    error Uninitialized();

    /// @notice The internal balances don't match the actual balance for token0
    error Token0BalanceMismatch();

    /// @notice The internal balances don't match the actual balance for token1
    error Token1BalanceMismatch();

    /// @notice Mint was attempted with mismatched value on each side
    error UnequalMint();

    /// @notice Can't reservoir mint liquidity with both tokens
    error TwoSidedReservoirMint();

    /// @notice There was not enough liquidity in the reservoir
    error InsufficientReservoir();

    /// @notice Not enough liquidity was created during mint
    error InsufficientLiquidityMinted();

    /// @notice Not enough funds added to mint new liquidity
    error InsufficientLiquidityAdded();

    /// @notice More liquidity must be burned to be redeemed for non-zero amounts
    error InsufficientLiquidityBurned();

    /// @notice Swap was attempted with zero input
    error InsufficientInputAmount();

    /// @notice Swap was attempted with zero output
    error InsufficientOutputAmount();

    /// @notice Pool doesn't have the liquidity to service the swap
    error InsufficientLiquidity();

    /// @notice The specified "to" address is invalid
    error InvalidRecipient();

    /// @notice The product of pool balances must not change during a swap (save for accounting for fees)
    error KInvariant();
}
