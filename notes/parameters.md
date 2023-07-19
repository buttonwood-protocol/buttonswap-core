# Parameters

The protocol has several parameters defined which control how the reservoir safeguard mechanisms behave.

## Bounds

The parameters all fall into two broad categories:

### Durations

The value is a time duration, eg. 24 hours.
For these values a range of [0, 3 months] was chosen for the following reasons:
- a minimum of 0 allows for single sided operations to be neatly disabled independent of overall pause functionality
- a maximum of 3 months is beyond our expectations for what could be justifiably chosen, but there's a small chance that a use case for a long duration being desired
- anything beyond 3 months seems wildly excessive, however

### BPS

The value is the numerator for a fraction, denominated in basis points (one hundredth of a percent).
For these values a range of [0, 10000] was chosen for the following reasons:
- a minimum of 0 allows for single sided operations to be neatly disabled independent of overall pause functionality
- a maximum of 10,000 represents 100% and is beyond our expectations for what could be justifiably chosen, but once again there's a chance of an edge case where it's useful
- anything beyond 100% is wholly unreasonable however

### Note

There are some combinations of parameters that don't make sense - for example, a `minTimelockDuration` that is greater than a `maxTimelockDuration`.
There are no validation checks to ensure that a parameter's new value does not violate these relationships and subsequently result in pair operations reverting due to mathematical errors (eg. max minus min underflowing when min is greater than max).

If parameters are updated in this manner, it is fully recoverable.
Certain pair operations cease to be executable but no new invalid state can be persisted and all it takes is for a new valid combination of parameters to be set for the pair to resume full functionality.
Crucially, the `burn` operation remains available as it has zero dependence on the parameters.
This means a poorly configured pair has no more restrictions than a pair that has been paused, and thus these are no surprising ways for the param setter to adversely affect liquidity providers through malicious parameter updates.

The following is a list of values or value combinations that result in impaired functionality:
- `maxVolatilityBps = 0`: swap operation reverts
- `minTimelockDuration > maxTimelockDuration`: swap operation reverts
- `minTimelockDuration = maxTimelockDuration = 0`: no operations revert, timelock is disabled
- `maxSwappableReservoirLimitBps = 0`: mintWithReservoir and burnWithReservoir operations revert, as `swappableReservoirLimit` is always zero

## Implementation details

This section outlines how derived variables should be adjusted when the configuration parameters are updated.

### `movingAverageWindow`

In addition to abiding by the generic duration bounds, `movingAverageWindow` also has a minimum value of `1 second`.
This is because if `movingAverageWindow = 0` then no operations revert, but `movingAveragePrice0` is always equal to `currentPrice0`.
This exposes reservoir funds to a pair price manipulation exploit, where an attacker can in one transaction greatly devalue the reservoir tokens through a large swap and then use a single sided operation to buy those reservoir tokens at greatly reduced cost before finally restoring the pair price with a final swap.

A value of `1 second` is chosen because it ensures that no matter the block speed, the `movingAveragePrice0` will never equal `currentPrice0` in the same block that `currentPrice0` changed.
Through this it ensures that any potential exploit of this nature requires an attacker to expose themselves to having disrupted the pool with significant personal value for at least one block.

With MEV, an attacker can potentially be in control of two consecutive blocks on Ethereum mainnet (albeit at increased bid price and low frequency of opportunity).
This is mitigated by choosing a suitable `minTimelockDuration` value however, rather than being dependent on `movingAverageWindow`.

The following variables are immediately impacted by changes to this parameter:
- `movingAveragePrice0`

The following variables are eventually impacted by changes to this parameter:
- `movingAveragePrice0Last`
- `singleSidedTimelockDeadline`

When `movingAverageWindow` is updated, `movingAveragePrice0Last` should not be updated.
This is because the value represents the state of `movingAveragePrice0` at a previous point in time.

When `movingAverageWindow` is updated, `singleSidedTimelockDeadline` should not be updated.
This is because the value likewise is derived from the state of `movingAveragePrice0` at a previous point in time.
In addition to that, updating it in response to updating `movingAverageWindow` would interfere with the preferred beahviour of having it respond to changes to `minTimelockDuration` and `maxTimelockDuration`, as described below.

### `maxVolatilityBps`

The following variables are eventually impacted by changes to this parameter:
- `singleSidedTimelockDeadline`

When `maxVolatilityBps` is updated, `singleSidedTimelockDeadline` should not be updated.
This is because the value likewise is derived from the state of `movingAveragePrice0` at a previous point in time.
In addition to that, updating it in response to updating `maxVolatilityBps` would interfere with the preferred beahviour of having it respond to changes to `minTimelockDuration` and `maxTimelockDuration`, as described below.

### `minTimelockDuration`

The following variables are eventually impacted by changes to this parameter:
- `singleSidedTimelockDeadline`

When `minTimelockDuration` is updated, `singleSidedTimelockDeadline` should be updated too per the following:

