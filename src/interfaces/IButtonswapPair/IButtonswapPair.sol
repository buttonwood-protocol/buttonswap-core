// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IButtonswapPairErrors} from "./IButtonswapPairErrors.sol";
import {IButtonswapPairEvents} from "./IButtonswapPairEvents.sol";
import {IButtonswapERC20} from "../IButtonswapERC20/IButtonswapERC20.sol";

interface IButtonswapPair is IButtonswapPairErrors, IButtonswapPairEvents, IButtonswapERC20 {
    /**
     * @notice The smallest value that {IButtonswapERC20-totalSupply} can be.
     * @dev After the first mint the total liquidity (represented by the liquidity token total supply) can never drop below this value.
     *
     * This is to protect against an attack where the attacker mints a very small amount of liquidity, and then donates pool tokens to skew the ratio.
     * This results in future minters receiving no liquidity tokens when they deposit.
     * By enforcing a minimum liquidity value this attack becomes prohibitively expensive to execute.
     * @return MINIMUM_LIQUIDITY The MINIMUM_LIQUIDITY value
     */
    function MINIMUM_LIQUIDITY() external pure returns (uint256 MINIMUM_LIQUIDITY);

    /**
     * @notice The address of the {ButtonswapFactory} instance used to create this Pair.
     * @dev Set to `msg.sender` in the Pair constructor.
     * @return factory The factory address
     */
    function factory() external view returns (address factory);

    /**
     * @notice The address of the first sorted token.
     * @return token0 The token address
     */
    function token0() external view returns (address token0);

    /**
     * @notice The address of the second sorted token.
     * @return token1 The token address
     */
    function token1() external view returns (address token1);

    /**
     * @notice Get the current active liquidity values.
     * The ratio of these two values is the current price of the Pair.
     * @return _pool0 The active `token0` liquidity
     * @return _pool1 The active `token1` liquidity
     * @return _blockTimestampLast The timestamp of when the price was last updated
     */
    function getPools() external view returns (uint112 _pool0, uint112 _pool1, uint32 _blockTimestampLast);

    /**
     * @notice Get the current inactive liquidity values.
     * @return _reservoir0 The inactive `token0` liquidity
     * @return _reservoir1 The inactive `token1` liquidity
     */
    function getReservoirs() external view returns (uint112 _reservoir0, uint112 _reservoir1);

    /**
     * @notice The time-weighted average price of the Pair.
     * The price is of `token0` in terms of `token1`.
     * @dev The price is represented as a [UQ112x112](https://en.wikipedia.org/wiki/Q_(number_format)) to maintain precision.
     * Consequently this value must be divided by `2^112` to get the actual price.
     *
     * Because of the time weighting, `price0CumulativeLast` must also be divided by the total Pair lifetime to get the average price over that time period.
     * @return price0CumulativeLast The current cumulative `token0` price
     */
    function price0CumulativeLast() external view returns (uint256 price0CumulativeLast);

    /**
     * @notice The time-weighted average price of the Pair.
     * The price is of `token1` in terms of `token0`.
     * @dev The price is represented as a [UQ112x112](https://en.wikipedia.org/wiki/Q_(number_format)) to maintain precision.
     * Consequently this value must be divided by `2^112` to get the actual price.
     *
     * Because of the time weighting, `price1CumulativeLast` must also be divided by the total Pair lifetime to get the average price over that time period.
     * @return price1CumulativeLast The current cumulative `token1` price
     */
    function price1CumulativeLast() external view returns (uint256 price1CumulativeLast);

    /**
     * @notice TODO
     * @dev TODO
     * @return kLast TODO
     */
    function kLast() external view returns (uint256 kLast);

