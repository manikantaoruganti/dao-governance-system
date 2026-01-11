import { expect } from "chai";
import { ethers } from "hardhat";

describe("GovernanceDAO", function () {
  let dao: any;
  let owner: any, member1: any, member2: any;

  beforeEach(async function () {
    [owner, member1, member2] = await ethers.getSigners();
    const GovernanceDAO = await ethers.getContractFactory("GovernanceDAO");
    dao = await GovernanceDAO.deploy();
    await dao.deployed();
  });

  describe("Deposits", function () {
    it("Should allow ETH deposits", async function () {
      const depositAmount = ethers.utils.parseEther("10");
      await dao.depositToTreasury("highConviction", { value: depositAmount });
      expect(await dao.balances(owner.address)).to.equal(depositAmount);
    });
  });

  describe("Proposals", function () {
    it("Should create proposals", async function () {
      const depositAmount = ethers.utils.parseEther("10");
      await dao.depositToTreasury("highConviction", { value: depositAmount });
      
      const tx = await dao.createProposal(
        member1.address,
        ethers.utils.parseEther("5"),
        "Test Proposal",
        0
      );
      
      expect(await dao.proposalCount()).to.equal(1);
    });
  });

  describe("Voting", function () {
    it("Should allow voting", async function () {
      const depositAmount = ethers.utils.parseEther("10");
      await dao.depositToTreasury("highConviction", { value: depositAmount });
      
      await dao.createProposal(
        member2.address,
        ethers.utils.parseEther("5"),
        "Test Proposal",
        0
      );
      
      await ethers.provider.mine(2);
      await dao.vote(0, 0); // Vote For
      
      const proposal = await dao.proposals(0);
      expect(proposal.forVotes).to.be.gt(0);
    });
  });
});
