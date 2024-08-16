// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./Errors.sol";

/// @title TokenAuctionWithArray
/// @notice A contract for conducting token auctions using an array for bid ordering
/// @dev This contract manages a token auction with bid placement, token claiming, and ETH refunds
contract TokenAuctionWithArray is ReentrancyGuard {
    uint256[] public orderedBids;
    using SafeERC20 for IERC20;

    // Structs
    struct Bid {
        address bidder;
        uint256 bidPricePerUnit;
        uint256 bidQty;
        uint256 qtyFilled;
        uint256 refundValue;
        bool isFilled;
    }

    // State variables
    IERC20 public token;
    mapping(uint256 => Bid) public bidDetails;
    mapping(bytes32 => uint256) public bidHashToBidValue;

    uint256 public auctionEndTime;
    uint256 public auctionStartTime;
    uint256 public auctionStartPrice;
    uint256 public tokensSold;
    uint256 public tokenSupply;
    bool public auctionEnded;
    address public immutable owner;
    uint64 public bidderCount;

    // Events
    event BidPlaced(
        bytes32 indexed bidHash,
        address indexed bidder,
        uint256 quantity,
        uint256 pricePerUnit
    );
    event AuctionEnded();
    event TokensClaimed(address indexed bidder, uint256 amount);
    event RefundIssued(address indexed bidder, uint256 refundValue);

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, Errors.NOT_THE_OWNER);
        _;
    }

    modifier auctionActive() {
        require(
            block.timestamp >= auctionStartTime &&
                block.timestamp <= auctionEndTime,
            Errors.AUCTION_NOT_ACTIVE
        );
        require(!auctionEnded, Errors.AUCTION_ALREADY_ENDED);
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /// @notice Initializes the auction with given parameters
    /// @param _tokenAddress Address of the ERC20 token being auctioned
    /// @param _tokenQty Total number of tokens available for auction
    /// @param _auctionStartTime Unix timestamp when the auction starts
    /// @param _auctionEndTime Unix timestamp when the auction ends
    /// @param _auctionStartPrice Minimum price per token to start the auction
    function startAuction(
        address _tokenAddress,
        uint256 _tokenQty,
        uint256 _auctionStartTime,
        uint256 _auctionEndTime,
        uint256 _auctionStartPrice
    ) external onlyOwner {
        require(_tokenAddress != address(0), Errors.BAD_ADDRESS);
        require(
            _auctionStartTime > block.timestamp,
            Errors.AUCTION_START_MUST_BE_AHEAD
        );
        require(
            _auctionEndTime > _auctionStartTime,
            Errors.AUCTION_END_MUST_EXCEED_AUCTION_START_TIME
        );
        token = IERC20(_tokenAddress);
        require(
            token.balanceOf(msg.sender) >= _tokenQty,
            Errors.INSUFFICIENT_TOKENS
        );
        tokenSupply = _tokenQty;
        auctionStartTime = _auctionStartTime;
        auctionEndTime = _auctionEndTime;
        auctionStartPrice = _auctionStartPrice;

        token.safeTransferFrom(msg.sender, address(this), _tokenQty);
    }

    /// @notice Allows a user to place a bid in the auction
    /// @param _quantity Number of tokens the user wants to buy
    /// @param _bidPricePerUnit Price per token the user is willing to pay
    /// @dev Requires the auction to be active and the bid to be higher than previous bids
    function placeBid(
        uint256 _quantity,
        uint256 _bidPricePerUnit
    ) external payable auctionActive nonReentrant {
        uint256 totalBidValue = _quantity * _bidPricePerUnit;

        require(msg.value >= totalBidValue, Errors.INSUFFICIENT_PAYMENT);
        require(
            _bidPricePerUnit >= auctionStartPrice,
            Errors.BID_PRICE_TOO_LOW
        );
        require(
            token.balanceOf(address(this)) >= tokenSupply,
            Errors.AUCTION_UNFUNDED
        );

        if (bidderCount != 0) {
            require(
                _bidPricePerUnit > orderedBids[orderedBids.length - 1], //to ensure that only a bid higher 
                //than the last is added, effectively sorting the array in descending order
                Errors.BID_PRICE_TOO_LOW
            );
        }
        require(bidderCount <= 50, Errors.MAX_BID_COUNT_REACHED);

        bytes32 bidHash = _createBid(_quantity, _bidPricePerUnit);

        orderedBids.push(_bidPricePerUnit);
        bidderCount++;

        emit BidPlaced(bidHash, msg.sender, _quantity, _bidPricePerUnit);
    }

    /// @notice Ends the auction and processes winning bids
    /// @dev Can only be called by the owner after the auction end time
    function endAuction() external onlyOwner {
        require(
            block.timestamp >= auctionEndTime,
            Errors.AUCTION_STILL_ONGOING
        );
        require(!auctionEnded, Errors.AUCTION_ALREADY_ENDED);

        auctionEnded = true;
        _fillWinningBids();

        emit AuctionEnded();
    }

    /// @notice Allows a winning bidder to claim their tokens
    /// @param _bidHash The unique hash of the bid
    /// @dev Transfers the won tokens to the bidder
    function claimTokens(bytes32 _bidHash) external nonReentrant {
        uint256 bidValue = bidHashToBidValue[_bidHash];
        Bid storage bid = bidDetails[bidValue];

        require(bid.bidder == msg.sender, Errors.NOT_THE_BIDDER);
        require(bid.qtyFilled > 0, Errors.NO_TOKENS_TO_CLAIM);
        require(bid.isFilled, Errors.BID_NOT_PROCESSED);

        uint256 amountFilled = bid.qtyFilled;
        bid.qtyFilled = 0;

        token.safeTransfer(msg.sender, amountFilled);
        emit TokensClaimed(msg.sender, amountFilled);
    }

    /// @notice Allows a bidder to claim their ETH refund for unfilled bids
    /// @param _bidHash The unique hash of the bid
    /// @dev Transfers the refund amount in ETH to the bidder
    function refundETH(bytes32 _bidHash) external nonReentrant {
        uint256 bidValue = bidHashToBidValue[_bidHash];
        Bid storage bid = bidDetails[bidValue];

        require(bid.bidder == msg.sender, Errors.NOT_THE_BIDDER);
        require(bid.refundValue > 0, Errors.NO_REFUND_AVAILABLE);

        uint256 refundAmount = bid.refundValue;
        bid.refundValue = 0;

        (bool success, ) = msg.sender.call{value: refundAmount}("");
        require(success, Errors.ETH_REFUND_FAILED);

        emit RefundIssued(msg.sender, refundAmount);
    }

    /// @notice Checks if the auction should end and ends it if conditions are met
    /// @dev Can be called by anyone to trigger the end of the auction
    function checkAuctionEnd() external {
        if (block.timestamp >= auctionEndTime || tokensSold >= tokenSupply) {
            _endAuction();
        }
    }

    /// @notice Creates a new bid and stores it in the contract
    /// @param _quantity Number of tokens in the bid
    /// @param _bidPricePerUnit Price per token in the bid
    /// @return bidHash The unique hash of the created bid
    function _createBid(
        uint256 _quantity,
        uint256 _bidPricePerUnit
    ) internal returns (bytes32) {
        bidDetails[_bidPricePerUnit] = Bid({
            bidder: msg.sender,
            bidPricePerUnit: _bidPricePerUnit,
            bidQty: _quantity,
            qtyFilled: 0,
            refundValue: 0,
            isFilled: false
        });

        bytes32 bidHash = keccak256(
            abi.encodePacked(msg.sender, _bidPricePerUnit, _quantity)
        );
        bidHashToBidValue[bidHash] = _bidPricePerUnit;

        return bidHash;
    }

    /// @notice Processes winning bids and allocates tokens
    /// @dev Called internally when ending the auction
    function _fillWinningBids() internal {
        uint256 remainingTokens = tokenSupply - tokensSold;

        while (remainingTokens > 0 && orderedBids.length > 0) {
            uint256 highestBidPerValue = orderedBids[orderedBids.length - 1];
            orderedBids.pop();
            Bid storage bid = bidDetails[highestBidPerValue];

            uint256 tokensToFill = bid.bidQty < remainingTokens
                ? bid.bidQty
                : remainingTokens;
            bid.qtyFilled = tokensToFill;
            tokensSold += tokensToFill;
            remainingTokens -= tokensToFill;

            if (bid.bidQty > tokensToFill) {
                bid.refundValue =
                    (bid.bidQty - tokensToFill) *
                    bid.bidPricePerUnit;
            }

            bid.isFilled = true;
        }
    }

    /// @notice Internal function to end the auction
    /// @dev Sets the auction as ended and processes winning bids
    function _endAuction() internal {
        if (!auctionEnded) {
            auctionEnded = true;
            _fillWinningBids();
            emit AuctionEnded();
        }
    }
}
