import { ethers } from "hardhat";
import { expect } from "chai";
import {
    time,
    loadFixture,
  } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { MyToken, TokenAuctionWithArray } from "../typechain-types";
// import { BigNumber } from "ethers";

describe("TokenAuction Using Array", function () {
  let auction: TokenAuctionWithArray;
  let token: MyToken;
  let owner: any;
  let addr1: any;
  let addr2: any;
  let addr3: any;
  let addr4: any;
  let addr5: any;
  let addr6: any;
  let addr7: any;
  let addr8: any;
  let addr9: any;
  let addrs: any;
  const initialSupply = 10; // 1000 tokens
  const tokenPrice = ethers.parseEther("0.5"); // 1 ETH per token
  const auctionDuration = 86400; // 1 day

  beforeEach(async function () {
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();

    // Deploy an ERC20 token for auction
    const ERC20 = await ethers.getContractFactory("MyToken");
    token = await ERC20.deploy();
    await token.waitForDeployment();
    // await token.mint(owner.address, initialSupply);

    // Deploy the TokenAuction contract
    const TokenAuction = await ethers.getContractFactory("TokenAuctionWithArray");
    const auctionStartTime = await time.latest() + 60; // starts in 1 min
    const auctionEndTime = auctionStartTime + auctionDuration;

    auction = await TokenAuction.deploy();
    await auction.waitForDeployment();

    // Owner approves tokens to be spent by the auction contract
    await token.approve(await auction.getAddress(), initialSupply);
    await auction.startAuction(await token.getAddress(),
    initialSupply,
    auctionStartTime,
    auctionEndTime,
    tokenPrice);
  });

  it("Should place a bid successfully", async function () {
    const bidQty = 5; // 5 tokens
    const bidPricePerUnit = ethers.parseEther("2"); // 2 ETH per token
    const bidValue = ethers.parseEther("10");
    console.log("Bid Value: ", bidValue)

    // Fund the auction contract with tokens
    await token.transfer(await auction.getAddress(), initialSupply);

    // Fast forward to auction start time
    // await ethers.provider.send("evm_increaseTime", [60]);
    await time.increaseTo(await auction.auctionStartTime())
    // await ethers.provider.send("evm_mine", []);

    // ethers.keccak256(new ethers.AbiCoder())
    // ethers.solidityPacked;
    // ethers.solidityPackedKeccak256;
    const bidHashDirect = ethers.solidityPackedKeccak256(
        ["address", "uint256", "uint256"],
        [addr1.address, bidPricePerUnit, bidQty]
    );
    // Place bid by addr1
    await expect(
      auction.connect(addr1).placeBid(bidQty, bidPricePerUnit, { value: bidValue })
    )
      .to.emit(auction, "BidPlaced")
      .withArgs(bidHashDirect, addr1.address, bidQty, bidPricePerUnit); // using anyValue for bidHash since it's dynamically generated

    const bidDetails = await auction.bidDetails(bidPricePerUnit);
    expect(bidDetails.bidder).to.equal(addr1.address);
    expect(bidDetails.bidQty).to.equal(bidQty);
    expect(bidDetails.bidPricePerUnit).to.equal(bidPricePerUnit);
  });

  it("Should reject bids with insufficient funds", async function () {
    const bidQty = 5; // 5 tokens
    const bidPricePerUnit = ethers.parseEther("2"); // 2 ETH per token
    const bidValue = ethers.parseEther("1"); // 1 ETH short

    // Fund the auction contract with tokens
    await token.transfer(await auction.getAddress(), initialSupply);

    // Fast forward to auction start time
    await time.increaseTo(await auction.auctionStartTime())

    // Try placing bid with insufficient funds
    await expect(
      auction.connect(addr1).placeBid(bidQty, bidPricePerUnit, { value: bidValue })
    ).to.be.revertedWith("Insufficient ETH sent");
  });

  it("Should end the auction and distribute tokens to highest bidders", async function () {
    const bidQty1 = 5; // 5 tokens
    const bidPricePerUnit1 = ethers.parseEther("2"); // 2 ETH per token

    const bidQty2 = 3; // 3 tokens
    const bidPricePerUnit2 = ethers.parseEther("3"); // 3 ETH per token

    // Fund the auction contract with tokens
    await token.transfer(await auction.getAddress(), initialSupply);

    // Fast forward to auction start time
    await time.increaseTo(await auction.auctionStartTime())

    // Place two bids
    await auction.connect(addr1).placeBid(bidQty1, bidPricePerUnit1, { value: ethers.parseEther("10") });
    await auction.connect(addr2).placeBid(bidQty2, bidPricePerUnit2, { value: ethers.parseEther("9") });

    // Fast forward to auction end time
    await time.increaseTo(await auction.auctionEndTime())

    // End auction
    await auction.endAuction();

    // addr2 should have won 3 tokens since they bid at a higher price
    const bidHash2 = ethers.solidityPackedKeccak256(["address", "uint256", "uint256"], [addr2.address, bidPricePerUnit2, bidQty2]);
    const bidDetails2 = await auction.bidDetails(await auction.bidHashToBidValue(bidHash2));
    expect(bidDetails2.qtyFilled).to.equal(bidQty2);

    // addr1 should have won 5 tokens
    const bidHash1 = ethers.solidityPackedKeccak256(["address", "uint256", "uint256"], [addr1.address, bidPricePerUnit1, bidQty1]);
    const bidDetails1 = await auction.bidDetails(await auction.bidHashToBidValue(bidHash1));
    expect(bidDetails1.qtyFilled).to.equal(bidQty1);
  });

  it("Should allow winning bidders to claim their tokens", async function () {
    const bidQty = 5; // 5 tokens
    const bidPricePerUnit = ethers.parseEther("2"); // 2 ETH per token

    // Fund the auction contract with tokens
    await token.transfer(await auction.getAddress(), initialSupply);

    // Fast forward to auction start time
    await time.increaseTo(await auction.auctionStartTime())

    // Place bid
    await auction.connect(addr1).placeBid(bidQty, bidPricePerUnit, { value: ethers.parseEther("10") });

    // Fast forward to auction end time
    await time.increaseTo(await auction.auctionEndTime())

    // End auction
    await auction.endAuction();

    // Claim tokens
    const bidHash = ethers.solidityPackedKeccak256(["address", "uint256", "uint256"], [addr1.address, bidPricePerUnit, bidQty]);
    await auction.connect(addr1).claimTokens(bidHash);

    const balanceAfter = await token.balanceOf(addr1.address);
    expect(balanceAfter).to.equal(bidQty);
  });

  it("Should allow losing bidders to claim a refund", async function () {
    const bidQty1 = 10; // 5 tokens
    const bidPricePerUnit1 = ethers.parseEther("1.5"); // 1.5 ETH per token

    const bidQty2 = 6; // 3 tokens
    const bidPricePerUnit2 = ethers.parseEther("2.5"); // 2.5 ETH per token

    // Fund the auction contract with tokens
    await token.transfer(await auction.getAddress(), 10);

    // Fast forward to auction start time
    await time.increaseTo(await auction.auctionStartTime())

    // Place bids
    await auction.connect(addr1).placeBid(bidQty1, bidPricePerUnit1, { value: ethers.parseEther("15") });
    await auction.connect(addr2).placeBid(bidQty2, bidPricePerUnit2, { value: ethers.parseEther("15") });

    // Fast forward to auction end time
    await time.increaseTo(await auction.auctionEndTime())

    // End auction
    await auction.endAuction();

    // addr1 should receive a refund because they were outbid
    const bidHash = ethers.solidityPackedKeccak256(["address", "uint256", "uint256"], [addr1.address, bidPricePerUnit1, bidQty1]);
    console.log("Caller is : ", addr1.address)
    //check that they recived tokens
    const ethBalanceBeforeCall = await ethers.provider.getBalance(addr1);
    await auction.connect(addr1).refundETH(bidHash);
    const ethBalanceAfterCall = await ethers.provider.getBalance(addr1);
    expect(ethBalanceAfterCall).to.be.greaterThan(ethBalanceBeforeCall)
    const bidDetails = await auction.bidDetails(await auction.bidHashToBidValue(bidHash));
    expect(bidDetails.refundValue).to.equals(0);


    // addr1's balance should increase by the refund amount
    // Testing refund logic properly would require capturing balances before and after
  });
  it("should do a large auction", async function(){
    const bidQty1 = 1; // 1 token
    const bidPricePerUnit1 = ethers.parseEther("1.5"); // 1.5 ETH per token

    const bidQty2 = 1; // 3 tokens
    const bidPricePerUnit2 = ethers.parseEther("1.55"); // 2.5 ETH per token

    const bidQty3 = 2; // 5 tokens
    const bidPricePerUnit3 = ethers.parseEther("1.6"); // 1.5 ETH per token

    const bidQty4 = 1; // 3 tokens
    const bidPricePerUnit4 = ethers.parseEther("1.65"); // 2.5 ETH per token

    const bidQty5 = 1; // 5 tokens
    const bidPricePerUnit5 = ethers.parseEther("1.7"); // 1.5 ETH per token

    const bidQty6 = 1; // 3 tokens
    const bidPricePerUnit6 = ethers.parseEther("1.75"); // 2.5 ETH per token

    const bidQty7 = 1; // 5 tokens
    const bidPricePerUnit7 = ethers.parseEther("1.8"); // 1.5 ETH per token

    const bidQty8 = 2; // 3 tokens
    const bidPricePerUnit8 = ethers.parseEther("1.85"); // 2.5 ETH per token

    const bidQty9 = 2; // 3 tokens
    const bidPricePerUnit9 = ethers.parseEther("1.9"); // 2.5 ETH per token

    [owner, addr1, addr2, addr3, addr4, addr5, addr6, addr7, addr8, addr9] = await ethers.getSigners();

    // Fund the auction contract with tokens
    await token.transfer(await auction.getAddress(), 10);

    // Fast forward to auction start time
    await time.increaseTo(await auction.auctionStartTime())

    // Place bids
    await auction.connect(addr1).placeBid(bidQty1, bidPricePerUnit1, { value: ethers.parseEther("1.5") });
    await auction.connect(addr2).placeBid(bidQty2, bidPricePerUnit2, { value: ethers.parseEther("1.55") });

    await auction.connect(addr3).placeBid(bidQty3, bidPricePerUnit3, { value: ethers.parseEther("3.2") });
    await auction.connect(addr4).placeBid(bidQty4, bidPricePerUnit4, { value: ethers.parseEther("1.65") });

    await auction.connect(addr5).placeBid(bidQty5, bidPricePerUnit5, { value: ethers.parseEther("1.7") });
    await auction.connect(addr6).placeBid(bidQty6, bidPricePerUnit6, { value: ethers.parseEther("1.75") });

    await auction.connect(addr7).placeBid(bidQty7, bidPricePerUnit7, { value: ethers.parseEther("1.8") });
    await auction.connect(addr8).placeBid(bidQty8, bidPricePerUnit8, { value: ethers.parseEther("3.7") });

    await auction.connect(addr9).placeBid(bidQty9, bidPricePerUnit9, { value: ethers.parseEther("3.8") });

    // Fast forward to auction end time
    await time.increaseTo(await auction.auctionEndTime())

    // End auction
    await auction.endAuction();
  })
});