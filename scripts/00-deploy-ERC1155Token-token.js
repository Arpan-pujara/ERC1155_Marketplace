const { ethers, upgrades, network } = require('hardhat');
const { verify } = require('../utils/verify');

const main = async () => {
  const [deployer] = await ethers.getSigners();

  console.log('Deploying ERC1155Token...', deployer);
  const ERC1155Token = await ethers.getContractFactory('ERC1155Token'); // Correct factory retrieval
  const token = await upgrades.deployProxy(ERC1155Token, [], {
    initializer: 'initialize',
    signer: deployer.address, // Specify signer for deployment
  });
  await token.waitForDeployment();

  console.log(`ERC1155Token deployed to: ${token.target}`);

  // Verify the deployment (corrected condition)
  if (network.config.chainId !== 31337 && process.env.ETHERSCAN_API_KEY) {
    console.log('Verifying...');
    await verify(token.target, []);
  }
};

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
