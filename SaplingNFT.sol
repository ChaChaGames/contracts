// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "hardhat/console.sol";

contract SaplingNFT is ERC721Enumerable, AccessControl {
    using SafeMath for uint256;
    using Strings for uint256;
    using Counters for Counters.Counter;
    using Address for address payable;
    using SafeERC20 for IERC20;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    address public payToken = 0x0000000000000000000000000000000000001000;
    address public treasury = 0x0000000000000000000000000000000000001000;
    
    struct dutchAuctionParams {
        uint256 startTime;
        uint256 startPrice;
        uint256 reservePrice;
        uint256 priceStep;
        uint256 timeRange;
    }

    // Roles
    bytes32 private constant whitelistedRole = keccak256("whitelist");

    // Public parameters
    uint256 public maxSupply = 80000000;
    uint256 public whitelistSupply = 0;
    uint256 public publicSupply = 80000000;
    uint256 public totalWhitelistClaimable = 0;
    uint256 public totalPublicSaleClaimable = 80000000;
    uint256 public totalWhitelistClaimed = 0;
    uint256 public totalPublicSaleClaimed = 0;
    uint256 public whitelistSalePrice = 1 ether;
    bool public whitelistSaleActivated = false;
    bool public publicSaleActivated = false;
    bool public paymentTokenActivated = true;
    bool public revealed = true;

    dutchAuctionParams public dutchAuction;

    // Public variables
    string public baseURI;
    uint256 public lastId = 1;
    mapping(address => uint256) public whitelistClaimed;
    mapping(address => uint256) public publicSaleClaimed;
    mapping(address => uint256) public givewaysClaimed;
    mapping(uint256 => address) public idToAddress;

    // Private variables
    Counters.Counter private _tokenIds;
    
    // Events
    event PublicSaleClaim(
        address indexed from,
        uint256 price,
        address payToken,
        uint256 timestamp,
        uint256[] tokenIds
    );
    event WhitelistSaleClaim(
        address indexed from,
        uint256 price,
        address payToken,
        uint256 timestamp,
        uint256[] tokenIds
    );
    event GivewayClaim(
        address indexed from,
        uint256 timestamp,
        uint256[] tokenIds
    );

    /**
    @dev Gives the owner of the contract the admin role
    */
    constructor(string memory name, string memory symbol,string memory nftBaseURI) ERC721(name, symbol) {
        _setRoleAdmin(whitelistedRole, DEFAULT_ADMIN_ROLE);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        baseURI = nftBaseURI;
    }

    /// MODIFIERS

    /**
    @dev Modifier for only admins
     */
    modifier onlyAdmin() {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "Restricted to admins."
        );
        _;
    }

    /// PUBLIC FUNCTIONS
    
    /**
    @dev setSetAddress
     */
    function setAddress(address _payToken,address _treasury) public onlyAdmin {
        if(_payToken!=address(0)) payToken = _payToken;
        if(_treasury!=address(0)) treasury = _treasury;
    }


    function setPaymentTokenActivated(bool tokenActivated) external onlyAdmin {
        paymentTokenActivated = tokenActivated;
    }

    /**
    @dev Base URI setter
     */
    function setBaseURI(string memory _newBaseURI) public onlyAdmin {
        baseURI = _newBaseURI;
    }
    
    /**
    @dev Returns token URI
     */
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        string memory base = _baseURI();
        if (!revealed) {
            return bytes(base).length > 0 ? string(abi.encodePacked(base)) : "";
        }
        return
            bytes(base).length > 0
                ? string(abi.encodePacked(base, tokenId.toString()))
                : "";
    }


    /**
    @dev Give current price  
     */
    function getPublicSalePrice()
        public
        view
        returns (uint256)
    {
        return getPublicSalePriceFor(block.timestamp);
    }


    /**ip
    @dev Give current price of the dutch auction
     */
    function getPublicSalePriceFor(uint256 _timestamp)
        public
        view
        returns (uint256)
    {
        require(publicSaleActivated, "Public sale is not active.");
        _timestamp = Math.max(_timestamp, dutchAuction.startTime);
        uint256 priceDiff = _timestamp
            .sub(dutchAuction.startTime)
            .div(dutchAuction.timeRange)
            .mul(dutchAuction.priceStep);

        if (priceDiff > dutchAuction.startPrice - dutchAuction.reservePrice) {
            return dutchAuction.reservePrice;
        }
        return dutchAuction.startPrice.sub(priceDiff);
    }

    /// EXTERNAL FUNCTIONS
    
    /**
    @dev Add an account as an admin of this contract
     */
    function addAdmin(address account) external onlyAdmin {
        grantRole(DEFAULT_ADMIN_ROLE, account);
    }

    /**
    @dev Remove an account as an admin of this contract
     */
    function removeAdmin(address account) external onlyAdmin {
        revokeRole(DEFAULT_ADMIN_ROLE, account);
    }

    /**
    @dev Setter for the total of tokens claimable for whitelisted accounts
     */
    function setTotalWhitelistClaimable(uint256 _nb) external onlyAdmin {
        totalWhitelistClaimable = _nb;
    }

    /**
    @dev Setter for the total of tokens claimable for public sale
     */
    function setTotalPublicSaleClaimable(uint256 _nb) external onlyAdmin {
        totalPublicSaleClaimable = _nb;
    }
    /**
    @dev Setter for price of whitelist sale
     */
    function setWhitelistMintPrice(uint256 _nb) external onlyAdmin {
        whitelistSalePrice = _nb;
    }

    /**
    @dev Setter for whitelist supply
     */
    function setWhitelistSupply(uint256 _nb) external onlyAdmin {
        whitelistSupply = _nb;
    }

    /**
    @dev Setter for public sale supply
     */
    function setPublicSupply(uint256 _nb) external onlyAdmin {
        publicSupply = _nb;
    }

    /**
    @dev Grant whitelist role for given addresses
     */
    function addAddressesToWhitelist(address[] calldata addresses)
        external
        onlyAdmin
    {
        for (uint32 i = 0; i < addresses.length; i++) {
            grantRole(whitelistedRole, addresses[i]);
        }
    }

    /**
    @dev Remove given addresses from the whitelist role
     */
    function removeAddressesOfWhitelist(address[] calldata addresses)
        external
        onlyAdmin
    {
        for (uint32 i = 0; i < addresses.length; i++) {
            revokeRole(whitelistedRole, addresses[i]);
        }
    }

    /**
    @dev Active or deactivate whitelist sale
     */
    function flipWhitelistSale() external onlyAdmin {
        whitelistSaleActivated = !whitelistSaleActivated;
    }

    /**
    @dev Switch status of revealed
     */
    function flipRevealed() external onlyAdmin {
        revealed = !revealed;
    }

    /**
    @dev Activate the public sale as a dutch auction
     */
    function activatePublicSale(
        uint256 _start,
        uint256 _reserve,
        uint256 _step,
        uint256 _timeRange
    ) external onlyAdmin {
        require(_start >= _reserve, "Invalid prices");
        require(
            _start != 0 && _reserve != 0 && _step != 0 && _timeRange != 0,
            "Invalid parameters"
        );
        publicSaleActivated = true;
        dutchAuction = dutchAuctionParams(
            block.timestamp,
            _start,
            _reserve,
            _step,
            _timeRange
        );
    }
  
    function setPublicSaleActivated(bool _publicSaleActivated) external onlyAdmin {
        publicSaleActivated = _publicSaleActivated;
    }
        
    /**
    @dev Mint for giveways
     */
    function givewayMint(address _to, uint256 _nb) external onlyAdmin {
        require(totalSupply().add(_nb) <= maxSupply, "Not enough tokens left.");

        uint256[] memory _tokenIdsMinted = new uint256[](_nb);
        for (uint32 i = 0; i < _nb; i++) {
            _tokenIdsMinted[i] = _mint(_to);
        }
        givewaysClaimed[_to] = givewaysClaimed[_to].add(_nb);
        emit GivewayClaim(_to, block.timestamp, _tokenIdsMinted);
    }

    /**
    @dev Mint for whitelisted address
     */
    function whitelistSaleMint(uint256 _nb)
        external
        payable
        onlyRole(whitelistedRole)
    {
        require(whitelistSaleActivated, "Whitelisted sale is not active.");
        require(totalSupply().add(_nb) <= maxSupply, "Not enough tokens left.");
        require(
            totalWhitelistClaimed.add(_nb) <= whitelistSupply,
            "Not enough supply."
        );

        if(paymentTokenActivated){
            require(IERC20(payToken).balanceOf(msg.sender) >= whitelistSalePrice.mul(_nb),"Insufficient amount.");
            IERC20(payToken).transferFrom(msg.sender,address(this),whitelistSalePrice.mul(_nb) );
        }else{
            require(msg.value >= whitelistSalePrice.mul(_nb), "Insufficient amount." );
        }

        require(
            whitelistClaimed[msg.sender].add(_nb) <= totalWhitelistClaimable,
            "Limit exceeded."
        );
        
        uint256[] memory _tokenIdsMinted = new uint256[](_nb);
        for (uint32 i = 0; i < _nb; i++) {
            _tokenIdsMinted[i] = _mint(msg.sender);
        }
        totalWhitelistClaimed = totalWhitelistClaimed.add(_nb);
        whitelistClaimed[msg.sender] = whitelistClaimed[msg.sender].add(_nb);

        idToAddress[lastId] = msg.sender;
        lastId += 1;
        emit WhitelistSaleClaim(msg.sender, whitelistSalePrice, payToken,block.timestamp, _tokenIdsMinted);
    }

    /**
    @dev Public mint as a dutch auction
     */
    function publicSaleMint(uint256 _nb) external payable {
        require(publicSaleActivated, "Public sale is not active.");
        require(totalSupply().add(_nb) <= maxSupply, "Not enough tokens left.");

        require(
            totalPublicSaleClaimed.add(_nb) <= publicSupply,
            "Not enough supply."
        );
        uint256 currentTimestamp = block.timestamp;

        uint256 currentPrice = getPublicSalePriceFor(currentTimestamp);

        if(paymentTokenActivated){
            require(IERC20(payToken).balanceOf(msg.sender) >= currentPrice.mul(_nb),"Insufficient amount.");
            IERC20(payToken).transferFrom(msg.sender,address(this),currentPrice.mul(_nb) );
        }else{
            require(msg.value >= currentPrice.mul(_nb), "Insufficient amount.");
        }

        require(
            publicSaleClaimed[msg.sender].add(_nb) <= totalPublicSaleClaimable,
            "Limit exceeded."
        );
        
        uint256[] memory _tokenIdsMinted = new uint256[](_nb);
        for (uint32 i = 0; i < _nb; i++) {
            _tokenIdsMinted[i] = _mint(msg.sender);
        }
        totalPublicSaleClaimed = totalPublicSaleClaimed.add(_nb);
        publicSaleClaimed[msg.sender] = publicSaleClaimed[msg.sender].add(_nb);

        idToAddress[lastId] = msg.sender;
        lastId += 1;
        
        emit PublicSaleClaim(
            msg.sender,
            currentPrice,
            payToken,
            currentTimestamp,
            _tokenIdsMinted
        );
    }

    /**
    @dev Check if an address is whitelisted
     */
    function isWhitelisted(address account) external view returns (bool) {
        return hasRole(whitelistedRole, account);
    }

    /**
    @dev Check if an address is admin
     */
    function isAdmin(address account) external view returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, account);
    }

    /// INTERNAL FUNCTIONS

    /**
    @dev Returns base token URI
     */
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function _mint(address _to) internal returns (uint256) {
        _tokenIds.increment();
        uint256 _tokenId = _tokenIds.current();
        _safeMint(_to, _tokenId);
        return _tokenId;
    }

    /// Necessary overrides
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721Enumerable, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }


    receive() external payable {}
    

    function _transferEth(address _to, uint256 _amount) internal {
        (bool success, ) = _to.call{value: _amount}('');
        require(success, "_transferEth: Eth transfer failed");
    }

    // Emergency function: In case any ETH get stuck in the contract unintentionally
    // Only owner can retrieve the asset balance to a recipient address
    function rescueETH() onlyAdmin external {
        _transferEth(treasury, address(this).balance);
    }

    // Emergency function: In case any ERC20 tokens get stuck in the contract unintentionally
    // Only owner can retrieve the asset balance to a recipient address
    function rescueERC20(address asset) onlyAdmin external { 
        IERC20(asset).transfer(treasury, IERC20(asset).balanceOf(address(this)));
    }
}