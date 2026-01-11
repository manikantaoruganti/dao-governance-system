import { ethers } from "hardhat";

async function main() {
  console.log("Seeding test data...");
  
  const [owner, member1, member2] = await ethers.getSigners();
  const GovernanceDAO = await ethers.getContractFactory("GovernanceDAO");
  const dao = GovernanceDAO.attach(process.env.DAO_ADDRESS || "");
  
  // Deposit ETH
  const depositAmount = ethers.utils.parseEther("10");
  await dao.connect(owner).depositToTreasury("highConviction", { value: depositAmount });
  await dao.connect(member1).depositToTreasury("experimental", { value: depositAmount });
  await dao.connect(member2).depositToTreasury("operational", { value: depositAmount });
  
  console.log("Test data seeded successfully!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
