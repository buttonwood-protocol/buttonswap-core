# Pausing

## Purpose
Pausing is a restricted, permission mechanism that allows a single address (`isPausedSetter` inside of `ButtonswapFactory.sol`) to block ButtonswapPair interactions while maintaining users' ability to withdraw assets. It exists as a responsive measure to potential abuse on a ButtonswapPair.

Pausing prevents all mints, reservoir-interactions, and swaps from executing on a ButtonswapPair. Dual-sided burn operations always remain unblocked.

In addition to the above, unpausing resets the `singleSidedTimelock` to the maximum duration from the current timestamp.

$$
singleSidedTimelockDeadline = (block.timestamp + maxTimelockDuration).
$$


## Structure

All ButtonswapPairs have an internal `isPaused` state. When paused, all operations are disabled, other than burning. This state can only be modified by the ButtonswapFactory.

The ButtonswapFactory keeps an internal `isPausedSetter` address. Only the `isPausedSetter` address is capable of calling the two methods related pausing:
- `setIsPaused()`: Will update the pause state on a list of ButtonswapPairs.
- `setIsPausedSetter()`: Will update `isPausedSetter`.

## Risks

There are a number of risks associated with pausing/unpausing a pair.

### Pausing
- If the pause is front-ran, the pool price and the movingAveragePrice can be skewed
  - If the time between pausing and unpausing exceeds the pair's `movingAverageWindow`, this will effectively set the `movingAveragePrice` to pool price after the last recorded swap.
  - **Note:** This comes with significant risk any potential attack would require they also be the first swap after unpausing
- Rebases will still occur while the pair is paused. This can potentially create larger reservoirs than under normal conditions


### Unpausing
- The market price can deviate from the current price in the pool while the pool is paused. This can create immediate arbitrage opportunity when the pair is unpaused.
- If the time between pausing and unpausing exceeds the pair's `swappableReservoirGrowthWindow`, then the `swappableReservoirLimit` will be set to its maximum.

## Procedures

### Pausing
Pausing can be done without additional preconditions to ensure timely execution.

### Unpausing
Unpausing should be done with mitigating strategies in the same transaction to protect against front/back-run exposure. Unpausing is ideally performed inside a private mempool. The following should all be performed in the same transaction.

#### If market price is close to the pool price:
1. Unpause the pair.

There are no other steps necessary since there won't be any significant arbitrage opportunities. Additionally, since the single-sided timelock is activated for the maximum duration, the reservoirs are not exposed to any risk while a new `movingAveragePrice` is discovered.

#### If market price is greatly deviated (updating the pair to market price):
1. Unpause the pair.
2. Use a flash loan to borrow the asset that has a shortage in the pair (call it TokenA).
3. Arbitrage enough TokenA into the pair such that the resulting pool-price matches the market-price.
4. Take the resulting TokenB from the previous swap and use an external market to convert enough of it back to TokenA in order to pay back the flash loan. Set this amount aside until step 7.
5. Take the remaining TokenB and if necessary, use an external market to convert it into a the asset opposite the reservoir. Then, using the pool price to calculate how much is needed to match the reservoir, transfer it to the pair.
6. Anything left over in step 6 is kept by `msg.sender` to repay gas-fees.
7. Repay the flash loan.

As explained in the above section, the unpausing triggers the single-sided timelock to protect the reservoirs from any exposure for a duration of `maxTimelockDuration`.

The third step has the benefit of updating the pool price to the market price.

As a result of the arbitrage in the third step, there will be enough tokenB in order to pay back the flash-loan in tokenA (fourth step).

The fifth step uses the arbitrage profits to help drain the reservoir in a manner that donates the added liquidity to existing LPs.

In the sixth step, if there is anything left over, this kept to repay gas-fees.