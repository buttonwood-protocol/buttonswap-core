// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IButtonswapERC20Errors} from "../IButtonswapERC20/IButtonswapERC20Errors.sol";

interface IButtonswapPairErrors is IButtonswapERC20Errors {
    /**
     * @notice Re-entrancy guard prevented method call
     */
    error Locked();

    /**
     * @notice User does not have permission for the attempted operation
     */
    error Forbidden();

    /**
     * @notice Integer maximums exceeded
     */
    error Overflow();

    /**
     * @notice Initial deposit not yet made
     */
    error Uninitialized();

    /**
     * @notice There was not enough liquidity in the reservoir
     */
    error InsufficientReservoir();

    /**
     * @notice Not enough liquidity was created during mint
     */
    error InsufficientLiquidityMinted();

    /**
     * @notice Not enough funds added to mint new liquidity
     */
    error InsufficientLiquidityAdded();

    /**
     * @notice More liquidity must be burned to be redeemed for non-zero amounts
     */
    error InsufficientLiquidityBurned();

    /**
     * @notice Swap was attempted with zero input
     */
    error InsufficientInputAmount();

    /**
     * @notice Swap was attempted with zero output
     */
    error InsufficientOutputAmount();

    /**
     * @notice Pool doesn't have the liquidity to service the swap
     */
    error InsufficientLiquidity();

    /**
     * @notice The specified "to" address is invalid
     */
    error InvalidRecipient();

    /**
     * @notice The product of pool balances must not change during a swap (save for accounting for fees)
     */
    error KInvariant();

    /**
     * @notice The new price ratio after a swap is invalid (one or more of the price terms are zero)
     */
    error InvalidFinalPrice();

    /**
     * @notice
     */
    error SingleSidedTimelock();
}
