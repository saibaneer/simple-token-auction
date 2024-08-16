## TokenAuctionWithArray - Project ReadMe

### Overview

**TokenAuctionWithArray** is a smart contract that facilitates token auctions using an array to store and sort bids. Participants place bids for a specified number of tokens, and bids are ordered by price per token in descending order. The contract supports bid placement, token claiming for winning bids, and ETH refunds for unfilled bids after the auction ends.

### Key Features
- **ERC20 Token Auction**: Allows users to place bids for ERC20 tokens, with each bid being ordered by price.
- **Bid Management**: The contract stores bid details, including the price per unit, quantity of tokens requested, and quantities filled.
- **Auction Control**: The owner can start and end the auction, and users can claim tokens or request refunds after the auction ends.
- **Refunds**: Users receive ETH refunds for any unfilled portion of their bid.
- **Safety and Security**: The contract uses OpenZeppelin's `ReentrancyGuard` to protect against reentrancy attacks and `SafeERC20` for safe token transfers.

### Prerequisites

- Solidity `0.8.24`
- OpenZeppelin Contracts: `@openzeppelin/contracts`
- Node.js with Hardhat for development and testing.

### Contract Details

#### State Variables:
- **token**: The ERC20 token being auctioned.
- **orderedBids**: An array that holds bids in descending order by price per unit.
- **bidDetails**: A mapping of bid prices to `Bid` struct details.
- **bidHashToBidValue**: A mapping from bid hashes to bid prices.
- **auctionEndTime, auctionStartTime**: The start and end time of the auction.
- **auctionStartPrice**: The minimum price per token at which bidding starts.
- **tokensSold**: Total tokens sold during the auction.
- **tokenSupply**: The total number of tokens available for auction.
- **auctionEnded**: A boolean indicating whether the auction has ended.
- **owner**: The owner of the auction contract.
- **bidderCount**: The count of total unique bidders.

#### Structs:
- **Bid**: Stores details of each bid, including the bidder's address, bid price, quantity requested, quantity filled, refund value, and fill status.

### Functions

#### Public/External Functions

1. **`startAuction`**: Initializes the auction with the token address, token quantity, start and end times, and starting price.
    - **Parameters**:
        - `_tokenAddress`: Address of the ERC20 token.
        - `_tokenQty`: Total number of tokens for auction.
        - `_auctionStartTime`: Timestamp when the auction starts.
        - `_auctionEndTime`: Timestamp when the auction ends.
        - `_auctionStartPrice`: Minimum price per token.
    - **Access**: Only callable by the contract owner.

2. **`placeBid`**: Allows a user to place a bid for a specific number of tokens at a price per token.
    - **Parameters**:
        - `_quantity`: The quantity of tokens the user wants to purchase.
        - `_bidPricePerUnit`: The price per token the user is willing to pay.
    - **Requirements**:
        - Must be called during the auction's active period.
        - The bid price must be higher than the previous bids to maintain order.
        - Limited to 50 bids.

3. **`endAuction`**: Ends the auction and processes winning bids. Can only be called by the owner after the auction end time.
    - **Requirements**: Auction must be active and the current time must be past the auction's end time.

4. **`claimTokens`**: Allows a winning bidder to claim their tokens after the auction ends.
    - **Parameters**:
        - `_bidHash`: A unique hash representing the bid.
    - **Requirements**: The bid must be processed, and tokens must be available to claim.

5. **`refundETH`**: Allows a bidder to claim a refund for any unfilled portion of their bid.
    - **Parameters**:
        - `_bidHash`: A unique hash representing the bid.
    - **Requirements**: The bid must have an unfilled portion and a corresponding refund value.

6. **`checkAuctionEnd`**: A function that anyone can call to check if the auction should end based on current time or if all tokens have been sold.

### Internal Functions

1. **`_createBid`**: Internal function that creates a new bid and stores it in the contract's mappings.
    - **Parameters**:
        - `_quantity`: The number of tokens requested in the bid.
        - `_bidPricePerUnit`: The price per token.
    - **Returns**: A unique `bidHash` that identifies the bid.

2. **`_fillWinningBids`**: Processes the bids, filling as many as possible based on available tokens. It allocates tokens to bidders and calculates any refund values for unfilled bids.

3. **`_endAuction`**: Internal function that marks the auction as ended and processes the winning bids.

### Events

- **`BidPlaced`**: Emitted when a user places a bid.
- **`AuctionEnded`**: Emitted when the auction ends.
- **`TokensClaimed`**: Emitted when a bidder successfully claims tokens.
- **`RefundIssued`**: Emitted when a refund is issued to a bidder.

### Errors

- **`NOT_THE_OWNER`**: Thrown when a non-owner tries to perform an owner-only action.
- **`AUCTION_NOT_ACTIVE`**: Thrown when trying to place a bid outside of the auction's active period.
- **`AUCTION_ALREADY_ENDED`**: Thrown when trying to interact with the auction after it has ended.
- **`AUCTION_UNFUNDED`**: Thrown if the auction has not been funded with the required number of tokens.
- **`BID_PRICE_TOO_LOW`**: Thrown when a bid's price per token is below the auction's starting price.
- **`INSUFFICIENT_PAYMENT`**: Thrown when a bidder sends insufficient ETH for their bid.
- **`NO_TOKENS_TO_CLAIM`**: Thrown when a bidder attempts to claim tokens with no filled quantity.
- **`NO_REFUND_AVAILABLE`**: Thrown when a bidder attempts to claim a refund with no unfilled portion.

### Installation & Deployment

1. Install dependencies:
   ```bash
   npm install
   ```

2. Compile the contract:
   ```bash
   npx hardhat compile
   ```

3. Deploy the contract:
   ```bash
   npx hardhat run scripts/deploy.js --network <network_name>
   ```

### Testing

1. Write tests in the `test` folder using Hardhat.
2. Run the tests:
   ```bash
   npx hardhat test
   ```

### License

This contract is released under the **Unlicensed** license.

### Author

Developed by **[Gbenga AJiboye]**, [2024].

---

This `TokenAuctionWithArray` contract is designed to be a simple yet effective token auction mechanism. Feel free to extend and modify it for your specific needs.