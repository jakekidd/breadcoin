# BreadCoin

After extensive research and questionable decision-making, BreadCoin v1.0 is a bread-based currency. It cannot be exchanged for real bread, but maybe
in the future it can, somewhere, somehow. We'll see. But it will cost extra, with inflation. DM me for delivery

## Key Features

- ERC-20 compliant (0 decimals - whole loaves only)
- Initial supply: 123,000 BREAD (blessed number)
- Max supply: 1,000,000 BREAD (sanity cap, we don't have unlimited bread)
- Dynamic pricing: starts at 0.00001 ETH, +1 wei per block #inflation

## Core Mechanics

The BreadCoin contract is designed to be straightforward. It has features that control supply, pricing, and user interaction.

### Pricing Model

The price of BreadCoin increases over time linearly, #inflation

- **Floor Price**: 0.00001 ETH (10,000,000,000,000 wei) - because even bread has standards. This is the penthouse floor of bread pricing.
- **Linear Inflation**: Starting from the floor price, the cost increases by 1 wei with every new block mined after the contract's deployment. The price can be checked at any time using the `price()` view function.
- ~~**Bulk Discount**: A 10% discount is automatically applied to the total cost when purchasing 100 or more loaves in a single transaction.~~
- **Cost Calculation**: The `quote(numLoaves)` function allows users to get an exact cost for a specific number of loaves. We removed the bulk discount after it caused a ruckus

### Acquiring BreadCoin (Baking)

Users can acquire BreadCoin by "baking" it, which is the contract's term for minting.

- **`bake(numLoaves)`**: This function allows a user to mint an exact number of tokens. The user must send enough ETH to cover the cost, which is calculated based on the current price and quantity. Any excess ETH sent is automatically refunded.
- **`bakeMax()`**: For convenience, a user can call this function and send an arbitrary amount of ETH. The contract will calculate the maximum number of loaves they can afford, mint them, and refund any remaining dust. I don't recommend you do this.

**Important**: The bakery is closed on Sundays. Even bread needs to rest. Minting functions will revert on Sundays with a helpful message to come back Monday for fresh loaves.

### Key Functions

- **`toast(amount)`**: A deflationary mechanism that allows users to permanently burn their BreadCoin tokens, reducing the total supply.
- **`knead()`**: A non-financial function that allows users to interact with the contract. It tracks the number of times a user has kneaded, storing the count in the `_crumbs` mapping. This is for \[TBD NFT\]
- **`makeDough()`**: This is so I can actually make money. I mean bread

### Contract Details

- **Token Standard**: ERC20
- **Decimals**: 0 (Tokens are not divisible)
- **Max Supply**: 1,000,000 BREAD
- **Security**: OK

## Testing

1.  Install Foundry if you really knead to test: `curl -L https://foundry.paradigm.xyz | bash`
2.  Install dependencies: `forge install`
3.  `forge b` or `forge test`
