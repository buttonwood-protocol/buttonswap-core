# Swap Math

The pool has two tokens, `A` and `B`.

The pool's token balances changes during a swap.

Let `A_s` and `B_s` represent the start balances for how many tokens the pool has.
Let `A_e` and `B_e` represent the end balances for how many tokens the pool has.

## K invariant

`K` refers to the product of the pool token balances.

The rule by which this AMM operates is that `K` does not change during a swap.

Thus:
- `K_s = A_s * B_s`
- `K_e = A_e * B_e`
- `K_s = K_e`
- `A_s * B_s = A_e * B_e`

## Swap Calculations

Let us trade `x` amount of `A` for `B`.

We expect back amount `y` of token `B`. 

Thus:
- `A_e = A_s + x`
- `B_e = B_s - y`

Substituting with our equations from before, we have:
- `A_s * B_s = A_e * B_e`
- `A_s * B_s = (A_s + x) * (B_s - y)`

We wish to determine `y`, so:
- `A_s * B_s = (A_s + x) * (B_s - y)`
- `(A_s * B_s)/(A_s + x) = (B_s - y)`
- `y = B_s - (A_s * B_s)/(A_s + x)`
- `y = (B_s*(A_s + x))/(A_s + x) - (A_s * B_s)/(A_s + x)`
- `y = ((B_s*(A_s + x)) - (A_s * B_s))/(A_s + x)`
- `y = (B_s*A_s + B_s*x - A_s*B_s)/(A_s + x)`
- `y = (B_s * x)/(A_s + x)`

This works both ways, so more generally, if rather than `A` and `B` we have `I` and `O` to represent the Input token and the Output token, we have:

`y = (O_s * x)/(I_s + x)`

## Fee mechanism

The expression above describes the expected output amount for a swap with no fee.

In practise, the pool actually operates with a 0.3% fee, which is deducted from the output amount the swapper receives.

This is done by calculating the output amount received if the input amount were to have the fee deducted.

Let `f` be the fee of 0.3%.
The contracts rely on integer math, so we represent `f` as a fraction `f = f_n/f_d` where `f_n = 3` and `f_d = 1000`.

Let `F` be the input amount scalar, where `F = 1 - f`. Thus we have `F = F_n/F_d` where `F_n = f_d - f_n` and `F_d = f_d`.

Apply this to the output amount expression from above and we have:
- `y = (O_s * (x*F))/(I_s + (x*F))`
- `y = (O_s * (x*(F_n/F_d)))/(I_s + (x*(F_n/F_d)))`
- `y = (O_s * (x*(F_n)))/((I_s*F_d) + (x*(F_n)))`
- `y = (O_s * (x*F_n))/((I_s*F_d) + (x*F_n))`

With values for a 0.3% fee substituted:
- `y = (O_s * x  * 997)/((I_s * 1000) + (x * 997))`
