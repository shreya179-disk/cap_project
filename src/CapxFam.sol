// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import{ERC721Upgradeable} from  "lib/openzeppelin-contracts-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol";
import {ERC721PausableUpgradeable} from "lib/openzeppelin-contracts-upgradeable/contracts/token/ERC721/extensions/ERC721PausableUpgradeable.sol";
import {ERC721URIStorageUpgradeable} from "lib/openzeppelin-contracts-upgradeable/contracts/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import {OwnableUpgradeable} from "lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {ERC721BurnableUpgradeable} from "lib/openzeppelin-contracts-upgradeable/contracts/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import {ERC721EnumerableUpgradeable} from "lib/openzeppelin-contracts-upgradeable/contracts/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import {Initializable} from "lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {ECDSA} from "lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";


interface ICapxFam {
    // Custom Errors
    error CallerNotWhitelisted();
    error InvalidMessageHash();
    error UnauthorizedMinter();
    error UserAlreadyMinted();
    error UnauthorizedAccess();
    error InvalidInput();
    error InvalidCapxProfileAddress();

    event CapxFamMinted(
        uint256 passID,
        address receipient,
        string tokenURI
    );

    event CapxFamBurned(uint256 tokenId, address receipient);

    // Functions
    function mint(
        bytes32 _messageHash,
        bytes calldata _signature,
        string calldata _tokenURI
    ) external returns (uint256);

    function isAuthorized(address _checkAddress) external view returns (bool);

    function isUserWhitelisted(
        address _checkAddress
    ) external view returns (bool);

    function isWhitelistingActive() external view returns (bool);

    function getAuthorizedMinter() external view returns (address);

    function getOwnerOf(uint256 _passId) external view returns (address);

    function getPassIdOfUser(
        address _userAddress
    ) external view returns (uint256);
}

interface ICapxProfileCredential {
    error InvalidCallMode();
    error InvalidInput();
    error UserAlreadyMintedTheProfile();
    error InvalidMessageHash();
    error UnauthorizedMinter();
    error InvalidUserAddress();
    error CallerNotWhitelisted();
    error TokenNotTransferable();
    error UnauthorizedAccess();
    error InvalidCapxProfileAddress();

    struct CapxProfileData {
        uint256 _capxProfileId;
        bytes32 _username;
        string _profileImage;
        uint256 _rank;
        uint256 _totalUnitsEarned;
        uint256 _totalUnitsBurned;
        uint256 _numberOfQuestsPerformed;
    }

    function mintCapxProfile(
        uint8 _callmode,
        bytes32 _messageHash,
        bytes calldata _signature,
        string calldata _tokenURI,
        address _userAddress,
        uint256 _profileId
    ) external returns (uint256);

    function burn(
        bytes32 _messageHash,
        bytes calldata _signature,
        uint256 _profileId
    ) external;

    function updateTokenURI(
        bytes32 _messageHash,
        bytes calldata _signature,
        uint256 _profileId,
        string memory _tokenURI
    ) external;

    function getOwnerOf(uint256 _profileId) external view returns (address);

    function isAuthorized(address _checkAddress) external view returns (bool);

    function getProfileIdOfUser(
        address _userAddress
    ) external view returns (uint256);

    function isUserWhitelisted(
        address _checkAddress
    ) external view returns (bool);

    function isWhitelistingActive() external view returns (bool);

    function getAuthorizedMinter() external view returns (address);

    function adminMintCapxProfile(
        uint8 _callmode,
        bytes32 _messageHash,
        bytes calldata _signature,
        string calldata _tokenURI,
        address _receipient,
        uint256 _profileId
    ) external returns (uint256);
}

