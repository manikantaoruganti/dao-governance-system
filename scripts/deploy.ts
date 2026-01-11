import { ethers } from "hardhat";

async function main() {
  console.log("Deploying GovernanceDAO contract...");
  
  const GovernanceDAO = await ethers.getContractFactory("GovernanceDAO");
  const dao = await GovernanceDAO.deploy();
  
  await dao.deployed();
  
  console.log("GovernanceDAO deployed to:", dao.address);
  console.log("\nDeployment completed successfully!");
  console.log("Contract Address:", dao.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
