// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.10;

import "./IButtonswapERC20.sol";

interface IButtonswapPair is IButtonswapERC20 {
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

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 pool0, uint112 pool1);
    event SyncReservoir(uint112 reservoir0, uint112 reservoir1);

    function MINIMUM_LIQUIDITY() external pure returns (uint256);

    function factory() external view returns (address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function getPools() external view returns (uint112 poolA, uint112 poolB, uint32 blockTimestampLast);

    function getReservoirs() external view returns (uint112 reservoirA, uint112 reservoirB);

    function price0CumulativeLast() external view returns (uint256);

    function price1CumulativeLast() external view returns (uint256);

    function kLast() external view returns (uint256);

    function mint(address to) external returns (uint256 liquidity);

    function mintWithReservoir(address to) external returns (uint256 liquidity);

    function burn(address to) external returns (uint256 amountA, uint256 amountB);

    function burnFromReservoir(address to) external returns (uint256 amountA, uint256 amountB);

    function swap(uint256 amountAOut, uint256 amountBOut, address to, bytes calldata data) external;

    function sync() external;

    function initialize(address, address) external;
}
