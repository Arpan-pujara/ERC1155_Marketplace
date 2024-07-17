const { expect } = require('chai');
const { ethers, upgrades } = require('hardhat');

describe('ERC1155Token', () => {
  let Token, token;
  let owner, addr1, addr2;
  let amount = [10, 1000];
  let uri = 'tokenURI';
  let root, proof;

  beforeEach(async () => {
    [owner, addr1, addr2] = await ethers.getSigners();

    const Token = await ethers.getContractFactory('ERC1155Token');

    // Deploy the contract using upgrades.deployProxy
    token = await upgrades.deployProxy(Token, [root], {
      initializer: 'initialize',
    });

    // The contract is now deployed and initialized
  });

  describe('Deployment', () => {
    it('Should set the right owner', async function () {
      expect(await token.owner()).to.equal(owner.address);
    });
  });

  describe('Airdrop Tokens', () => {
    it('Should allow owner to airdrop tokens', async function () {
      const addresses = [addr1.address, addr2.address];

      const tx = await token
        .connect(owner)
        .AirdropTokens(addresses, amount, uri, proof);
      await tx.wait(); // Wait for the transaction to be mined

      // Get the current tokenId
      const currentTokenId = await token.getCurrentTokenId();

      expect(await token.balanceOf(addr1.address, currentTokenId)).to.equal(
        amount[0]
      );
      expect(await token.balanceOf(addr2.address, currentTokenId)).to.equal(
        amount[1]
      );
    });

    it('Should fail for non-owner', async () => {
      const addresses = [addr1.address];

      await expect(
        token.connect(addr1).AirdropTokens(addresses, amount, uri, proof)
      ).to.be.revertedWith('Ownable: caller is not the owner');
    });
  });

  describe('Pause and Unpause', () => {
    it('Should allow owner to pause and unpause the contract', async function () {
      // Pausing the contract
      await token.connect(owner).pause();
      expect(await token.paused()).to.equal(true);

      // Unpausing the contract
      await token.connect(owner).unPause();
      expect(await token.paused()).to.equal(false);
    });

    it('Should fail to pause and unpause for non-owner', async function () {
      // Attempt to pause the contract by a non-owner
      await expect(token.connect(addr1).pause()).to.be.revertedWith(
        'Ownable: caller is not the owner'
      );

      // Attempt to unpause the contract by a non-owner
      await token.connect(owner).pause(); // First pause the contract as owner
      await expect(token.connect(addr1).unPause()).to.be.revertedWith(
        'Ownable: caller is not the owner'
      );
    });

    it('Should prevent airdropping tokens when the contract is paused', async function () {
      // First, pause the contract
      await token.connect(owner).pause();

      // Prepare parameters for the AirdropTokens function
      const addresses = [addr1.address, addr2.address];

      // Attempt to airdrop tokens while the contract is paused
      await expect(
        token.connect(owner).AirdropTokens(addresses, amount, uri, proof)
      ).to.be.revertedWith('Pausable: paused');

      await token.connect(owner).unPause();

      // Attempting AirdropTokens function again to ensure it works when not paused
      await expect(
        token.connect(owner).AirdropTokens(addresses, amount, uri, proof)
      ).to.not.be.reverted; // Adjust the assertion based on your contract's expected behavior

      // Get the current tokenId
      const currentTokenId = await token.getCurrentTokenId();

      /* Retrieve the tokenId from your contract */
      expect(await token.balanceOf(addresses[0], currentTokenId)).to.equal(
        amount[0]
      );
    });
  });

  describe('Offset Management', function () {
    it('Should mark and recover property offset by the owner', async function () {
      const addresses = [addr1.address, addr2.address];
      const tx = await token
        .connect(owner)
        .AirdropTokens(addresses, amount, uri, proof);
      await tx.wait(); // Wait for the transaction to be mined
      const currentTokenId = await token.getCurrentTokenId();
      // Marking the property offset as owner
      await token.connect(owner).markPropertyOffset(currentTokenId);
      expect(await token.offsetStatus(currentTokenId)).to.equal(true);

      // Recovering the property from offset as owner
      await token.connect(owner).recoverPropertyFromOffset(currentTokenId);
      expect(await token.offsetStatus(currentTokenId)).to.equal(false);
    });

    it('Should fail to mark and recover property offset by non-owner', async function () {
      const addresses = [addr1.address, addr2.address];
      const tx = await token
        .connect(owner)
        .AirdropTokens(addresses, amount, uri, proof);
      await tx.wait(); // Wait for the transaction to be mined
      // Attempt to mark property offset by a non-owner
      const currentTokenId = await token.getCurrentTokenId();
      await expect(
        token.connect(addr1).markPropertyOffset(currentTokenId)
      ).to.be.revertedWith('Ownable: caller is not the owner');
      // Attempt to recover property from offset by a non-owner
      await token.connect(owner).markPropertyOffset(currentTokenId); // First mark the property as owner
      await expect(
        token.connect(addr1).recoverPropertyFromOffset(currentTokenId)
      ).to.be.revertedWith('Ownable: caller is not the owner');
    });
  });

  describe('Token URI Management', function () {
    it('Should update token URI by owner', async function () {
      let newURI = 'https://newtokenuri.com';
      const addresses = [addr1.address, addr2.address];
      const tx = await token
        .connect(owner)
        .AirdropTokens(addresses, amount, uri, proof);
      await tx.wait(); // Wait for the transaction to be mined
      // Update the token URI as the owner

      const currentTokenId = await token.getCurrentTokenId();
      await token.connect(owner).updateTokenURI(currentTokenId, newURI);

      // Check if the token URI was updated correctly
      expect(await token.uri(currentTokenId)).to.equal(newURI);
    });

    it('Should fail to update token URI by non-owner', async function () {
      let newURI = 'https://newtokenuri.com';
      const addresses = [addr1.address, addr2.address];
      const tx = await token
        .connect(owner)
        .AirdropTokens(addresses, amount, uri, proof);
      await tx.wait(); // Wait for the transaction to be mined
      // Attempt to update the token URI by a non-owner
      const currentTokenId = await token.getCurrentTokenId();
      await expect(
        token.connect(addr1).updateTokenURI(currentTokenId, newURI)
      ).to.be.revertedWith('Ownable: caller is not the owner');
    });
  });
});
