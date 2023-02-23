const hre = require("hardhat");

async function main() {
 // 获取合约并部署
 const nftContractFactory = await hre.ethers.getContractFactory("BullBear");
 const nftContract = await nftContractFactory.deploy("10","0xA39434A63A52E749F02807ae27335515BA4b07F7","0xa8c02b883d32cd554f7cd5d68c98fa9b57cb8ebe");
 await nftContract.deployed();
 console.log("nftContract deployed to ", nftContract.address);
 process.exitCode = 0
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
