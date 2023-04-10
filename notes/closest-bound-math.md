# Closest Bound Math

The pool has two tokens that it serves as a market for, $A$ and $B$.

Whenever there are rebases or underlying balance changes, the pair contract must keep track of the active liquidity and surplus liquidity with virtual balances in order to keep price ratio constant.

```math
\frac{A_{0}}{B_{0}} = \frac{A_{1}}{B_{1}}
``` 

If there is a change in $B$, then calculating the new $A$ is easy:

```math
A_{1} = {B_{1} \cdot \frac{A_{0}}{B_{0}}}
``` 

However, given that the pool balances are stored in integers, there will inevitably be some rounding error.
The question is thus whether to round up or down in order to minimize the error:

```math
A_{L} = \floor{A_{1}}
``` 
```math
A_{U} = \ceil{A_{1}} = A_{L} + 1
``` 

This can be determined by comparing the delta of both options with that of the original price ratios, using cross multiplication.

```math
\Delta_{L} = \left| A_{L}*B_{0} - A_{0}B_{1} \right|
```
```math
\Delta_{U} = \left| A_{U}*B_{0} - A_{0}B_{1} \right|
```

If $\Delta_{L} < \Delta_{U}$, then round down, otherwise round up.

This math can however be simplified into a single if-condition if we examine the following properties of the values inside the absolute values.
Firstly, we're going to rewrite the deltas as follows:

```math
Diff_{L} = (A_{L}*B_{0} - A_{0}B_{1})
```
```math
Diff_{U} = (A_{U}*B_{0} - A_{0}B_{1})
```
```math
\Delta_{L} = \left| Diff_{L} \right|
```
```math
\Delta_{U} = \left| Diff_{U} \right|
```

The question then becomes whether $Diff_{L}$ or $Diff_{U}$ is closer to 0. 
One key insight to notice is that $Diff_{U}$ is always strictly greater than $Diff_{L}$, since $A_{U} = A_{L} + 1$.
 
- If $Diff_{L}$ is positive, then $Diff_{U}$ must be positive and further from 0. Thus $A_{L}$ gives a smaller error.
- Likewise, if $Diff_{U}$ is negative, then $Diff_{L}$ must be negative and further from 0. Thus $A_{U}$ gives a smaller error.

It's impossible for $Diff_{L}$ to be positive and $Diff_{U}$ to be negative.
Therefore the only case that remains is when $Diff_{L}$ is negative and $Diff_{U}$ is positive.
Note that because $A_{U} = A_{L} + 1$, this means that $Diff_{U} = Diff_{L} + B_{0}$.
Thus, the bounds of $Diff_{U}$ and $Diff_{L}$ are $(-B_{0}, B_{0})$.

Note that, if $Diff_{U} < B_{0}/2$ this implies that $Diff_{L} < -B_{0}/2$. 
Thus when $Diff_{U} < B_{0}/2$, it is closer to 0 than $Diff_{L}$, and $A_{U}$ gives a smaller error.

## Final If-Condition
Thus, the final if-condition is:

>
> if ($Diff_{U} < B_{0}/2$)
>>    return $A_{U}$;
>
> else
>>    return $A_{L}$;