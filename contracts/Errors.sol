// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.24;


library Errors {
    string internal constant NOT_THE_OWNER = "Not the owner";
    string internal constant AUCTION_NOT_ACTIVE = "Auction not active";
    string internal constant AUCTION_ALREADY_ENDED = "Auction already ended";
    string internal constant BAD_ADDRESS = "Bad Address";
    string internal constant AUCTION_START_MUST_BE_AHEAD = "Auction start time must be in the future";
    string internal constant AUCTION_END_MUST_EXCEED_AUCTION_START_TIME= "Auction end time must be after start time";
    string internal constant INSUFFICIENT_TOKENS = "You don't have sufficient tokens";
    string internal constant INSUFFICIENT_PAYMENT = "Insufficient ETH sent";
    string internal constant BID_PRICE_TOO_LOW = "Bid price too low";
    string internal constant AUCTION_UNFUNDED = "Auctioner is yet to fund account correctly";
    string internal constant MAX_BID_COUNT_REACHED = "Max Bid count reached";
    string internal constant AUCTION_STILL_ONGOING = "Auction still ongoing";
    string internal constant NOT_THE_BIDDER = "Not the bidder";
    string internal constant NO_TOKENS_TO_CLAIM = "No tokens to claim";
    string internal constant BID_NOT_PROCESSED = "Bid was not processed, claim refund!";
    string internal constant NO_REFUND_AVAILABLE = "No refund available";
    string internal constant ETH_REFUND_FAILED = "ETH refund failed";

}