# Reservoir Valuation

Interactions with the reservoir require implicit pricing of the assets in the reservoir. Utilizing the current pool balances has an underlying risk of a price-manipulation exploit. A malicious actor could temporarily flood the pair with the same asset as the reservoir in order to withdraw the reservoir itself at a discounted price, before returning balances to normal as before.

We outline the strategies used to prevent and mitigate this risk.


## Price Stability
In order to calculate a "stable" price, our approach is to store a modified TWAP(Time Weighted Average Price). TWAP's typically use a weighted moving average approach where each observation is weighted by the amount of time since the last observation (https://en.wikipedia.org/wiki/Time-weighted_average_price):

```math
P_{TWAP} = \frac{\sum_{j} P_{j} \cdot T_{j}}{\sum_{j} T_{j}}
```

where:
- $P_{TWAP}$ is Time Weighted Average Price
- $P_{j}$ is the price of security at a time of measurement $j$
- $T_{j}$ is change of time since previous price measurement $j$
- $j$ is each individual measurement that takes place over the defined period of time.

The negatives to this approach are that it requires a sliding window of previous trades which is gas-intensive.

### Our Approach

Our approach is to use a similar time weighted moving average, however instead of weighing by $T_{j}$, we will weigh by scalars $W_{j}$. These are the same values except if the observation happens outside of the last 24 hours, then $W_{j}=0$ (for cases where $T_{j}$ overlaps with the cutoff, it is scaled down to fit inside the window). In essence, we will be averaging over the entire time window, but expiring observations that are over 24 hours old. Therefore for any number of $W_{j}$, their total sum will always equal 24 hours. This allows us to rewrite our modified TWAP in an approximate recursive fashion:

```math
S_{j} = \frac{\sum_{i \le j} P_{i} \cdot W_{i}}{\sum_{i \le j} W_{i}}
```
```math
S_{j} \approx \frac{P_{j} \cdot W_{j} + S_{j-1} \cdot \left((\sum_{i \le j} W_{i}) - W_{j}\right)}{\sum_{i \le j} W_{i}}
```
```math
S_{j} \approx \frac{P_{j} \cdot W_{j} + S_{j-1} \cdot \left((24 hrs) - W_{j}\right)}{24 hrs}
```
```math
S_{j} \approx \alpha_{j} \cdot P_{j} + (1 - \alpha) S_{j-1}
```

where:
- $S_{j}$ is the moving average at time of measurement $j$
- $\alpha_{j} = \frac{W_{j}}{24 hrs}$ is the relative weight of the current observation over the last 24 hours at time of measurment $j$

TODO: FILL IN IMPLEMENTATION DETAILS (i.e, only need to store 3 values and rest is accessible from block, also how price is stored)

## Risk Mitigation

### Smoothed Reservoir Pricing

The use of a TWAP to valuate the reservoir tokens when doing single-sided operations goes a lot way to protect it from exploitation, but it is not ironclad.
The biggest drawback is that it remains a lagging price indicator (due to its time-based component) and consequently provides some arbitrage opportunity between a past value and the current one if there's rapid price movement.

As such, we apply a few more mechanisms which almost entirely mitigate this.

### Time-Lock

This is a mechanism whereby the single-sided operations can effectively be disabled automatically at times - eg. if someone were to try calling them, they would revert.
This would be done in response to price volatility.
If there's been a sudden change in price recently, then users must wait before they can use that price whilst interacting with the reservoir.

This is triggered during every swap, by calculating the difference between the new price and the TWAP price.
That difference is then mapped to a time delay, and the timestamp of when this delay expires is determined.
If the new timestamp exceeds the current stored value then update it to the new one, else leave untouched.

This ensures that the TWAP is fairly stable before being used, giving users the opportunity to trade against it if it's thought to not be representative of market value.
This has the effect of reducing the impact of the TWAP lagging behind live price.

### Chunking

This is a mechanism that limits how much of the reservoir can be used in a single sided operation.
In an extreme scenario we can imagine the reservoir being larger than the active liquidity.
In this case it doesn't make sense to allow the entire reservoir to be valuated using a price derived from a small liquidity pool.

As such this works by restricting the amount used based on time since last single sided operation.
This would be done by mapping the time elapsed to a fraction of the pool balance, up to a maximum.

This also ensures that if there was still any price mismatching it would have limited impact.  
