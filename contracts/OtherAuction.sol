// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.24;


import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title TokenAuction
/// @notice A contract for conducting token auctions
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
    IERC20 public immutable token;
    mapping(uint256 => Bid) public bidDetails;
    mapping(bytes32 => uint256) public bidHashToBidValue;

    uint256 public immutable auctionEndTime;
    uint256 public immutable auctionStartTime;
    uint256 public immutable auctionStartPrice;
    uint256 public tokensSold;
    uint256 public immutable tokenSupply;
    bool public auctionEnded;
    address public immutable owner;
    uint64 public bidderCount;

    // Events
    event BidPlaced(bytes32 indexed bidHash, address indexed bidder, uint256 quantity, uint256 pricePerUnit);
    event AuctionEnded();
    event TokensClaimed(address indexed bidder, uint256 amount);
    event RefundIssued(address indexed bidder, uint256 refundValue);

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    modifier auctionActive() {
        require(block.timestamp >= auctionStartTime && block.timestamp <= auctionEndTime, "Auction not active");
        require(!auctionEnded, "Auction already ended");
        _;
    }

    // Constructor
    constructor(
        address _tokenAddress,
        uint256 _tokenSupply,
        uint256 _auctionStartTime,
        uint256 _auctionEndTime,
        uint256 _auctionStartPrice
    ) {
        owner = msg.sender;
        token = IERC20(_tokenAddress);
        tokenSupply = _tokenSupply;
        auctionStartTime = _auctionStartTime;
        auctionEndTime = _auctionEndTime;
        auctionStartPrice = _auctionStartPrice;
    }

    // External functions
    function placeBid(uint256 _quantity, uint256 _bidPricePerUnit) external payable auctionActive nonReentrant {
        uint256 totalBidValue = _quantity * _bidPricePerUnit;
        
        require(msg.value >= totalBidValue, "Insufficient ETH sent");
        require(_bidPricePerUnit >= auctionStartPrice, "Bid price too low");
        require(token.balanceOf(address(this)) >= tokenSupply, "Auctioner is yet to fund account correctly");
        
        if(bidderCount != 0) {
            require(_bidPricePerUnit > orderedBids[orderedBids.length - 1], "Bid too low");
        }

        bytes32 bidHash = _createBid(_quantity, _bidPricePerUnit);
        
        orderedBids.push(_bidPricePerUnit);
        bidderCount++;
        
        emit BidPlaced(bidHash, msg.sender, _quantity, _bidPricePerUnit);
    }

    function endAuction() external onlyOwner {
        require(block.timestamp >= auctionEndTime, "Auction still ongoing");
        require(!auctionEnded, "Auction already ended");

        auctionEnded = true;
        _fillWinningBids();

        emit AuctionEnded();
    }

    function claimTokens(bytes32 _bidHash) external nonReentrant {
        uint256 bidValue = bidHashToBidValue[_bidHash];
        Bid storage bid = bidDetails[bidValue];

        require(bid.bidder == msg.sender, "Not the bidder");
        require(bid.qtyFilled > 0, "No tokens to claim");
        require(bid.isFilled, "Bid not fully processed");

        uint256 amountFilled = bid.qtyFilled;
        bid.qtyFilled = 0;

        token.safeTransfer(msg.sender, amountFilled);
        emit TokensClaimed(msg.sender, amountFilled);
    }

    function refundETH(bytes32 _bidHash) external nonReentrant {
        uint256 bidValue = bidHashToBidValue[_bidHash];
        Bid storage bid = bidDetails[bidValue];

        require(bid.bidder == msg.sender, "Not the bidder");
        require(bid.refundValue > 0, "No refund available");

        uint256 refundAmount = bid.refundValue;
        bid.refundValue = 0;

        (bool success, ) = msg.sender.call{value: refundAmount}("");
        require(success, "ETH refund failed");

        emit RefundIssued(msg.sender, refundAmount);
    }

    function checkAuctionEnd() external {
        if (block.timestamp >= auctionEndTime || tokensSold >= tokenSupply) {
            _endAuction();
        }
    }

    // Internal functions
    function _createBid(uint256 _quantity, uint256 _bidPricePerUnit) internal returns (bytes32) {
        bidDetails[_bidPricePerUnit] = Bid({
            bidder: msg.sender,
            bidPricePerUnit: _bidPricePerUnit,
            bidQty: _quantity,
            qtyFilled: 0,
            refundValue: 0,
            isFilled: false
        });
        
        bytes32 bidHash = keccak256(abi.encodePacked(msg.sender, _bidPricePerUnit, _quantity));
        bidHashToBidValue[bidHash] = _bidPricePerUnit;

        return bidHash;
    }

    function _fillWinningBids() internal {
        uint256 remainingTokens = tokenSupply - tokensSold;

        while (remainingTokens > 0 && orderedBids.length > 0) {

            uint256 highestBidPerValue = orderedBids[orderedBids.length -1];
            orderedBids.pop();
            Bid storage bid = bidDetails[highestBidPerValue];

            uint256 tokensToFill = bid.bidQty < remainingTokens ? bid.bidQty : remainingTokens;
            bid.qtyFilled = tokensToFill;
            tokensSold += tokensToFill;
            remainingTokens -= tokensToFill;

            if (bid.bidQty > tokensToFill) {
                bid.refundValue = (bid.bidQty - tokensToFill) * bid.bidPricePerUnit;
            }

            bid.isFilled = true;
        }
    }

    function _endAuction() internal {
        if (!auctionEnded) {
            auctionEnded = true;
            _fillWinningBids();
            emit AuctionEnded();
        }
    }
}