// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Investline Marketplace Contract
/// @notice This Contract enables Property Tokens to be listed on Investline Marketplace for trade

import {BasicMetaTransaction} from "./helper/BasicMetaTransaction.sol";
import {CountersUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ERC1155PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155PausableUpgradeable.sol";
import {ERC1155SupplyUpgradeable, ERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import {MerkleProofUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {ERC1155HolderUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "./interfaces/ITokenHelpers.sol";

error ListProperty__CryptoPaymentDisabled();
error ListProperty__AddressNotWhitelisted();
error ListProperty__AmountMustBeGreaterThanZero();
error ListProperty__CallerMustOwnToken();
error ListProperty__FundReceiverAddressCannotBeZero();
error ListProperty__CannotBuyOwnProperty();
error ListProperty__NotEnoughPropertyTokens();
error ListProperty__PropertyNotAvailable();
error ListProperty__NotCallerListing();
error ListProperty__NotEnoughFunds();

contract ERC1155Marketplacelace is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    ERC1155HolderUpgradeable,
    ReentrancyGuardUpgradeable,
    BasicMetaTransaction
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    CountersUpgradeable.Counter private _listingIds;
    ITokenUpgradeable public propertyToken;

    bytes32 public root;

    struct List {
        address seller;
        uint256 tokenId;
        uint256 amount;
        uint256 price;
        uint256 tokensAvailable;
        bool completed;
        uint256 listingId;
        address fundReceiverAddress;
    }

    event PropertyListed(
        address indexed seller,
        uint256 indexed tokenId,
        uint256 amount,
        uint256 pricePerToken,
        uint256 indexed listingId,
        address fundReceiverAddress
    );

    event PropertySold(
        address indexed seller,
        address indexed buyer,
        uint256 indexed tokenId,
        uint256 amount,
        uint256 pricePerToken,
        uint256 listingId
    );

    event PropertyDelisted(
        uint256 indexed tokenId,
        uint256 indexed listingId,
        address indexed seller
    );

    mapping(uint256 => List) private idToProperty;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _propertyToken) external initializer {
        if (_propertyToken == address(0)) {
            revert ListProperty__FundReceiverAddressCannotBeZero();
        }
        propertyToken = ITokenUpgradeable(_propertyToken);
        __Ownable_init();
    }

    /// @notice UUPS upgrade mandatory function: To authorize the owner to upgrade the contract
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    /**@dev to check if address is whitelisted using Merkleproof */
    function isWhitelisted(
        bytes32[] memory proof,
        bytes32 leaf
    ) public view returns (bool) {
        return MerkleProofUpgradeable.verify(proof, root, leaf);
    }

    /**
     * @notice returns property trade details based on the listingId
     * @param _id here represents unique listingId
     */
    function viewPropertyById(uint256 _id) external view returns (List memory) {
        return idToProperty[_id];
    }

    /**
     * @notice returns total number of listings inside marketplace
     * @dev backend can traverse from 1 --> listingIds to get each property trade details
     */
    function getTotalIds() external view returns (uint256) {
        return _listingIds.current();
    }

    /**@dev Set the Merkleroot for the whitelisted address */
    function setRoot(bytes32 _root) external onlyOwner {
        root = _root;
    }

    /**@notice fallback function for receiving unknown funds */
    receive() external payable {}

    /**@notice withdraw explicit funds from contract */
    function withdrawExplicitFunds(uint256 _amount) external onlyOwner {
        payable(_msgSender()).transfer(_amount);
    }

    /**
     * @notice list property on marketplace
     * @dev current implementation does not take decimal value for per token price
     * @param proof MerkleProof required to verify _msgSender() whitelisted?
     * @param tokenId Property tokenId inside propertyToken Token Contract
     * @param amount Number of tokens available in wei for public listing
     * @param price per wei token price for the listed property
     */
    function listProperty(
        bytes32[] memory proof,
        uint256 tokenId,
        uint256 amount,
        uint256 price,
        address fundReceiverAddress
    ) external nonReentrant {
        if (!isWhitelisted(proof, keccak256(abi.encodePacked(_msgSender())))) {
            revert ListProperty__AddressNotWhitelisted();
        }
        if (amount == 0) {
            revert ListProperty__AmountMustBeGreaterThanZero();
        }
        if (propertyToken.balanceOf(_msgSender(), tokenId) < amount) {
            revert ListProperty__CallerMustOwnToken();
        }
        if (fundReceiverAddress == address(0)) {
            revert ListProperty__FundReceiverAddressCannotBeZero();
        }

        _listingIds.increment();
        uint256 listingId = _listingIds.current();

        idToProperty[listingId] = List(
            _msgSender(),
            tokenId,
            amount,
            price,
            amount,
            false,
            listingId,
            fundReceiverAddress
        );

        emit PropertyListed(
            _msgSender(),
            tokenId,
            amount,
            price,
            listingId,
            fundReceiverAddress
        );
        propertyToken.safeTransferFrom(
            _msgSender(),
            address(this),
            tokenId,
            amount,
            ""
        );
    }

    /**
     * @notice buy property on marketplace
     * @dev _listingId is the unique identifier because multiple listings can be there for same tokenId
     * @param proof MerkleProof required to verify _msgSender() whitelisted?
     * @param listingId Unique identity to every listing inside marketplace
     * @param amount Number of tokens _msgSender() wants to buy
     */
    function buyProperty(
        bytes32[] memory proof,
        uint256 listingId,
        uint256 amount
    ) external payable nonReentrant {
        if (!isWhitelisted(proof, keccak256(abi.encodePacked(_msgSender())))) {
            revert ListProperty__AddressNotWhitelisted();
        }
        if (_msgSender() == idToProperty[listingId].seller) {
            revert ListProperty__CannotBuyOwnProperty();
        }
        if (idToProperty[listingId].tokensAvailable < amount) {
            revert ListProperty__NotEnoughPropertyTokens();
        }
        if (idToProperty[listingId].completed) {
            revert ListProperty__PropertyNotAvailable();
        }
        if (msg.value < amount * idToProperty[listingId].price) {
            revert ListProperty__NotEnoughFunds();
        }

        idToProperty[listingId].tokensAvailable -= amount;

        if (idToProperty[listingId].tokensAvailable == 0) {
            idToProperty[listingId].completed = true;
        }

        emit PropertySold(
            idToProperty[listingId].seller,
            _msgSender(),
            idToProperty[listingId].tokenId,
            amount,
            idToProperty[listingId].price,
            listingId
        );

        propertyToken.safeTransferFrom(
            address(this),
            _msgSender(),
            idToProperty[listingId].tokenId,
            amount,
            ""
        );

        payable(idToProperty[listingId].fundReceiverAddress).transfer(
            msg.value
        );
    }

    /**
     * @notice Delist property from marketplace
     * @dev instead of removing the listing entry completely the trade would be marked as complete
     * @param proof MerkleProof required to verify _msgSender() whitelisted?
     * @param _listingId Unique identity to every listing inside marketplace
     */
    function deListProperty(
        bytes32[] memory proof,
        uint256 _listingId
    ) external nonReentrant {
        if (!isWhitelisted(proof, keccak256(abi.encodePacked(_msgSender())))) {
            revert ListProperty__AddressNotWhitelisted();
        }
        if (_msgSender() != idToProperty[_listingId].seller) {
            revert ListProperty__NotCallerListing();
        }
        if (idToProperty[_listingId].completed) {
            revert ListProperty__PropertyNotAvailable();
        }

        idToProperty[_listingId].completed = true;

        emit PropertyDelisted(
            idToProperty[_listingId].tokenId,
            _listingId,
            _msgSender()
        );

        propertyToken.safeTransferFrom(
            address(this),
            _msgSender(),
            idToProperty[_listingId].tokenId,
            idToProperty[_listingId].tokensAvailable,
            ""
        );
    }

    /** 
        @notice function to override for BMT
    */
    function _msgSender() internal view virtual override returns (address) {
        return msgSender();
    }
}
