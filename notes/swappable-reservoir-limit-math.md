# Swappable Reservoir Limit Math

## Variables
- `uint16 maxSwappableReservoirLimitBps`: The corresponding pool balance which can be exchanged from the reservoir in a given timeframe, denoted in basis points
- `uint120 swappableReservoirLimitReachesMaxDeadline`: The point in time at which the max relative amount of reservoir tokens can be exchanged, denoted as a unix timestamp
- `uint32 swappableReservoirGrowthWindow`: How much time it takes for the swappable reservoir value to grow from 0 to its maximum value, denoted in seconds

## Behavior
First we calculate the maximum swappable reservoir amount ever allowed to be exchanged, `maxSwappableReservoirLimit`:

$$
M = poolA \cdot \frac{maxSwappableReservoirLimitBps}{10000}
$$

Then we scale $M$ by how close the current `block.timestamp` is to the `swappableReservoirLimitReachesMaxDeadline`. We denote the `swappableReservoirGrowthWindow` by $W$.

$$
t_{diff} = swappableReservoirLimitReachesMaxDeadline - block.timestamp
$$

$$
swappableReservoir = \begin{cases} M & t_{diff} \le 0 \\ M \cdot \frac{W - t_{diff}}{W} & \text{otherwise} \end{cases}
$$