$$
newSingleSidedTimelockDeadline = \max(singleSidedTimelockDeadline, currentTime + minTimelockDuration)
$$

If there is an existing timelock deadline that takes less than the new `minTimelockDuration` duration to reach, then it should be extended to be no less than the new `minTimelockDuration` duration away from present time.

See the next section for more extensive reasoning about how this pair of parameters behave.

### `maxTimelockDuration`

The following variables are eventually impacted by changes to this parameter:
- `singleSidedTimelockDeadline`

When `maxTimelockDuration` is updated, `singleSidedTimelockDeadline` should be updated too per the following:

$$
newSingleSidedTimelockDeadline = \min(singleSidedTimelockDeadline, currentTime + maxTimelockDuration)
$$

If there is an existing timelock deadline that takes longer than the new `maxTimelockDuration` duration to reach, then it should be truncated to be no later than the new `maxTimelockDuration` duration away from present time.
This is so that when reducing the duration users do not have to wait out for a timelock initiated by the previous set of rules to elapse before being able to interact in accordance with the new rules.

If however the existing timelock deadline falls within that new $max - min$ window, it is not updated.
Whilst there are some nice properties of adjusting the `singleSidedTimelockDeadline` such that its progress before remains its progress after (eg. path independence) it is ultimately most flexible not to.
This allows the param setter to pick any new value for the `singleSidedTimelockDeadline` by adjusting min and max timelock durations, before setting them to their final value with the new deadline somewhere in the middle (indeed, this can be used to retain progress value across updates too).

### `maxSwappableReservoirLimitBps`

The following variables are immediately impacted by changes to this parameter:
- `swappableReservoirLimit`

The following variables are eventually impacted by changes to this parameter:
- `swappableReservoirLimitReachesMaxDeadline`

When `maxSwappableReservoirLimitBps` is updated, `swappableReservoirLimitReachesMaxDeadline` should not be updated.
This is because if the param setter is changing this parameter they desire a corresponding immediate increase or decrease in the `swappableReservoirLimit` value.
It does not make sense to try to adjust `swappableReservoirLimitReachesMaxDeadline` such that the current `swappableReservoirLimit` value remains unchanged across this parameter update.

### `swappableReservoirGrowthWindow`

In addition to abiding by the generic duration bounds, `swappableReservoirGrowthWindow` also has a minimum value of `1 second`.
This is because if `swappableReservoirGrowthWindow = 0` then when the function for updating the parameter is ran subsequently, there is a div-by-zero error and it reverts (effectively locking `swappableReservoirGrowthWindow` forever at zero).
Refer to the math below for more detail, the issue occurs when $W_{0} = 0$.

The following variables are immediately impacted by changes to this parameter:
- `swappableReservoirLimit`

The following variables are eventually impacted by changes to this parameter:
- `swappableReservoirLimitReachesMaxDeadline`

When `swappableReservoirGrowthWindow` is updated, `swappableReservoirLimitReachesMaxDeadline` should be updated too per the following:

Let $P_{0}$ and $P_{1}$ be the old and new progress value respectively.
Let $W_{0}$ and $W_{1}$ be the old and new `swappableReservoirGrowthWindow` value respectively.
Let $D_{0}$ and $D_{1}$ be the old and new `swappableReservoirLimitReachesMaxDeadline` value respectively.
Let $t$ be the current time.

$$
P_{0} = {W_{0} - (D_{0} - t) \over W_{0}}
$$

and likewise

$$
P_{1} = {W_{1} - (D_{1} - t) \over W_{1}}
$$

We desire the progess to remain unchanged, such that

$$
P_{1} = P_{0}
$$

Thus:

$$
{W_{1} - (D_{1} - t) \over W_{1}} = {W_{0} - (D_{0} - t) \over W_{0}}
$$

Rearranging to solve for $D_{1}$:

$$
{W_{1} - D_{1} + t \over W_{1}} = {W_{0} - D_{0} + t \over W_{0}}
$$

$$
1 - {D_{1} \over W_{1}} + {t \over W_{1}} = 1 - {D_{0} \over W_{0}} + {t \over W_{0}}
$$

$$
{D_{1} \over W_{1}} - {t \over W_{1}} = {D_{0} \over W_{0}} - {t \over W_{0}}
$$

$$
D_{1} = W_{1} \cdot ({D_{0} - t \over W_{0}} + {t \over W_{1}})
$$

$$
D_{1} = W_{1} \cdot {D_{0} - t \over W_{0}} + t
$$

This is primarily to avoid a scenario where the following code underflows if `swappableReservoirGrowthWindow` has been decreased too much:
```solidity
// from _getSwappableReservoirLimit function:
uint256 progress = swappableReservoirGrowthWindow - (swappableReservoirLimitReachesMaxDeadline - block.timestamp);
```

It has the additional benefit of being the most intuitive outcome.
If the growth window is changed, there isn't an expectation that the current `swappableReservoirLimit` changes too.
Rather, the only expectation is that the rate at which it grows has changed.
