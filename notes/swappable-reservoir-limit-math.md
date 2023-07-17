# Swappable Reservoir Limit Math

## Variables
- `uint16 public maxSwappableReservoirLimitBps`: The bps of the corresponding pool balance which can be exchanged from the reservoir in a given timeframe
- `uint120 public swappableReservoirLimitReachesMaxDeadline`: The current deadline by which the max relative amount of reservoir tokens can be exchanged
- `uint32 public swappableReservoirGrowthWindow`: How much time it takes for the swappable reservoir value to grow from nothing to its maximum value.

## Behavior

Before the reservoir is exchanged, we check if `block.timestamp` has passed the `swappableReservoirLimitReachesMaxDeadline`. If so, then maxSwappableReservoirLimit is allowed to be exchanged:

$$
maxSwappableReservoirLimit = poolA \cdot \frac{maxSwappableReservoirLimitBps}{10000}
$$

Otherwise, we calculate how much progress is made towards reaching it:

$$
progress = swappableReservoirGrowthWindow -
\\
(swappableReservoirLimitReachesMaxDeadline - block.timestamp)
$$

Then, we scale `maxSwappableReservoirLimit` by the progress relative to the entire `swappableReservoirGrowthWindow`:

$$
swappableReservoir = maxSwappableReservoirLimit \cdot \frac{progress}{swappableReservoirGrowthWindow}
$$