// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

/// @title ERC1155 Property Token Contract

import {CountersUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ERC1155PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155PausableUpgradeable.sol";
import {ERC1155SupplyUpgradeable, ERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import {MerkleProofUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";

contract ERC1155Token is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    ERC1155PausableUpgradeable,
    ERC1155SupplyUpgradeable
{
    //SECTION : Global variables

    //ANCHOR : token id counter
    using CountersUpgradeable for CountersUpgradeable.Counter;

    CountersUpgradeable.Counter private _tokenIds;
    bytes32 public root;

    //SECTION EVENTS

    //ANCHOR : Mint event
    event MintedNewPropertyToken(uint256 indexed tokenId, string uri);

    event MintBatch(
        address[] indexed to,
        uint256 indexed tokenId,
        uint256[] amounts
    );

    //!SECTION END EVENTS

    //SECTION : MAPPINGS

    //ANCHOR : mapping for offset
    mapping(uint256 => bool) public offsetStatus;
    mapping(uint256 => string) private _tokenURIs;

    //!SECTION END MAPPINGS

    //SECTION : CUSTOM ERRORS

    error TokenIdDoesNotExist();
    error URIIsNotValid();
    error ArrayLengthMismatch();
    error InvalidRecipientAddress();
    error AmountMustBeGreaterThanZero();
    error TokenIsMarkedToOffset();
    error NotInWhitelist();

    //!SECTION END CUSTOM ERRORS

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    //SECTION FUNCTIONS

    //ANCHOR : initialize
    function initialize(bytes32 _root) external initializer {
        __ERC1155_init("");
        __Ownable_init();
        __ERC1155Pausable_init();
        __ERC1155Supply_init();
        root = _root;
    }

    /// @notice UUPS upgrade mandatory function: To authorize the owner to upgrade the contract
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    /// @notice Update the Merkle root to whitelist addresses
    /// @param _newRoot The new Merkle root
    function updateMerkleRoot(bytes32 _newRoot) external onlyOwner {
        root = _newRoot;
    }

    /// @dev Check if an address is whitelisted using MerkleProof
    /// @param proof The Merkle proof
    /// @param leaf The leaf node (address hashed)
    /// @return bool indicating if the address is whitelisted
    function isWhitelisted(
        bytes32[] memory proof,
        bytes32 leaf
    ) public view returns (bool) {
        return MerkleProofUpgradeable.verify(proof, root, leaf);
    }

    /**
        @notice to return the MetaDataURI of the NFT 
        @param _tokenId token id of the NFT
        
    */
    function uri(
        uint256 _tokenId
    ) public view override(ERC1155Upgradeable) returns (string memory) {
        if (!exists(_tokenId)) revert TokenIdDoesNotExist();
        return _tokenURIs[_tokenId];
    }

    function getCurrentTokenId() public view returns (uint256) {
        return _tokenIds.current();
    }

    //SECTION : MINT

    function AirdropTokens(
        address[] calldata to,
        uint256[] calldata amounts,
        string calldata __uri,
        bytes32[] calldata merkleProof
    ) external onlyOwner {
        if (to.length != amounts.length) revert ArrayLengthMismatch();
        if (bytes(__uri).length == 0) revert URIIsNotValid();
        if (
            !isWhitelisted(merkleProof, keccak256(abi.encodePacked(msg.sender)))
        ) {
            revert NotInWhitelist();
        }

        _tokenIds.increment();
        uint256 _currentTokenId = _tokenIds.current();

        for (uint256 i = 0; i < to.length; i++) {
            if (to[i] == address(0)) revert InvalidRecipientAddress();
            if (amounts[i] == 0) revert AmountMustBeGreaterThanZero();
            _mint(to[i], _currentTokenId, amounts[i], "");
        }
        _setURI(_currentTokenId, __uri);
        emit MintedNewPropertyToken(_currentTokenId, __uri);
    }

    //!SECTION : End Mint

    //SECTION: Offset
    function markPropertyOffset(uint256 _tokenId) external onlyOwner {
        if (!exists(_tokenId)) revert TokenIdDoesNotExist();
        offsetStatus[_tokenId] = true;
    }

    //!SECTION: end Offset

    //SECTION: Recover from Offset
    function recoverPropertyFromOffset(uint256 _tokenId) external onlyOwner {
        if (!exists(_tokenId)) revert TokenIdDoesNotExist();
        offsetStatus[_tokenId] = false;
    }

    //!SECTION: end Offset

    //SECTION : pause/unpause

    //ANCHOR : PAUSE
    //function to pause contract
    function pause() external onlyOwner {
        _pause();
    }

    //ANCHOR : UNPAUSE
    // function to unpause contract
    function unPause() external onlyOwner {
        _unpause();
    }

    //!SECTION : END PAUSE/UNPAUSE

    //SECTION : URI - Management

    //ANCHOR function to set the uri of a token
    function updateTokenURI(
        uint256 _tokenId,
        string memory __uri
    ) external onlyOwner {
        if (!exists(_tokenId)) revert TokenIdDoesNotExist();
        if (bytes(__uri).length == 0) revert URIIsNotValid();
        _tokenURIs[_tokenId] = __uri;
    }

    //!SECTION : End uri - management

    /**
        @notice setting URI of token
        @param _tokenId token id of the NFT
        @param _uri MetaDataURI of the NFT
    */
    function _setURI(uint256 _tokenId, string memory _uri) internal {
        _tokenURIs[_tokenId] = _uri;
    }

    //SECTION: Add offset to safeTransferFrom
    function _safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal override {
        if (offsetStatus[id]) revert TokenIsMarkedToOffset();
        super._safeTransferFrom(from, to, id, amount, data);
    }

    //!SECTION: End Add offset to safeTransferFrom

    // override function to save from errors in ERC1155
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    )
        internal
        override(ERC1155PausableUpgradeable, ERC1155SupplyUpgradeable)
        whenNotPaused
    {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    //ANCHOR: override function to save from errors in ERC1155
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC1155Upgradeable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    //!SECTION END overridden functions
}
