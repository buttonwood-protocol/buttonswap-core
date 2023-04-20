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

Our approach is to use an EWMA (exponential weighted moving average) through exponential smoothing(https://en.wikipedia.org/wiki/Exponential_smoothing), where each new observation has a smoothing factor($\alpha$) by it's relative proportion of time in the last 24 hours.

```math
S_{0} = P_{0}
```
```math
\alpha_{j} = \frac{T_{j}}{24hrs}
```
```math
S_{j} =  \begin{cases} \alpha_{j} \cdot P_{j-1} + (1 - \alpha_{j}) \cdot S_{j-1} & T_{j} < 24hrs \\ P_{j-1} & \text{otherwise} \end{cases}
```

where:
- $S_{j}$ is the EWMA at time of measurement $j$
- $a_{j}$ is the smoothing factor at time of measurement $j$

TODO: FILL IN IMPLEMENTATION DETAILS (i.e, only need to store 3 values and rest is accessible from block, also how price is stored)

## Risk Mitigation

### Time-Lock
TODO: Fill in how the time lock works (For Socks)

### Smoothed Reservoir Pricing
TODO: Why we use TWAP price and not the reservoir price (for Fids)

### Chunking
TODO: What chunking is and what it accomplishes