    /**
     * @notice Mints new liquidity tokens to `to` based on how much `token0` and `token1` has been deposited.
     * Expects both tokens to be deposited in a ratio that matches the current Pair price.
     * @dev The token deposits are deduced to be the delta between the current Pair contract token balances and the last stored balances.
     * Refer to [mint-math.md](https://github.com/buttonwood-protocol/buttonswap-core/blob/main/notes/mint-math.md#dual-sided-mint) for more detail.
     * @param to The account that receives the newly minted liquidity tokens
     * @return liquidity THe amount of liquidity tokens minted
     */
    function mint(address to) external returns (uint256 liquidity);

    /**
     * @notice Mints new liquidity tokens to `to` based on how much `token0` and `token1` has been deposited.
     * Expects only one token to be deposited, so that it can be paired with the other token's inactive liquidity.
     * @dev The token deposits are deduced to be the delta between the current Pair contract token balances and the last stored balances.
     * Refer to [mint-math.md](https://github.com/buttonwood-protocol/buttonswap-core/blob/main/notes/mint-math.md#single-sided-mint) for more detail.
     * @param to The account that receives the newly minted liquidity tokens
     * @return liquidity THe amount of liquidity tokens minted
     */
    function mintWithReservoir(address to) external returns (uint256 liquidity);

    /**
     * @notice Burns deposited liquidity tokens to redeem to `to` the corresponding `amount0` of `token0` and `amount1` of `token1`.
     * @dev The token deposit is deduced to be the current Pair contract liquidity token balance, as this is the only time the contract should own liquidity tokens.
     * Refer to [burn-math.md](https://github.com/buttonwood-protocol/buttonswap-core/blob/main/notes/burn-math.md#dual-sided-burn) for more detail.
     * @param to The account that receives the redeemed tokens
     * @return amount0 The amount of `token0` that the liquidity tokens are redeemed for
     * @return amount1 The amount of `token1` that the liquidity tokens are redeemed for
     */
    function burn(address to) external returns (uint256 amount0, uint256 amount1);

    /**
     * @notice Burns deposited liquidity tokens to redeem to `to` the corresponding `amount0` of `token0` and `amount1` of `token1`.
     * Only returns tokens from the non-zero inactive liquidity balance, meaning one of `amount0` and `amount1` will be zero.
     * @dev The token deposit is deduced to be the current Pair contract liquidity token balance, as this is the only time the contract should own liquidity tokens.
     * Refer to [burn-math.md](https://github.com/buttonwood-protocol/buttonswap-core/blob/main/notes/burn-math.md#single-sided-burn) for more detail.
     * @param to The account that receives the redeemed tokens
     * @return amount0 The amount of `token0` that the liquidity tokens are redeemed for
     * @return amount1 The amount of `token1` that the liquidity tokens are redeemed for
     */
    function burnFromReservoir(address to) external returns (uint256 amount0, uint256 amount1);

    /**
     * @notice Swaps one token for the other, sending `amount0Out` of `token0` and `amount1Out` of `token1` to `to`.
     * The price of the swap is determined by maintaining the "K Invariant".
     * A 0.3% fee is collected to distribute between liquidity providers and the protocol.
     * @dev The token deposits are deduced to be the delta between the current Pair contract token balances and the last stored balances.
     * Optional calldata can be passed to `data`, which will be used to confirm the output token transfer with `to` if `to` is a contract that implements the {IButtonswapCallee} interface.
     * Refer to [mint-math.md](https://github.com/buttonwood-protocol/buttonswap-core/blob/main/notes/swap-math.md) for more detail.
     * @param amount0Out The amount of `token0` that the recipient receives
     * @param amount1Out The amount of `token1` that the recipient receives
     * @param to The account that receives the swap output
     * @param data Optional calldata that can be used to confirm the token transfer with `to`
     */
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;

    /**
     * @notice TODO
     * @dev TODO
     */
    function sync() external;

    /**
     * @notice Called during Pair deployment to initialize the new instance.
     * @param _token0 The address for `token0`
     * @param _token1 The address for `token1`
     */
    function initialize(address _token0, address _token1) external;
}