/// @title Capx Fam NFT
/// @notice Main smart contract to mint and manage Capx Fam NFT
contract CapxFam is
    Initializable,
    ERC721Upgradeable,
    ERC721PausableUpgradeable,
    OwnableUpgradeable,
    ERC721BurnableUpgradeable,
    ERC721EnumerableUpgradeable,
    ERC721URIStorageUpgradeable,
    UUPSUpgradeable,
    ICapxFam 
{
    // Data Variables
    address internal authorizedMinter;
    bool public isWhitelistActive;
    ICapxProfileCredential internal capxProfileCredential;

    // Mappings
    mapping(address => bool) internal isWhitelisted;
    mapping(address => uint256) internal userCapxFamID;
    mapping(address => bool) internal isAuthorizedAddress;
    mapping(uint256 => uint256) public profileIdToMintId;

    uint256 public mintedTokenIds;

    // Modifiers

    modifier onlyAuthorizedOrPassOwner(uint256 _passId) {
        if (
            owner() != _msgSender() &&
            !isAuthorizedAddress[_msgSender()] &&
            _ownerOf(_passId) != _msgSender()
        ) {
            revert UnauthorizedAccess();
        }
        _;
    }

    modifier onlyAuthorized() {
        if (owner() != _msgSender() && !isAuthorizedAddress[_msgSender()]) {
            revert UnauthorizedAccess();
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _initialOwner,
        string memory _name,
        string memory _symbol,
        address _authorizedMinter,
        address _ICapxProfileCredential
    ) public initializer {
        if (_ICapxProfileCredential == address(0)) {
            revert InvalidCapxProfileAddress();
        }
        __ERC721_init(_name, _symbol);
        __ERC721Pausable_init();
        __Ownable_init(_initialOwner);
        __ERC721Burnable_init();
        __UUPSUpgradeable_init();
        authorizedMinter = _authorizedMinter;
        capxProfileCredential = ICapxProfileCredential(_ICapxProfileCredential);
        mintedTokenIds = 0;
    }

    // OverRiding Functions
    function _authorizeUpgrade(
        address newImplementation
    ) internal virtual override {}

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(
            ERC721Upgradeable,
            ERC721URIStorageUpgradeable,
            ERC721EnumerableUpgradeable
        )
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _increaseBalance(
        address _account,
        uint128 _amount
    )
        internal
        virtual
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
    {
        super._increaseBalance(_account, _amount);
    }

    function _update(
        address to,
        uint256 tokenId,
        address auth
    )
        internal
        virtual
        override(
            ERC721Upgradeable,
            ERC721PausableUpgradeable,
            ERC721EnumerableUpgradeable
        )
        returns (address)
    {
        if (isWhitelistActive) {
            if (
                !(owner() == _msgSender() ||
                    owner() == to ||
                    isWhitelisted[_msgSender()] ||
                    isWhitelisted[to])
            ) revert CallerNotWhitelisted();
        }
        return super._update(to, tokenId, auth);
    }
    






    function tokenURI(
        uint256 tokenId
    )
        public
        view
        virtual
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    // Helper Functions

   

    function recoverSigner(
        bytes32 messagehash,
        bytes memory signature
    ) internal pure returns (address) {
        bytes32 messageDigest = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messagehash)
        );
        return ECDSA.recover(messageDigest, signature);
    }

    

    
    
    // Core Functions

    /**
     * @dev Set whitelist status of given address to given boolean value
     * @param _addressToBeWhitelisted address to be added/removed from whitelisted
     * @param _whitelistStatus true(add to whitelist) or false(remove from whitelist)
     */
    function setAddressWhiteListStatus(
        address _addressToBeWhitelisted,
        bool _whitelistStatus
    ) external onlyOwner {
        isWhitelisted[_addressToBeWhitelisted] = _whitelistStatus;
    }

    /**
     * @dev Set the active status of whitelist
     * @param _status true(activate whitelist) or false(deactivate whitelist)
     */
    function setIsWhitelistActive(bool _status) external onlyOwner {
        isWhitelistActive = _status;
    }

    /**
     * @dev Add or remove authorization access of a address
     * @param _account true(activate whitelist) or false(deactivate whitelist)
     * @param _authorizationStatus true(authorize _account) false(remove _account's authorization)
     */
    function setAuthorization(
        address _account,
        bool _authorizationStatus
    ) external onlyOwner {
        isAuthorizedAddress[_account] = _authorizationStatus;
    }

    /**
     * @dev Pause contract
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Function to mint Capx Fam
     * @dev The mints Capx Fam
     * @param _messageHash Message Hash generated by the platform
     * @param _signature Signature signed by authorized minter
     * @param _tokenURI TokenURI of Capx Fam
     */
    function mint(
        bytes32 _messageHash,
        bytes calldata _signature,
        string calldata _tokenURI
    ) external whenNotPaused returns (uint256) {
        address _receipient = _msgSender();
        uint256 passID = capxProfileCredential.getProfileIdOfUser(_receipient);
        if (passID == 0) {
            revert InvalidInput();
        }
        if (
            _messageHash == bytes32(0) ||
            keccak256(abi.encodePacked(_tokenURI, _receipient)) != _messageHash
        ) {
            revert InvalidMessageHash();
        }
        if (
            _signature.length == 0 ||
            recoverSigner(_messageHash, _signature) != authorizedMinter
        ) {
            revert UnauthorizedMinter();
        }

        if (userCapxFamID[_receipient] != 0) {
            revert UserAlreadyMinted();
        }

        mintedTokenIds += 1;
        userCapxFamID[_receipient] = block.number;
        _safeMint(_receipient, passID);
        _setTokenURI(passID, _tokenURI);
        profileIdToMintId[passID] = mintedTokenIds;
        emit CapxFamMinted(passID, _receipient, _tokenURI);

        return (passID);
    }

    function adminMint(
        address[] calldata _recipients,
        string[] calldata _tokenURIs
    )
        external
        whenNotPaused
        onlyAuthorized
        returns (
            uint256[] memory mintedPassIDs,
            uint256[] memory skippedProfileIDs
        )
    {
        if (_recipients.length != _tokenURIs.length) revert InvalidInput();

        uint256[] memory passIDs = new uint256[](_recipients.length);
        uint256[] memory skippedIDs = new uint256[](_recipients.length); // Array for skipped IDs
        uint256 skippedCount = 0; // Counter for skipped IDs

        for (uint256 i = 0; i < _recipients.length; i++) {
            address recipient = _recipients[i];
            string calldata currtokenURI = _tokenURIs[i];

            uint256 passID = capxProfileCredential.getProfileIdOfUser(
                recipient
            );
            if (
                passID == 0 ||
                userCapxFamID[recipient] != 0
            ) {
                skippedIDs[skippedCount] = passID;
                skippedCount++;
                continue; // Move to the next iteration
            }

            mintedTokenIds += 1;
            userCapxFamID[recipient] = block.number;
            _safeMint(recipient, passID);
            _setTokenURI(passID, currtokenURI);
            profileIdToMintId[passID] = mintedTokenIds;
            emit CapxFamMinted(passID, recipient, currtokenURI);

            passIDs[i] = passID;
        }

        return (passIDs, skippedIDs);
    }

    /**
     * @notice Burn Capx Fam
     * @dev To be executed only by authorized addresses or the owner of the Fam
     * @param _passId Token ID of Capx Fam
     */
    function burn(
        uint256 _passId
    ) public override onlyAuthorizedOrPassOwner(_passId) {
        address owner = _ownerOf(_passId);
        if (owner == address(0)) {
            revert ERC721NonexistentToken(_passId);
        }

        _burn(_passId);
        userCapxFamID[owner] = 0;
        emit CapxFamBurned(_passId, owner);
    }

    function updateTokenURI(
        bytes32 _messageHash,
        bytes calldata _signature,
        uint256 _passId,
        string memory _tokenURI
    ) external {
        if (
            _messageHash == "" ||
            keccak256(abi.encodePacked(_passId, _tokenURI)) != _messageHash
        ) {
            revert InvalidMessageHash();
        }
        if (
            _signature.length == 0 ||
            recoverSigner(_messageHash, _signature) != authorizedMinter
        ) {
            revert UnauthorizedMinter();
        }
        _setTokenURI(_passId, _tokenURI);
    }

    /**
     * @dev Set given address to capxProfileCredential
     * @param _capxProfileCredential address of capxProfileCredential
     */
    function setCapxProfileCredential(
        address _capxProfileCredential
    ) external onlyOwner {
        capxProfileCredential = ICapxProfileCredential(_capxProfileCredential);
    }

    /**
     * @dev Set authorized minter address
     * @param _authorizedMinter new authorized minter address.
     */
    function setAuthorizationMinter(address _authorizedMinter) external onlyOwner {
        authorizedMinter = _authorizedMinter;
    }

    function isAuthorized(address _checkAddress) external view returns (bool) {
        return isAuthorizedAddress[_checkAddress];
    }

    function isUserWhitelisted(
        address _checkAddress
    ) external view returns (bool) {
        return isWhitelisted[_checkAddress];
    }

    function isWhitelistingActive() external view returns (bool) {
        return isWhitelistActive;
    }

    function getAuthorizedMinter() external view returns (address) {
        return authorizedMinter;
    }

    function getOwnerOf(uint256 _passId) external view returns (address) {
        return _ownerOf(_passId);
    }

    function getPassIdOfUser(
        address _userAddress
    ) external view returns (uint256) {
        return userCapxFamID[_userAddress];
    }

    /**
     * @dev Transfer ownership of the CapxFam NFT
     * @param _to The address to which the NFT is being transferred
     * @param _passId Token ID of Capx Fam
     */
    function transferCapxFam(address _to, uint256 _passId) external {
        address owner = _ownerOf(_passId);
        require(owner == _msgSender() || isApprovedForAll(owner, _msgSender()), "Not authorized to transfer");

        _safeTransfer(owner, _to, _passId, "");

        // Update userCapxFamID mapping
        userCapxFamID[owner] = 0;
        userCapxFamID[_to] = _passId;

        //emit Transfer(owner, _to, _passId);
    }

    /**
     * @dev Approve another address to transfer the ownership of the CapxFam NFT
     * @param _to The address being approved for transfer
     * @param _passId Token ID of Capx Fam
     */
    function approveTransfer(address _to, uint256 _passId) external {
        address owner = _ownerOf(_passId);
        require(owner == _msgSender(), "Not the owner of the NFT");

        approve(_to, _passId);

        //emit Approval(owner, _to, _passId);
    }

    /**
     * @dev Get the approved address for a single NFT
     * @param _passId Token ID of Capx Fam
     * @return The approved address
     */
    function getApprovedAddress(uint256 _passId) external view returns (address) {
      //  require(_exists(_passId), "NFT does not exist");
        return getApproved(_passId);
    }

     /**
    * @dev Set or unset the approval of an authorized address as an operator for the caller's NFTs
    * @param _authorizedAddress Address to be set as an authorized address for the caller
    * @param _approved Approval status of the operator
    */
    function setApprovalForAll(address _authorizedAddress, bool _approved) public override(ERC721Upgradeable, IERC721) onlyOwner {
    require(_authorizedAddress != _msgSender(), "Cannot approve yourself");
    _setApprovalForAll(_msgSender(), _authorizedAddress, _approved);
    }


    /**
    * @dev Check if an authorized address is approved as an operator for the caller
    * @param _authorizedAddress Address of the authorized address
    * @param _operator Address of the operator
    * @return The approval status
    */
    function isApprovedOperator(address _authorizedAddress, address _operator) external view returns (bool) {
    return operatorApprovals[_authorizedAddress][_operator];
    }



    /**
     * @dev Get the approval status of an operator for a given owner
     * @param _owner Address of the owner
     * @param _operator Address of the operator
     * @return The approval status
     */
    function getApprovalStatus(address _owner, address _operator) external view returns (bool) {
        return isApprovedForAll(_owner, _operator);
    }
    

    /**
    * @dev Update the TokenURI of a Capx Fam NFT
    * @param _passId Token ID of Capx Fam
    * @param _tokenURI New TokenURI
    */
    function updateTokenURI(uint256 _passId, string memory _tokenURI) external  {
    require(isAuthorizedAddress[_msgSender()] || owner() == _msgSender(), "Unauthorized to update TokenURI");
    require(bytes(_tokenURI).length > 0, "TokenURI cannot be empty");
    
    // Ensure the NFT exists
    //require(_exists(_passId), "NFT does not exist");
    
    // Update the TokenURI
     _setTokenURI(_passId, _tokenURI);
    }
    
}

    

