# Time Lock Math

## Variables:
- `uint16 public maxVolatilityBps`: Maximum BPS that the current pool price can deviate from `movingAveragePrice0`
- `uint32 public minTimelockDuration`: The minimum timelock duration for any swap
- `uint32 public maxTimelockDuration`: The maximum timelock duration for any swap
- `uint120 public singleSidedTimelockDeadline`: The current timelock deadline timestamp

## Behavior

On every swap, a price delta is calculated from the current movingAveragePrice0. The price delta relative to movingAveragePrice is then used to scale how much to add to the timelock.

$$
\Delta Price = |newPrice - movingAveragePrice|
$$
$$
TimelockRange = (maxTimeLockDuration - minTimeLockDuration)
$$
$$
\Delta T = \frac{\Delta Price}{movingAveragePrice \cdot maxVolatilityPercent} \cdot TimelockRange
$$

If $block.timestamp + \Delta T$ exceeds the current timelockDeadline, it replaces it. Otherwise, the same previous deadline holds.