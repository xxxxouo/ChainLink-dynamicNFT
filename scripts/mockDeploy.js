const hre = require("hardhat");

async function main() {
 // 获取合约并部署
 const nftContractFactory = await hre.ethers.getContractFactory("MockV3Aggregator");
 const nftContract = await nftContractFactory.deploy("8","3034715771688");
 await nftContract.deployed();
 const info = await nftContract.latestRoundData()
 console.log(info.answer.toString(),'info');
 console.log("nftContract deployed to ", nftContract.address);
 process.exitCode = 0
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
