// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "hardhat/console.sol";
import "./interface/IGameMerchant.sol";

contract BlindBoxSale is ERC1155Holder, Ownable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;
    using Address for address payable;
    using SafeERC20 for IERC20;
    address public gameMerchant;

    address[] public feeRecipients;
    uint32[] public feePercentages;
    bool public publicSaleActivated = true;
    bool public limitedTimeSaleActivated = false;
    bool public limitedAmountSaleActivated = false;
    uint256 public saleStartTime;
    uint256 public saleTime;
    uint256 public saleAmount;
    uint256 private publicSalePrice = 0 ether;
    uint256 public diffDay = 1 days;
    
    BlindBoxInfo[] public saleBlindBox;
    mapping(address => mapping(uint256 => mapping(address => Auction))) public nftContractAuctions;
    mapping(uint256 => uint256) public saleAmounts;

    address public payToken = 0x3056B1d1AC0cE9c4DF9525c10908dDCcD8B335A2;
    mapping(address => uint256) bnbTransferCredits;
    mapping(address => mapping(address => uint256)) ercTransferCredits;

    
    //Each Auction is unique to each NFT (contract + id pairing).
    struct Auction {
        //map token ID to
        uint256 buyNowPrice;
        uint256 amountSupply;
        uint256 amount;
        uint256 auctionEnd;
        address nftSeller;
        address whitelistedBuyer; //The seller can specify a whitelisted address for a sale (this is effectively a direct sale).
        address ERC20Token; // The seller can specify an ERC20 token that can be used to bid or purchase the NFT.
        address recipient;
    }

    struct BlindBoxInfo {
        address nftContractAddress;
        uint256 tokenId;
        address nftSellerAddress;
    }

    event BuyBox(
        address nftContractAddress,
        uint256 tokenId,
        uint256 amount,
        address nftSeller,
        address nftBuyer,
        address erc20Token,
        uint256 buyNowPrice,
        uint256 userId,  
        address[] feeRecipients,
        uint32[] feePercentages,
        uint256 timeIndex
    );

    event CreateSale(
        address nftContractAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 amountSupply,
        address nftSeller,
        uint256 buyNowPrice,
        address recipient,
        address erc20Token,
        address[] feeRecipients,
        uint32[] feePercentages
    );
    
    event NFTWithdrawn(
        address nftContractAddress,
        uint256 tokenId,
        address nftSeller
    );

    event BuyNowPriceUpdated(
        address nftContractAddress,
        uint256 tokenId,
        address nftSellerAddress,
        uint256 newBuyNowPrice
    );

    function _isERC20Auction(address _auctionERC20Token)
        internal
        pure
        returns (bool)
    {
        return _auctionERC20Token != address(0);
    }

    /**
    @dev Give current price  
     */
    function getPublicSalePrice()
        public
        view
        returns (uint256)
    {
        return publicSalePrice;
    }

    function allLength() external view returns (uint) {
        return saleBlindBox.length;
    }

   function _transferNftToAuctionContract(
        address _nftContractAddress,
        uint256 _tokenId,
        uint256 _amount
    ) internal {
        IERC1155(_nftContractAddress).safeTransferFrom(
            msg.sender,
            address(this),
            _tokenId,
            _amount,
            "0x0"
        );
    }

    modifier batchWithinLimits(uint256 _batchTokenIdsLength) {
        require(
            _batchTokenIdsLength > 0 && _batchTokenIdsLength <= 10000,
            "Number of NFTs not applicable for batch sale"
        );
        _;
    }
    
    function setDiffDay(uint256 _diffDay) external onlyOwner {
        diffDay = _diffDay;
    }


    function setGameMerchant(address _gameMerchant) external  onlyOwner()  {
        gameMerchant = _gameMerchant;
    }

    function setSale(uint256 _saleStartTime,uint256 _saleTime,uint256 _saleAmount) external onlyOwner {
        if(_saleStartTime!=0)saleStartTime= _saleStartTime;
        if(_saleTime!=0)saleTime= _saleTime;
        if(_saleAmount!=0)saleAmount= _saleAmount;
    }

    function setAddress(address _payToken) external onlyOwner {
        if(_payToken!=address(0)) payToken = _payToken;
    }
    
    function createSale(
        address _nftContractAddress,
        uint256 _tokenId,
        uint256 _amount,
        uint256 _buyNowPrice,
        address _recipient
    )
        external onlyOwner
    {
        //require(IGameMerchant(gameMerchant).merchants(msg.sender).id != 0, 'Merchant does not exist'); 
        require(publicSaleActivated, "sale is not active.");
        require(nftContractAuctions[_nftContractAddress][_tokenId][msg.sender].amount<=0, " on sale.");
        _transferNftToAuctionContract(_nftContractAddress, _tokenId,_amount);
        _setupSale(
            _nftContractAddress,
            _tokenId,
            _amount,
            _buyNowPrice,
            _recipient
        );
        publicSalePrice = _buyNowPrice;
        saleBlindBox.push(BlindBoxInfo(_nftContractAddress,_tokenId,msg.sender));
        emit CreateSale(
            _nftContractAddress,
            _tokenId,
            _amount,
            _amount,
            msg.sender,
            _buyNowPrice,
            _recipient,
            payToken,
            feeRecipients,
            feePercentages
        );
    }

    modifier saleWithinLimits( address _nftContractAddress,uint256 _tokenId, address _nftSeller,uint256 _amount) {
        require(
            nftContractAuctions[_nftContractAddress][_tokenId][_nftSeller].amount>=_amount,
            "Insufficient quantity available"
        );
        _;
    }
    
    function getLastBlindBoxSaleInfo()
        external
        view  returns (uint256 _allLength,uint256 _saleStartTime,uint256 _saleTime, uint256 _saleAmount , uint256 _currentSaleAmount ,address _payToken,uint256 _publicSalePrice ,bool _publicSaleActivated,bool _limitedTimeSaleActivated,bool _limitedAmountSaleActivated ,BlindBoxInfo memory _blindBoxInfo,Auction memory _auction)
    {   
        BlindBoxInfo memory blindBoxInfo_ = saleBlindBox.length!=0?saleBlindBox[saleBlindBox.length-1]:BlindBoxInfo(address(0),0,address(0));
        Auction memory auction_ = blindBoxInfo_.tokenId!=0?nftContractAuctions[blindBoxInfo_.nftContractAddress][blindBoxInfo_.tokenId][blindBoxInfo_.nftSellerAddress]:Auction(0,0,0,0,address(0),address(0),address(0),address(0));
        uint256 timeIndex  = getTimeIndex();
        return(saleBlindBox.length,saleStartTime,saleTime,saleAmount,saleAmounts[timeIndex],payToken,getPublicSalePrice(),publicSaleActivated,limitedTimeSaleActivated,limitedAmountSaleActivated,blindBoxInfo_,auction_);
    }
    
    function saleWithTimeLimits()
        internal
        view
    {
        uint256 diffTime  = block.timestamp.sub(saleStartTime).mod(1 days  * diffDay);
        require(diffTime < saleTime, "Sale with time limits" );
    }
    
    function saleWithSaleAmountLimits(uint256 amount)
        internal
        view
    {
        uint256 timeIndex  = getTimeIndex();
        require(saleAmounts[timeIndex].add(amount) <= saleAmount, "Sale with sale amount limits" );
    }
    
    function getTimeIndex()
        public
        view returns(uint256)
    {
        uint256 timeIndex  = 0;
        if(block.timestamp.sub(saleStartTime)<= 1 days ){
            timeIndex = saleStartTime;
        }else{
            timeIndex = block.timestamp.sub(saleStartTime).div(1 days  * diffDay).mul(1 days  * diffDay).add(saleStartTime);
        }
        return(timeIndex);
    }


    function setPublicSaleActivated(bool _publicSaleActivated) external onlyOwner {
        publicSaleActivated =  _publicSaleActivated;
    }

    function setLimitedSaleActivated(bool _limitedTimeSaleActivated, bool _limitedAmountSaleActivated) external onlyOwner {
        limitedAmountSaleActivated =  _limitedAmountSaleActivated;
        limitedTimeSaleActivated =  _limitedTimeSaleActivated;
    }

    function buyBox(
        address _nftContractAddress,
        uint256 _tokenId,
        address _nftSeller ,
        uint256 _amount,
        uint256 userId
        )
        external
        batchWithinLimits(_amount)
        saleWithinLimits(_nftContractAddress,_tokenId,_nftSeller,_amount)
    {
        require(publicSaleActivated, "sale is not active.");
        if(limitedTimeSaleActivated)saleWithTimeLimits();
        if(limitedAmountSaleActivated)saleWithSaleAmountLimits(_amount);

        uint256 _buyNowPrice = nftContractAuctions[_nftContractAddress][_tokenId][_nftSeller].buyNowPrice;
        // address _recipient = nftContractAuctions[_nftContractAddress][_tokenId][_nftSeller].recipient;
       
        if (_isERC20Auction(payToken)) {
            if(nftContractAuctions[_nftContractAddress][_tokenId][_nftSeller].recipient==address(0)){
                IERC20(payToken).transferFrom(msg.sender,address(this),_amount.mul(_buyNowPrice) );
                ercTransferCredits[msg.sender][payToken] = ercTransferCredits[msg.sender][payToken].add(_amount.mul(_buyNowPrice));
            }else{
                IERC20(payToken).transferFrom(msg.sender,nftContractAuctions[_nftContractAddress][_tokenId][_nftSeller].recipient,_amount.mul(_buyNowPrice) );
            }
        } else {
            // attempt to send the funds to the recipient
            if(nftContractAuctions[_nftContractAddress][_tokenId][_nftSeller].recipient==address(0)){
                bnbTransferCredits[msg.sender] = bnbTransferCredits[msg.sender].add(_amount.mul(_buyNowPrice));
            }else{
                payable(nftContractAuctions[_nftContractAddress][_tokenId][_nftSeller].recipient).transfer(_amount.mul(_buyNowPrice));
            }
        }

        IERC1155(_nftContractAddress).safeTransferFrom(
            address(this),
            msg.sender,
            _tokenId,
            _amount,
            "0x0"
        );

        nftContractAuctions[_nftContractAddress][_tokenId][_nftSeller].amount  = nftContractAuctions[_nftContractAddress][_tokenId][_nftSeller].amount.sub(_amount);
        if(nftContractAuctions[_nftContractAddress][_tokenId][_nftSeller].amount<=0){
            _resetAuction(_nftContractAddress,_tokenId,nftContractAuctions[_nftContractAddress][_tokenId][_nftSeller].nftSeller);
        }
        saleAmounts[getTimeIndex()] = saleAmounts[getTimeIndex()].add(_amount);        

        emit BuyBox(
            _nftContractAddress,
            _tokenId,
            _amount,
            _nftSeller,
            msg.sender,
            payToken,
            _buyNowPrice,
            userId,
            feeRecipients,
            feePercentages,
            getTimeIndex()
        );
    }


    modifier onlyNftSeller(address _nftContractAddress, uint256 _tokenId,address _nftSeller) {
        require(
            msg.sender ==
                nftContractAuctions[_nftContractAddress][_tokenId][_nftSeller].nftSeller,
            "Only the owner can call this function"
        );
        _;
    }

    function withdrawAllCredits(address asset) external {
        uint256 amount = 0;
        if(asset==address(0)){
            amount = bnbTransferCredits[msg.sender];
            require(amount != 0, "no credits to withdraw");
            payable(msg.sender).transfer(amount);
            bnbTransferCredits[msg.sender] = 0;
        }else{
            amount = ercTransferCredits[msg.sender][asset];
            require(amount != 0, "no credits to withdraw");
            IERC20(asset).transfer(msg.sender, amount);
            ercTransferCredits[msg.sender][asset] = 0;
        }
   }

    function withdrawNft(address _nftContractAddress, uint256 _tokenId)
        external
        onlyNftSeller(_nftContractAddress,_tokenId,msg.sender)
    {
        uint256 _amount = nftContractAuctions[ _nftContractAddress ][_tokenId][msg.sender].amount;
        IERC1155(_nftContractAddress).safeTransferFrom(
            address(this),
            nftContractAuctions[_nftContractAddress][_tokenId][msg.sender].nftSeller,
            _tokenId,
            _amount,
            "0x0"
        );
        
        _resetAuction(_nftContractAddress,_tokenId,msg.sender);
        emit NFTWithdrawn(_nftContractAddress, _tokenId, msg.sender);
    }

    modifier priceGreaterThanZero(uint256 _price) {
        require(_price > 0, "Price cannot be 0");
        _;
    }

    function updateBuyNowPrice(
        address _nftContractAddress,
        uint256 _tokenId,
        uint256 _newBuyNowPrice
    )
        external
        priceGreaterThanZero(_newBuyNowPrice)
        onlyNftSeller(_nftContractAddress,_tokenId,msg.sender)
    {   
        nftContractAuctions[_nftContractAddress][_tokenId][msg.sender].buyNowPrice = _newBuyNowPrice;
        publicSalePrice = _newBuyNowPrice;
        emit BuyNowPriceUpdated(_nftContractAddress, _tokenId,msg.sender, _newBuyNowPrice);
    }


   function _resetAuction(address _nftContractAddress, uint256 _tokenId,address _nftSeller)
        internal
    {   
        nftContractAuctions[_nftContractAddress][_tokenId][_nftSeller].buyNowPrice = 0;
        nftContractAuctions[_nftContractAddress][_tokenId][_nftSeller].amountSupply = 0;
        nftContractAuctions[_nftContractAddress][_tokenId][_nftSeller].amount = 0;
        nftContractAuctions[_nftContractAddress][_tokenId][_nftSeller].auctionEnd = 0;
        nftContractAuctions[_nftContractAddress][_tokenId][_nftSeller].nftSeller = address( 0);
        nftContractAuctions[_nftContractAddress][_tokenId][_nftSeller].whitelistedBuyer = address(0);
        nftContractAuctions[_nftContractAddress][_tokenId][_nftSeller].ERC20Token = address( 0 );
        nftContractAuctions[_nftContractAddress][_tokenId][_nftSeller].recipient = address( 0 );
    }

    modifier correctFeeRecipientsAndPercentages(
        uint256 _recipientsLength,
        uint256 _percentagesLength
    ) {
        require(
            _recipientsLength == _percentagesLength,
            "mismatched fee recipients and percentages"
        );
        _;
    }

    modifier isFeePercentagesLessThanMaximum(uint32[] memory _feePercentages) {
        uint32 totalPercent;
        for (uint256 i = 0; i < _feePercentages.length; i++) {
            totalPercent = totalPercent + _feePercentages[i];
        }
        require(totalPercent <= 10000, "fee percentages exceed maximum");
        _;
    }

    modifier onSale(address _nftContractAddress, uint256 _tokenId) {
         require(
                0 !=
                nftContractAuctions[_nftContractAddress][_tokenId][msg.sender].amount,
            "No sale"
        );
        _;
    }

     /********************************************************************
     * Allows for a standard sale mechanism where the NFT seller can    *
     * can select an address to be whitelisted. This address is then    *
     * allowed to make a bid on the NFT. No other address can bid on    *
     * the NFT.                                                         *
     ********************************************************************/

    function _setupSale(
        address _nftContractAddress,
        uint256 _tokenId,
        uint256 _amount,
        uint256 _buyNowPrice,
        address _recipient
    )
        internal
        correctFeeRecipientsAndPercentages(
            feeRecipients.length,
            feePercentages.length
        )
        isFeePercentagesLessThanMaximum(feePercentages)
    {
        nftContractAuctions[_nftContractAddress][_tokenId][msg.sender]
            .nftSeller = msg.sender;
        nftContractAuctions[_nftContractAddress][_tokenId][msg.sender]
            .amount = _amount;
         nftContractAuctions[_nftContractAddress][_tokenId][msg.sender]
            .amountSupply = _amount;
        nftContractAuctions[_nftContractAddress][_tokenId][msg.sender]
            .buyNowPrice = _buyNowPrice;
        nftContractAuctions[_nftContractAddress][_tokenId][msg.sender]
            .recipient = _recipient;
    }
    
     function setFee(address[] memory _feeRecipients,uint32[] memory _feePercentages)  onlyOwner external {
        if(_feeRecipients.length!=0) feeRecipients = _feeRecipients;
        if(_feePercentages.length!=0) feePercentages = _feePercentages;
    }

     receive() external payable {}

    function _transferEth(address _to, uint256 _amount) internal {
        (bool success, ) = _to.call{value: _amount}('');
        require(success, "_transferEth: Eth transfer failed");
    }

    // Emergency function: In case any ETH get stuck in the contract unintentionally
    // Only owner can retrieve the asset balance to a recipient address
    function rescueETH(address recipient) onlyOwner external {
        _transferEth(recipient, address(this).balance);
    }

    // Emergency function: In case any ERC20 tokens get stuck in the contract unintentionally
    // Only owner can retrieve the asset balance to a recipient address
    function rescueERC20(address asset, address recipient) onlyOwner external { 
        IERC20(asset).transfer(recipient, IERC20(asset).balanceOf(address(this)));
    }

    // Emergency function: In case any ERC721 tokens get stuck in the contract unintentionally
    // Only owner can retrieve the asset balance to a recipient address
    function rescueERC721(address asset, uint256[] calldata ids, address recipient) onlyOwner external {
        for (uint256 i = 0; i < ids.length; i++) {
            IERC721(asset).transferFrom(address(this), recipient, ids[i]);
        }
    }

    // Emergency function: In case any ERC1155 tokens get stuck in the contract unintentionally
    // Only owner can retrieve the asset balance to a recipient address
    function rescueERC1155(address asset, uint256[] calldata ids, uint256[] calldata amounts, address recipient) onlyOwner external {
        for (uint256 i = 0; i < ids.length; i++) {
            IERC1155(asset).safeTransferFrom(address(this), recipient, ids[i], amounts[i], "");
        }
    }

}

