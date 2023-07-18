# Timelock Math

## Variables:
- `uint16 maxVolatilityBps`: Maximum amount that the current pool price can deviate from `movingAveragePrice0`, denoted in basis points
- `uint32 minTimelockDuration`: The minimum timelock duration after a swap
- `uint32 maxTimelockDuration`: The maximum timelock duration after a swap
- `uint120 singleSidedTimelockDeadline`: The current point in time at which the timelock deactivates

## Behavior

On every swap, a price delta is calculated from the current movingAveragePrice0. The price delta relative to movingAveragePrice is then used to scale how much to add to the timelock, denoted as $\Delta T$ below.

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