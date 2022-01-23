// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";


/// @title An Auction Contract for bidding and selling single and batched NFTs
/// @author Avo Labs GmbH
/// @notice This contract can be used for auctioning any NFTs, and accepts any ERC20 token as payment
contract NFTERC1155Auction is ERC1155Holder, Ownable{
    enum MARKETSTATE{CLOSEALL,OPENALL, OPENAUCTION, OPENLIMITORDER }
    enum ORDERTYPE{ AUCTION, LIMITORDER}

    address[] private payTokens = [0x0000000000000000000000000000000000001000];
    address[] public feeRecipients = [0x0000000000000000000000000000000000001000];
    uint32[] public feePercentages = [500];
    
    mapping(address => mapping(uint256 => mapping(address => Auction))) public nftContractAuctions;
    mapping(address => mapping(uint256 => mapping(address => address))) public nftOwner;
    mapping(address => uint256) failedTransferCredits;

    //Each Auction is unique to each NFT (contract + id pairing).
    struct Auction {
        //map token ID to
        uint256 orderType;
        uint256 minPrice;
        uint256 buyNowPrice;
        uint256 amount;
        uint256 auctionBidPeriod; //Increments the length of time the auction is open in which a new bid can be made after each bid.
        uint256 auctionEnd;
        uint256 nftHighestBid;
        uint256 bidIncreasePercentage;
        uint256[] batchTokenIds; // The first token in the batch is used to identify the auction (contract + id pairing).
        uint256[] batchAmounts; 
        uint32[] feePercentages;
        address nftHighestBidder;
        address nftSeller;
        address whitelistedBuyer; //The seller can specify a whitelisted address for a sale (this is effectively a direct sale).
        address nftRecipient; //The bidder can specify a recipient for the NFT if their bid is successful.
        address ERC20Token; // The seller can specify an ERC20 token that can be used to bid or purchase the NFT.
        address[] feeRecipients;
    }

    struct NFT {
        address nftContractAddress;
        uint256 tokenId;
        address nftSellerAddress;
    }

    /*
     * Default values that are used if not specified by the NFT seller.
     */
    uint256 public defaultBidIncreasePercentage;
    uint256 public defaultAuctionBidPeriod;
    uint256 public minimumSettableIncreasePercentage;
    uint256 public maximumMinPricePercentage;
    uint256 public marketState = uint(MARKETSTATE.OPENLIMITORDER);

    /*╔═════════════════════════════╗
      ║           EVENTS            ║
      ╚═════════════════════════════╝*/

    event NftAuctionCreated(
        uint256 orderType,
        address nftContractAddress,
        uint256 tokenId,
        uint256 amount,
        address nftSeller,
        address erc20Token,
        uint256 minPrice,
        uint256 buyNowPrice,
        uint256 auctionBidPeriod,
        uint256 bidIncreasePercentage,
        address[] feeRecipients,
        uint32[] feePercentages
    );

    event NftBatchAuctionCreated(
        uint256 orderType,
        address nftContractAddress,
        uint256 masterTokenId,
        uint256[] batchTokens,
         uint256[] batchAmounts, 
        address nftSeller,
        address erc20Token,
        uint256 minPrice,
        uint256 buyNowPrice,
        uint256 auctionBidPeriod,
        uint256 bidIncreasePercentage,
        address[] feeRecipients,
        uint32[] feePercentages
    );

    event SaleCreated(
        uint256 orderType,
        address nftContractAddress,
        uint256 tokenId,
        uint256 amount,
        address nftSeller,
        address erc20Token,
        uint256 buyNowPrice,
        address whitelistedBuyer,
        address[] feeRecipients,
        uint32[] feePercentages
    );

    event BatchSaleCreated(
        uint256 orderType,
        address nftContractAddress,
        uint256 masterTokenId,
        uint256[] batchTokens,
        uint256[] batchAmounts,
        address nftSeller,
        address erc20Token,
        uint256 buyNowPrice,
        address whitelistedBuyer,
        address[] feeRecipients,
        uint32[] feePercentages
    );

    event BidMade(
        address nftContractAddress,
        uint256 tokenId,
        address nftSellerAddress,
        address bidder,
        uint256 ethAmount,
        address erc20Token,
        uint256 tokenAmount
    );

    event AuctionPeriodUpdated(
        address nftContractAddress,
        uint256 tokenId,
        address nftSellerAddress,
        uint256 auctionEndPeriod
    );

    event NFTTransferredAndSellerPaid(
        address nftContractAddress,
        uint256 tokenId,
        address nftSellerAddress,
        address nftSeller,
        uint256 nftHighestBid,
        address nftHighestBidder,
        address nftRecipient
    );

    event AuctionSettled(
        address nftContractAddress,
        uint256 tokenId,
        address nftSellerAddress,
        address auctionSettler
    );

    event NFTWithdrawn(
        address nftContractAddress,
        uint256 tokenId,
        address nftSeller
    );

    event BidWithdrawn(
        address nftContractAddress,
        uint256 tokenId,
        address highestBidder
    );

    event WhitelistedBuyerUpdated(
        address nftContractAddress,
        uint256 tokenId,
        address nftSellerAddress,
        address newWhitelistedBuyer
    );

    event MinimumPriceUpdated(
        address nftContractAddress,
        uint256 tokenId,
        address nftSellerAddress,
        uint256 newMinPrice
    );

    event BuyNowPriceUpdated(
        address nftContractAddress,
        uint256 tokenId,
        address nftSellerAddress,
        uint256 newBuyNowPrice
    );
    event HighestBidTaken(address nftContractAddress, uint256 tokenId,address nftSellerAddress);
    /**********************************/
    /*╔═════════════════════════════╗
      ║             END             ║
      ║            EVENTS           ║
      ╚═════════════════════════════╝*/
    /**********************************/
    /*╔═════════════════════════════╗
      ║          MODIFIERS          ║
      ╚═════════════════════════════╝*/


    modifier priceGreaterThanZero(uint256 _price) {
        require(_price > 0, "Price cannot be 0");
        _;
    }


    /*
     * The minimum price must be 80% of the buyNowPrice(if set).
     */
    modifier minPriceDoesNotExceedLimit(
        uint256 _buyNowPrice,
        uint256 _minPrice
    ) {
        require(
            _buyNowPrice == 0 ||
                _getPortionOfBid(_buyNowPrice, maximumMinPricePercentage) >=
                _minPrice,
            "Min price cannot exceed 80% of buyNowPrice"
        );
        _;
    }
  
    
    /*
     * NFTs in a batch must contain between 2 and 100 NFTs
     */
    modifier batchWithinLimits(uint256 _batchTokenIdsLength) {
        require(
            _batchTokenIdsLength > 1 && _batchTokenIdsLength <= 100,
            "Number of NFTs not applicable for batch sale/auction"
        );
        _;
    }
    
    modifier notZeroAddress(address _address) {
        require(_address != address(0), "cannot specify 0 address");
        _;
    }

    modifier increasePercentageAboveMinimum(uint256 _bidIncreasePercentage) {
        require(
            _bidIncreasePercentage >= minimumSettableIncreasePercentage,
            "Bid increase percentage must be greater than minimum settable increase percentage"
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

    
    /**********************************/
    /*╔═════════════════════════════╗
      ║             END             ║
      ║          MODIFIERS          ║
      ╚═════════════════════════════╝*/
    /**********************************/
    // constructor
    constructor() {
        defaultBidIncreasePercentage = 1000;
        defaultAuctionBidPeriod = 86400; //1 day
        minimumSettableIncreasePercentage = 500;
        maximumMinPricePercentage = 8000;
    }

    /*╔══════════════════════════════╗
      ║    AUCTION CHECK FUNCTIONS   ║
      ╚══════════════════════════════╝*/


    function _notOnSale(NFT memory _nft)
        internal
        view
    {
        require(
            address(0) ==
                nftContractAuctions[_nft.nftContractAddress][_nft.tokenId][_nft.nftSellerAddress].nftSeller,
            "On sale"
        );
    }

    function _onSale(NFT memory _nft)
        internal
        view
    {
        require(
            address(0) !=
                nftContractAuctions[_nft.nftContractAddress][_nft.tokenId][_nft.nftSellerAddress].nftSeller,
            "No sale"
        );
    }

    function _notNftSeller(NFT memory _nft)
        internal
        view
    {
        require(
            msg.sender !=
                nftContractAuctions[_nft.nftContractAddress][_nft.tokenId][_nft.nftSellerAddress].nftSeller,
            "Owner cannot bid on own NFT"
        );
    }


    
    function _onlyNftSeller(NFT memory _nft)
        internal
        view
    {
         require(
            msg.sender ==
                nftContractAuctions[_nft.nftContractAddress][_nft.tokenId][_nft.nftSellerAddress].nftSeller,
            "Only the owner can call this function"
        );
    }


    /*
     * Payment is accepted if the payment is made in the ERC20 token or ETH specified by the seller.
     * Early bids on NFTs not yet up for auction must be made in ETH.
     */
    function _paymentAccepted(NFT memory _nft,address _erc20Token,uint256 _tokenAmount)
       internal 
       view
     {
        require(
            _isPaymentAccepted(
                _nft,
                _erc20Token,
                _tokenAmount
            ),
            "Bid to be made in quantities of specified token or eth"
        );
    }


    function _isAuctionOver(NFT memory _nft)
       internal 
       view
     {
        require(
            !_isAuctionOngoing(_nft),
            "Auction is not yet over"
        );
    }


    function  payTokensLimits(address _erc20Token) 
        internal 
        view
    {
        bool support = false;
        for (uint256 i = 0; i < payTokens.length; i++) {
            if(payTokens[i] == _erc20Token) {
                support = true;
                break;
            }
        }
        
        require(support==true,
            "This token payment is not currently supported"
        );
    }


    function _isAuctionOngoing(NFT memory _nft)
        internal
        view
        returns (bool)
    {
        uint256 auctionEndTimestamp = nftContractAuctions[_nft.nftContractAddress][_nft.tokenId][_nft.nftSellerAddress].auctionEnd;
        //if the auctionEnd is set to 0, the auction is technically on-going, however
        //the minimum bid price (minPrice) has not yet been met.
        return (auctionEndTimestamp == 0 ||
            block.timestamp < auctionEndTimestamp);
    }

    /*
     * Check if a bid has been made. This is applicable in the early bid scenario
     * to ensure that if an auction is created after an early bid, the auction
     * begins appropriately or is settled if the buy now price is met.
     */
    function _isABidMade(NFT memory _nft)
        internal
        view
        returns (bool)
    {
        return (nftContractAuctions[_nft.nftContractAddress][_nft.tokenId][_nft.nftSellerAddress].nftHighestBid > 0);
    }




    /*
     *if the minPrice is set by the seller, check that the highest bid meets or exceeds that price.
     */
    function _isMinimumBidMade(NFT memory _nft)
        internal
        view
        returns (bool)
    {
        uint256 minPrice = nftContractAuctions[_nft.nftContractAddress][_nft.tokenId][_nft.nftSellerAddress].minPrice;
        return  minPrice > 0 &&   (nftContractAuctions[_nft.nftContractAddress][_nft.tokenId][_nft.nftSellerAddress].nftHighestBid >=   minPrice);
    }

    /*
     * If the buy now price is set by the seller, check that the highest bid meets that price.
     */
    function _isBuyNowPriceMet(NFT memory _nft)
        internal
        view
        returns (bool)
    {
        uint256 buyNowPrice = nftContractAuctions[_nft.nftContractAddress][_nft.tokenId][_nft.nftSellerAddress] .buyNowPrice;
        return 
            buyNowPrice > 0 &&
            nftContractAuctions[_nft.nftContractAddress][_nft.tokenId][_nft.nftSellerAddress].nftHighestBid >=  buyNowPrice;
    }

    /*
     * Check that a bid is applicable for the purchase of the NFT.
     * In the case of a sale: the bid needs to meet the buyNowPrice.
     * In the case of an auction: the bid needs to be a % higher than the previous bid.
     */
    function _doesBidMeetBidRequirements(
        NFT memory _nft,
        uint256 _tokenAmount
    ) internal view returns (bool) {
        uint256 buyNowPrice = nftContractAuctions[_nft.nftContractAddress][_nft.tokenId][_nft.nftSellerAddress].buyNowPrice;
        //if buyNowPrice is met, ignore increase percentage
        if (buyNowPrice > 0 && (msg.value >= buyNowPrice || _tokenAmount >= buyNowPrice)
        ) {
            return true;
        }
        //if the NFT is up for auction, the bid needs to be a % higher than the previous bid
        uint256 bidIncreaseAmount = (nftContractAuctions[_nft.nftContractAddress][_nft.tokenId ][_nft.nftSellerAddress].nftHighestBid *  (10000 +  _getBidIncreasePercentage(_nft))) /  10000;
        return (msg.value >= bidIncreaseAmount ||  _tokenAmount >= bidIncreaseAmount);
    }

    /*
     * An NFT is up for sale if the buyNowPrice is set, but the minPrice is not set.
     * Therefore the only way to conclude the NFT sale is to meet the buyNowPrice.
     */
    function _isASale(NFT memory _nft)
        internal
        view
        returns (bool)
    {
        return (nftContractAuctions[_nft.nftContractAddress][_nft.tokenId][_nft.nftSellerAddress].buyNowPrice >
            0 &&
            nftContractAuctions[_nft.nftContractAddress][_nft.tokenId][_nft.nftSellerAddress].minPrice == 0);
    }

    function _isWhitelistedSale(NFT memory _nft)
        internal
        view
        returns (bool)
    {
        return (nftContractAuctions[_nft.nftContractAddress][_nft.tokenId][_nft.nftSellerAddress]
            .whitelistedBuyer != address(0));
    }

    /*
     * The highest bidder is allowed to purchase the NFT if
     * no whitelisted buyer is set by the NFT seller.
     * Otherwise, the highest bidder must equal the whitelisted buyer.
     */
    function _isHighestBidderAllowedToPurchaseNFT(
       NFT memory _nft
    ) internal view returns (bool) {
        return
            (!_isWhitelistedSale(_nft)) ||
            _isHighestBidderWhitelisted(_nft);
    }

    function _isHighestBidderWhitelisted(
       NFT memory _nft
    ) internal view returns (bool) {
        return (nftContractAuctions[_nft.nftContractAddress][_nft.tokenId][_nft.nftSellerAddress].nftHighestBidder ==  
                nftContractAuctions[_nft.nftContractAddress][_nft.tokenId][_nft.nftSellerAddress].whitelistedBuyer);
    }

    /**
     * Payment is accepted in the following scenarios:
     * (1) Auction already created - can accept ETH or Specified Token
     *  --------> Cannot bid with ETH & an ERC20 Token together in any circumstance<------
     * (2) Auction not created - only ETH accepted (cannot early bid with an ERC20 Token
     * (3) Cannot make a zero bid (no ETH or Token amount)
     */
    function _isPaymentAccepted(
        NFT memory _nft,
        address _bidERC20Token,
        uint256 _tokenAmount
    ) internal view returns (bool) {
        address auctionERC20Token = nftContractAuctions[_nft.nftContractAddress][_nft.tokenId ][_nft.nftSellerAddress].ERC20Token;
        if (_isERC20Auction(auctionERC20Token)) {
            return
                msg.value == 0 &&
                auctionERC20Token == _bidERC20Token && _tokenAmount > 0;
        } else {
            return
                msg.value != 0 && 
                 _bidERC20Token == address(0) && _tokenAmount == 0;
        }
    }
    function _isERC20Auction(address _auctionERC20Token)
        internal
        pure
        returns (bool)
    {   
        return _auctionERC20Token != address(0) ;
    }

    /*
     * Returns the percentage of the total bid (used to calculate fee payments)
     */
    function _getPortionOfBid(uint256 _totalBid, uint256 _percentage)
        internal
        pure
        returns (uint256)
    {
        return (_totalBid * (_percentage)) / 10000;
    }

    /**********************************/
    /*╔══════════════════════════════╗
      ║             END              ║
      ║    AUCTION CHECK FUNCTIONS   ║
      ╚══════════════════════════════╝*/
    /**********************************/
    /*╔══════════════════════════════╗
      ║    DEFAULT GETTER FUNCTIONS  ║
      ╚══════════════════════════════╝*/
    /*****************************************************************
     * These functions check if the applicable auction parameter has *
     * been set by the NFT seller. If not, return the default value. *
     *****************************************************************/

    function _getBidIncreasePercentage(
        NFT memory _nft
    ) internal view returns (uint256) {
        uint256 bidIncreasePercentage = nftContractAuctions[ _nft.nftContractAddress][_nft.tokenId][_nft.nftSellerAddress].bidIncreasePercentage;

        if (bidIncreasePercentage == 0) {
            return defaultBidIncreasePercentage;
        } else {
            return bidIncreasePercentage;
        }
    }

    function _getAuctionBidPeriod(NFT memory _nft)
        internal
        view
        returns (uint256)
    {
        uint256 auctionBidPeriod = nftContractAuctions[_nft.nftContractAddress][_nft.tokenId][_nft.nftSellerAddress].auctionBidPeriod;
        if (auctionBidPeriod == 0) {
            return defaultAuctionBidPeriod;
        } else {
            return auctionBidPeriod;
        }
    }

    /*
     * The default value for the NFT recipient is the highest bidder
     */
    function _getNftRecipient(NFT memory _nft)
        internal
        view
        returns (address)
    {
        address nftRecipient = nftContractAuctions[_nft.nftContractAddress][_nft.tokenId][_nft.nftSellerAddress].nftRecipient;

        if (nftRecipient == address(0)) {
            return    nftContractAuctions[_nft.nftContractAddress][_nft.tokenId][_nft.nftSellerAddress].nftHighestBidder;
        } else {
            return nftRecipient;
        }
    }

    /**********************************/
    /*╔══════════════════════════════╗
      ║             END              ║
      ║    DEFAULT GETTER FUNCTIONS  ║
      ╚══════════════════════════════╝*/
    /**********************************/

    /*╔══════════════════════════════╗
      ║  TRANSFER NFTS TO CONTRACT   ║
      ╚══════════════════════════════╝*/
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

    function _transferNftBatchToAuctionContract(
        address _nftContractAddress,
        uint256[] memory _batchTokenIds,
        uint256[] memory _batchAmounts
    ) internal {

         IERC1155(_nftContractAddress).safeBatchTransferFrom(
                msg.sender,
                address(this),
                _batchTokenIds,
                _batchAmounts,
                "0x0"
        );
        for (uint256 i = 0; i < _batchTokenIds.length; i++) {
            if (i != 0) {
                //Don't set the first one because we set this later as the NFTSeller parameter in the struct
                nftOwner[_nftContractAddress][_batchTokenIds[i]][msg.sender] = msg.sender;
            }
        }
        
        _reverseAndResetPreviousBid(NFT(_nftContractAddress, _batchTokenIds[0],msg.sender));
        nftContractAuctions[_nftContractAddress][_batchTokenIds[0]][msg.sender].batchTokenIds = _batchTokenIds;
        nftContractAuctions[_nftContractAddress][_batchTokenIds[0]][msg.sender].batchAmounts = _batchAmounts;
    }

    /**********************************/
    /*╔══════════════════════════════╗
      ║             END              ║
      ║  TRANSFER NFTS TO CONTRACT   ║
      ╚══════════════════════════════╝*/
    /**********************************/

    /*╔══════════════════════════════╗
      ║       AUCTION CREATION       ║
      ╚══════════════════════════════╝*/

    /**
     * Setup parameters applicable to all auctions and whitelised sales:
     * -> ERC20 Token for payment (if specified by the seller) : _erc20Token
     * -> minimum price : _minPrice
     * -> buy now price : _buyNowPrice
     * -> the nft seller: msg.sender
     * -> The fee recipients & their respective percentages for a sucessful auction/sale
     */
    function _setupAuction(
        address _nftContractAddress,
        uint256 _tokenId,
        uint256 _amount,
        address _erc20Token,
        uint256 _minPrice,
        uint256 _buyNowPrice
    )
        internal
        minPriceDoesNotExceedLimit(_buyNowPrice, _minPrice)
        correctFeeRecipientsAndPercentages(
            feeRecipients.length,
            feePercentages.length
        )
        isFeePercentagesLessThanMaximum(feePercentages)
    {
        _notOnSale(NFT(_nftContractAddress,_tokenId,msg.sender));
        if (_erc20Token != address(0)) {
            nftContractAuctions[_nftContractAddress][_tokenId][msg.sender] .ERC20Token = _erc20Token;
        }
         nftContractAuctions[_nftContractAddress][_tokenId][msg.sender]
            .orderType = uint(ORDERTYPE.AUCTION);
         nftContractAuctions[_nftContractAddress][_tokenId][msg.sender]
            .amount = _amount;
        nftContractAuctions[_nftContractAddress][_tokenId][msg.sender]
            .feeRecipients = feeRecipients;
        nftContractAuctions[_nftContractAddress][_tokenId][msg.sender]
            .feePercentages = feePercentages;
        nftContractAuctions[_nftContractAddress][_tokenId][msg.sender]
            .buyNowPrice = _buyNowPrice;
        nftContractAuctions[_nftContractAddress][_tokenId][msg.sender]
            .minPrice = _minPrice;
        nftContractAuctions[_nftContractAddress][_tokenId][msg.sender]
            .nftSeller = msg.sender;
    }

    function _createNewNftAuction(
        address _nftContractAddress,
        uint256 _tokenId,
        uint256 _amount,
        address _erc20Token,
        uint256 _minPrice,
        uint256 _buyNowPrice
    ) internal {
        // Sending the NFT to this contract
        _transferNftToAuctionContract(_nftContractAddress, _tokenId,_amount);
        _setupAuction(
            _nftContractAddress,
            _tokenId,
            _amount,
            _erc20Token,
            _minPrice,
            _buyNowPrice
        );
        NFT memory nft = NFT(_nftContractAddress, _tokenId,msg.sender);
        emit NftAuctionCreated(
            uint(ORDERTYPE.AUCTION),
            _nftContractAddress,
            _tokenId,
            _amount,
            msg.sender,
            _erc20Token,
            _minPrice,
            _buyNowPrice,
            _getAuctionBidPeriod(nft),
            _getBidIncreasePercentage(nft),
            feeRecipients,
            feePercentages
        );
        _updateOngoingAuction(nft);
    }

    function createNewNftAuction(
        address _nftContractAddress,
        uint256 _tokenId,
        uint256 _amount,
        address _erc20Token,
        uint256 _minPrice,
        uint256 _buyNowPrice,
        uint256 _auctionBidPeriod, //this is the time that the auction lasts until another bid occurs
        uint256 _bidIncreasePercentage
    )
        external
        priceGreaterThanZero(_minPrice)
        increasePercentageAboveMinimum(_bidIncreasePercentage)
    {
        require(marketState != uint(MARKETSTATE.CLOSEALL) && (marketState == uint(MARKETSTATE.OPENALL)||(marketState == uint(MARKETSTATE.OPENAUCTION))), "The market is not open");
        payTokensLimits(_erc20Token);

        nftContractAuctions[_nftContractAddress][_tokenId][msg.sender]
            .auctionBidPeriod = _auctionBidPeriod;
        nftContractAuctions[_nftContractAddress][_tokenId][msg.sender]
            .bidIncreasePercentage = _bidIncreasePercentage;
        _createNewNftAuction(
            _nftContractAddress,
            _tokenId,
            _amount,
            _erc20Token,
            _minPrice,
            _buyNowPrice
        );
    }

    function _createBatchNftAuction(
        address _nftContractAddress,
        uint256[] memory _batchTokenIds,
        uint256[] memory _batchAmounts,
        address _erc20Token,
        uint256 _minPrice,
        uint256 _buyNowPrice
    ) internal {
        _transferNftBatchToAuctionContract(_nftContractAddress, _batchTokenIds,_batchAmounts);
        _setupAuction(
            _nftContractAddress,
            _batchTokenIds[0],
            0,
            _erc20Token,
            _minPrice,
            _buyNowPrice
        );
        NFT memory nft = NFT(_nftContractAddress, _batchTokenIds[0],msg.sender);

        uint256 auctionBidPeriod = _getAuctionBidPeriod(nft);
        uint256 bidIncreasePercentage = _getBidIncreasePercentage(nft);
        emit NftBatchAuctionCreated(
            uint(ORDERTYPE.AUCTION),
            _nftContractAddress,
            _batchTokenIds[0],
            _batchTokenIds,
            _batchAmounts,
            msg.sender,
            _erc20Token,
            _minPrice,
            _buyNowPrice,
            auctionBidPeriod,
            bidIncreasePercentage,
            feeRecipients,
            feePercentages
        );
    }

    /*
     * Create an auction for multiple NFTs in a batch.
     * The first token in the batch is used as the identifier for the auction.
     * Users must be aware of this tokenId when creating a batch auction.
     */
    function createBatchNftAuction(
        address _nftContractAddress,
        uint256[] memory _batchTokenIds,
        uint256[] memory _batchAmounts,
        address _erc20Token,
        uint256 _minPrice,
        uint256 _buyNowPrice,
        uint256 _auctionBidPeriod, //this is the time that the auction lasts until another bid occurs
        uint256 _bidIncreasePercentage
    )
        external
        priceGreaterThanZero(_minPrice)
        batchWithinLimits(_batchTokenIds.length)
        increasePercentageAboveMinimum(_bidIncreasePercentage)
    {
        require(marketState != uint(MARKETSTATE.CLOSEALL) && (marketState == uint(MARKETSTATE.OPENALL)||(marketState == uint(MARKETSTATE.OPENAUCTION))), "The market is not open");
        payTokensLimits(_erc20Token);

        nftContractAuctions[_nftContractAddress][_batchTokenIds[0]][msg.sender]
            .auctionBidPeriod = _auctionBidPeriod;
        nftContractAuctions[_nftContractAddress][_batchTokenIds[0]][msg.sender]
            .bidIncreasePercentage = _bidIncreasePercentage;
        _createBatchNftAuction(
            _nftContractAddress,
            _batchTokenIds,
            _batchAmounts,
            _erc20Token,
            _minPrice,
            _buyNowPrice
        );
    }

    /**********************************/
    /*╔══════════════════════════════╗
      ║             END              ║
      ║       AUCTION CREATION       ║
      ╚══════════════════════════════╝*/
    /**********************************/

    /*╔══════════════════════════════╗
      ║            SALES             ║
      ╚══════════════════════════════╝*/

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
        address _erc20Token,
        uint256 _buyNowPrice,
        address _whitelistedBuyer,
        uint256 _orderType
    )
        internal
        correctFeeRecipientsAndPercentages(
            feeRecipients.length,
            feePercentages.length
        )
        isFeePercentagesLessThanMaximum(feePercentages)
    {
        _notOnSale(NFT(_nftContractAddress,_tokenId,msg.sender));

        if (_erc20Token != address(0)) {
            nftContractAuctions[_nftContractAddress][_tokenId][msg.sender]
                .ERC20Token = _erc20Token;
        }

        nftContractAuctions[_nftContractAddress][_tokenId][msg.sender]
            .orderType =_orderType==0? uint(ORDERTYPE.AUCTION):uint(ORDERTYPE.LIMITORDER);

        nftContractAuctions[_nftContractAddress][_tokenId][msg.sender]
            .amount = _amount;
        nftContractAuctions[_nftContractAddress][_tokenId][msg.sender]
            .feeRecipients = feeRecipients;
        nftContractAuctions[_nftContractAddress][_tokenId][msg.sender]
            .feePercentages = feePercentages;
        nftContractAuctions[_nftContractAddress][_tokenId][msg.sender]
            .buyNowPrice = _buyNowPrice;
        nftContractAuctions[_nftContractAddress][_tokenId][msg.sender]
            .whitelistedBuyer = _whitelistedBuyer;
        nftContractAuctions[_nftContractAddress][_tokenId][msg.sender]
            .nftSeller = msg.sender;
    }

    function createSale(
        address _nftContractAddress,
        uint256 _tokenId,
        uint256 _amount,
        address _erc20Token,
        uint256 _buyNowPrice,
        address _whitelistedBuyer
        
    ) external priceGreaterThanZero(_buyNowPrice) {
        require(marketState != uint(MARKETSTATE.CLOSEALL) && (marketState == uint(MARKETSTATE.OPENALL)||(marketState == uint(MARKETSTATE.OPENAUCTION))), "The market is not open");
        payTokensLimits(_erc20Token);
        
        _transferNftToAuctionContract(_nftContractAddress, _tokenId,_amount);
        //min price = 0
        _setupSale(
            _nftContractAddress,
            _tokenId,
            _amount,
            _erc20Token,
            _buyNowPrice,
            _whitelistedBuyer,
            uint(ORDERTYPE.AUCTION)
        );

        emit SaleCreated(
            uint(ORDERTYPE.AUCTION),
            _nftContractAddress,
            _tokenId,
            _amount,
            msg.sender,
            _erc20Token,
            _buyNowPrice,
            _whitelistedBuyer,
            feeRecipients,
            feePercentages
        );

        NFT memory nft = NFT(_nftContractAddress, _tokenId,msg.sender);
        //check if buyNowPrice is meet and conclude sale, otherwise reverse the early bid
        if (_isABidMade(nft)) {
            if (
                //we only revert the underbid if the seller specifies a different
                //whitelisted buyer to the highest bidder
                _isHighestBidderAllowedToPurchaseNFT(nft)
            ) {
                if (_isBuyNowPriceMet(nft)) {
                    _transferNftAndPaySeller(nft);
                }
            } else {
                _reverseAndResetPreviousBid(nft);
            }
        }
    }

    function createBatchSale(
        address _nftContractAddress,
        uint256[] memory _batchTokenIds,
        uint256[] memory _batchAmounts, 
        address _erc20Token,
        uint256 _buyNowPrice,
        address _whitelistedBuyer
    )
        external
        priceGreaterThanZero(_buyNowPrice)
        batchWithinLimits(_batchTokenIds.length)
    {
        require(marketState != uint(MARKETSTATE.CLOSEALL) && (marketState == uint(MARKETSTATE.OPENALL)||(marketState == uint(MARKETSTATE.OPENAUCTION))), "The market is not open");
        payTokensLimits(_erc20Token);

        _transferNftBatchToAuctionContract(_nftContractAddress, _batchTokenIds,_batchAmounts);
        _setupSale(
            _nftContractAddress,
            _batchTokenIds[0],
            0,
            _erc20Token,
            _buyNowPrice,
            _whitelistedBuyer,
            uint(ORDERTYPE.AUCTION)
        );

        emit BatchSaleCreated(
            uint(ORDERTYPE.AUCTION),
            _nftContractAddress,
            _batchTokenIds[0],
            _batchTokenIds,
            _batchAmounts,
            msg.sender,
            _erc20Token,
            _buyNowPrice,
            _whitelistedBuyer,
            feeRecipients,
            feePercentages
        );
    }

     function createSaleLimitOrder(
        address _nftContractAddress,
        uint256 _tokenId,
        uint256 _amount,
        address _erc20Token,
        uint256 _buyNowPrice,
        address _whitelistedBuyer
        
    ) external priceGreaterThanZero(_buyNowPrice) {
        require(marketState != uint(MARKETSTATE.CLOSEALL) && (marketState == uint(MARKETSTATE.OPENALL)||(marketState == uint(MARKETSTATE.OPENLIMITORDER))), "The market is not open");
        payTokensLimits(_erc20Token);

        _transferNftToAuctionContract(_nftContractAddress, _tokenId,_amount);
        //min price = 0
        _setupSale(
            _nftContractAddress,
            _tokenId,
            _amount,
            _erc20Token,
            _buyNowPrice,
            _whitelistedBuyer,
            uint(ORDERTYPE.LIMITORDER)
        );

        emit SaleCreated(
            uint(ORDERTYPE.LIMITORDER),
            _nftContractAddress,
            _tokenId,
            _amount,
            msg.sender,
            _erc20Token,
            _buyNowPrice,
            _whitelistedBuyer,
            feeRecipients,
            feePercentages
        );

        NFT memory nft = NFT(_nftContractAddress, _tokenId,msg.sender);
        //check if buyNowPrice is meet and conclude sale, otherwise reverse the early bid
        if (_isABidMade(nft)) {
            if (
                //we only revert the underbid if the seller specifies a different
                //whitelisted buyer to the highest bidder
                _isHighestBidderAllowedToPurchaseNFT(nft)
            ) {
                if (_isBuyNowPriceMet(nft)) {
                    _transferNftAndPaySeller(nft);
                }
            } else {
                _reverseAndResetPreviousBid(nft);
            }
        }
    }

    function createBatchSaleLimitOrder(
        address _nftContractAddress,
        uint256[] memory _batchTokenIds,
        uint256[] memory _batchAmounts, 
        address _erc20Token,
        uint256 _buyNowPrice,
        address _whitelistedBuyer
    )
        external
        priceGreaterThanZero(_buyNowPrice)
        batchWithinLimits(_batchTokenIds.length)
    {
        require(marketState != uint(MARKETSTATE.CLOSEALL) && (marketState == uint(MARKETSTATE.OPENALL)||(marketState == uint(MARKETSTATE.OPENLIMITORDER))), "The market is not open");
        payTokensLimits(_erc20Token);

        
        _transferNftBatchToAuctionContract(_nftContractAddress, _batchTokenIds,_batchAmounts);
        _setupSale(
            _nftContractAddress,
            _batchTokenIds[0],
            0,
            _erc20Token,
            _buyNowPrice,
            _whitelistedBuyer,
            uint(ORDERTYPE.LIMITORDER)
        );

        emit BatchSaleCreated(
            uint(ORDERTYPE.LIMITORDER),
            _nftContractAddress,
            _batchTokenIds[0],
            _batchTokenIds,
            _batchAmounts,
            msg.sender,
            _erc20Token,
            _buyNowPrice,
            _whitelistedBuyer,
            feeRecipients,
            feePercentages
        );
    }


    /**********************************/
    /*╔══════════════════════════════╗
      ║             END              ║
      ║            SALES             ║
      ╚══════════════════════════════╝*/
    /**********************************/

    /*╔═════════════════════════════╗
      ║        BID FUNCTIONS        ║
      ╚═════════════════════════════╝*/

    /********************************************************************
     * Make bids with ETH or an ERC20 Token specified by the NFT seller.*
     * Additionally, a buyer can pay the asking price to conclude a sale*
     * of an NFT.                                                      *
     ********************************************************************/

    function _makeBid(
        address _nftContractAddress,
        uint256 _tokenId,
        address _nftSellerAddress,
        address _erc20Token,
        uint256 _tokenAmount
    )
        internal
    {
        if(nftContractAuctions[_nftContractAddress][_tokenId][_nftSellerAddress].orderType == uint(ORDERTYPE.LIMITORDER) &&
        nftContractAuctions[_nftContractAddress][_tokenId][_nftSellerAddress].ERC20Token != address(0)) _tokenAmount = nftContractAuctions[_nftContractAddress][_tokenId][_nftSellerAddress].buyNowPrice;
        
        if(nftContractAuctions[_nftContractAddress][_tokenId][_nftSellerAddress].orderType == uint(ORDERTYPE.LIMITORDER) &&
            nftContractAuctions[_nftContractAddress][_tokenId][_nftSellerAddress].ERC20Token == address(0)) {
              require(
                msg.value>=nftContractAuctions[_nftContractAddress][_tokenId][_nftSellerAddress].buyNowPrice,
                "Insufficient amount"
              );
        }   
        
        NFT memory nft = NFT(_nftContractAddress, _tokenId, _nftSellerAddress);
        _onSale(nft);
        _notNftSeller(nft);
        _paymentAccepted(nft,_erc20Token,_tokenAmount);
        require(
            _doesBidMeetBidRequirements(
                nft,
                _tokenAmount
            ),
            "Not enough funds to bid on NFT"
        );

        _reversePreviousBidAndUpdateHighestBid(
            nft,
            _tokenAmount
        );
        emit BidMade(
            _nftContractAddress,
            _tokenId,
            _nftSellerAddress,
            msg.sender,
            msg.value,
            _erc20Token,
            _tokenAmount
        );
        _updateOngoingAuction(nft);
    }

    function makeBid(
        address _nftContractAddress,
        uint256 _tokenId,
        address _nftSellerAddress,
        address _erc20Token,
        uint256 _tokenAmount
    )
        external
        payable
    {
        NFT memory nft = NFT(_nftContractAddress, _tokenId, _nftSellerAddress);
        require(
            _isAuctionOngoing(nft),
            "Auction has ended"
        );  

        require(
            !_isWhitelistedSale(nft) ||
                nftContractAuctions[nft.nftContractAddress][nft.tokenId][nft.nftSellerAddress]
                    .whitelistedBuyer ==
                msg.sender,
            "only the whitelisted buyer can bid on this NFT"
        );

        _makeBid(_nftContractAddress, _tokenId,_nftSellerAddress, _erc20Token, _tokenAmount);
    }

    function makeCustomBid(
        address _nftContractAddress,
        uint256 _tokenId,
        address _nftSellerAddress,
        address _erc20Token,
        uint256 _tokenAmount,
        address _nftRecipient
    )
        external
        payable
        notZeroAddress(_nftRecipient)
    {
        NFT memory nft = NFT(_nftContractAddress, _tokenId, _nftSellerAddress);
        require(
            _isAuctionOngoing(nft),
            "Auction has ended"
        );  

        require(
            !_isWhitelistedSale(nft) ||
                nftContractAuctions[nft.nftContractAddress][nft.tokenId][nft.nftSellerAddress]
                    .whitelistedBuyer ==
                msg.sender,
            "only the whitelisted buyer can bid on this NFT"
        );

        nftContractAuctions[_nftContractAddress][_tokenId][_nftSellerAddress] .nftRecipient = _nftRecipient;
        _makeBid(_nftContractAddress, _tokenId,_nftSellerAddress, _erc20Token, _tokenAmount);
    }

    /**********************************/
    /*╔══════════════════════════════╗
      ║             END              ║
      ║        BID FUNCTIONS         ║
      ╚══════════════════════════════╝*/
    /**********************************/

    /*╔══════════════════════════════╗
      ║       UPDATE AUCTION         ║
      ╚══════════════════════════════╝*/

    /***************************************************************
     * Settle an auction or sale if the buyNowPrice is met or set  *
     *  auction period to begin if the minimum price has been met. *
     ***************************************************************/
    function _updateOngoingAuction(
       NFT memory _nft
    ) internal {
        if (_isBuyNowPriceMet(_nft)) {
            _transferNftAndPaySeller(_nft);
            return;
        }
        //min price not set, nft not up for auction yet
        if (_isMinimumBidMade(_nft)) {
            _updateAuctionEnd(_nft);
        }
    }

    function _updateAuctionEnd(NFT memory _nft)
        internal
    {
        //the auction end is always set to now + the bid period
        nftContractAuctions[_nft.nftContractAddress][_nft.tokenId][_nft.nftSellerAddress].auctionEnd =
            _getAuctionBidPeriod(_nft) + block.timestamp;
        emit AuctionPeriodUpdated(
            _nft.nftContractAddress,
            _nft.tokenId,
            _nft.nftSellerAddress,
            nftContractAuctions[_nft.nftContractAddress][_nft.tokenId][_nft.nftSellerAddress].auctionEnd
        );
    }

    /**********************************/
    /*╔══════════════════════════════╗
      ║             END              ║
      ║       UPDATE AUCTION         ║
      ╚══════════════════════════════╝*/
    /**********************************/

    /*╔══════════════════════════════╗
      ║       RESET FUNCTIONS        ║
      ╚══════════════════════════════╝*/

    /*
     * Reset all auction related parameters for an NFT.
     * This effectively removes an EFT as an item up for auction
     */
   function _resetAuction(NFT memory _nft)
        internal
    {
        nftContractAuctions[_nft.nftContractAddress][_nft.tokenId][_nft.nftSellerAddress].orderType = 0;
        nftContractAuctions[_nft.nftContractAddress][_nft.tokenId][_nft.nftSellerAddress].minPrice = 0;
        nftContractAuctions[_nft.nftContractAddress][_nft.tokenId][_nft.nftSellerAddress].buyNowPrice = 0;
        nftContractAuctions[_nft.nftContractAddress][_nft.tokenId][_nft.nftSellerAddress].amount = 0;
        nftContractAuctions[_nft.nftContractAddress][_nft.tokenId][_nft.nftSellerAddress].auctionEnd = 0;
        nftContractAuctions[_nft.nftContractAddress][_nft.tokenId][_nft.nftSellerAddress].auctionBidPeriod = 0;
        nftContractAuctions[_nft.nftContractAddress][_nft.tokenId][_nft.nftSellerAddress].bidIncreasePercentage = 0;
        nftContractAuctions[_nft.nftContractAddress][_nft.tokenId][_nft.nftSellerAddress].nftSeller = address( 0);
        nftContractAuctions[_nft.nftContractAddress][_nft.tokenId][_nft.nftSellerAddress].whitelistedBuyer = address(0);
        delete nftContractAuctions[_nft.nftContractAddress][_nft.tokenId][_nft.nftSellerAddress].batchTokenIds;
        delete nftContractAuctions[_nft.nftContractAddress][_nft.tokenId][_nft.nftSellerAddress].batchAmounts;
        nftContractAuctions[_nft.nftContractAddress][_nft.tokenId][_nft.nftSellerAddress].ERC20Token = address( 0 );
    }


    /*
     * Reset all bid related parameters for an NFT.
     * This effectively sets an NFT as having no active bids
     */
    function _resetBids(NFT memory _nft)
        internal
    {
        nftContractAuctions[_nft.nftContractAddress][_nft.tokenId][_nft.nftSellerAddress].nftHighestBidder = address(0);
        nftContractAuctions[_nft.nftContractAddress][_nft.tokenId][_nft.nftSellerAddress].nftHighestBid = 0;
        nftContractAuctions[_nft.nftContractAddress][_nft.tokenId][_nft.nftSellerAddress].nftRecipient = address(0);
    }

    /**********************************/
    /*╔══════════════════════════════╗
      ║             END              ║
      ║       RESET FUNCTIONS        ║
      ╚══════════════════════════════╝*/
    /**********************************/
    
    /*╔══════════════════════════════╗
      ║         UPDATE BIDS          ║
      ╚══════════════════════════════╝*/
    /******************************************************************
     * Internal functions that update bid parameters and reverse bids *
     * to ensure contract only holds the highest bid.                 *
     ******************************************************************/
    function _updateHighestBid(
        NFT memory _nft,
        uint256 _tokenAmount
    ) internal {
        address auctionERC20Token = nftContractAuctions[_nft.nftContractAddress][_nft.tokenId ][_nft.nftSellerAddress].ERC20Token;
        if (_isERC20Auction(auctionERC20Token)) {
            IERC20(auctionERC20Token).transferFrom(
                msg.sender,
                address(this),
                _tokenAmount
            );
            nftContractAuctions[_nft.nftContractAddress][_nft.tokenId][_nft.nftSellerAddress]
                .nftHighestBid = _tokenAmount;
        } else {
            nftContractAuctions[_nft.nftContractAddress][_nft.tokenId][_nft.nftSellerAddress]
                .nftHighestBid = msg.value;
        }
        nftContractAuctions[_nft.nftContractAddress][_nft.tokenId][_nft.nftSellerAddress]
            .nftHighestBidder = msg.sender;
    }

    function _reverseAndResetPreviousBid(
        NFT memory _nft
    ) internal {
        address nftHighestBidder = nftContractAuctions[_nft.nftContractAddress][ _nft.tokenId ][_nft.nftSellerAddress].nftHighestBidder;
        uint256 nftHighestBid = nftContractAuctions[_nft.nftContractAddress][ _nft.tokenId ][_nft.nftSellerAddress].nftHighestBid;
        _resetBids(_nft);

        _payout(_nft, nftHighestBidder, nftHighestBid);
    }

    function _reversePreviousBidAndUpdateHighestBid(
        NFT memory _nft,
        uint256 _tokenAmount
    ) internal {
        address prevNftHighestBidder = nftContractAuctions[_nft.nftContractAddress][_nft.tokenId ][_nft.nftSellerAddress].nftHighestBidder;
        uint256 prevNftHighestBid = nftContractAuctions[_nft.nftContractAddress][_nft.tokenId ][_nft.nftSellerAddress].nftHighestBid;
        _updateHighestBid(_nft, _tokenAmount);

        if (prevNftHighestBidder != address(0)) {
            _payout(
               _nft,
                prevNftHighestBidder,
                prevNftHighestBid
            );
        }
    }

    /**********************************/
    /*╔══════════════════════════════╗
      ║             END              ║
      ║         UPDATE BIDS          ║
      ╚══════════════════════════════╝*/
    /**********************************/

    /*╔══════════════════════════════╗
      ║  TRANSFER NFT & PAY SELLER   ║
      ╚══════════════════════════════╝*/
    function _transferNftAndPaySeller(
       NFT memory _nft
    ) internal {
        address _nftSeller = nftContractAuctions[_nft.nftContractAddress][_nft.tokenId][_nft.nftSellerAddress]  .nftSeller;
        address _nftHighestBidder = nftContractAuctions[_nft.nftContractAddress][_nft.tokenId ][_nft.nftSellerAddress].nftHighestBidder;
        address _nftRecipient = _getNftRecipient(NFT(_nft.nftContractAddress, _nft.tokenId, _nft.nftSellerAddress));
        uint256 _nftHighestBid = nftContractAuctions[_nft.nftContractAddress][_nft.tokenId][_nft.nftSellerAddress].nftHighestBid;
        
        _resetBids(_nft);
        _payFeesAndSeller(
            _nft,
            _nftSeller,
            _nftHighestBid
        );
        //reset bid and transfer nft last to avoid reentrancy
        uint256[] memory batchTokenIds = nftContractAuctions[_nft.nftContractAddress][_nft.tokenId][_nft.nftSellerAddress].batchTokenIds;
        uint256 numberOfTokens = batchTokenIds.length;
        if (numberOfTokens > 0) {
            uint256[] memory batchAmounts = nftContractAuctions[_nft.nftContractAddress][_nft.tokenId][_nft.nftSellerAddress].batchAmounts;
            IERC1155(_nft.nftContractAddress).safeBatchTransferFrom(
                    address(this),
                    _nftRecipient,
                    batchTokenIds,
                    batchAmounts,
                    "0x0"
            );

            for (uint256 i = 0; i < numberOfTokens; i++) {
                nftOwner[_nft.nftContractAddress][batchTokenIds[i]][_nft.nftSellerAddress] = address(0);
            }
        } else {
            uint256 _amount = nftContractAuctions[_nft.nftContractAddress][_nft.tokenId][_nft.nftSellerAddress].amount;
            IERC1155(_nft.nftContractAddress).safeTransferFrom(
                address(this),
                _nftRecipient,
                _nft.tokenId,
                _amount,
                "0x0"
            );

        }
        _resetAuction(_nft);
        emit NFTTransferredAndSellerPaid(
            _nft.nftContractAddress,
            _nft.tokenId,
            _nft.nftSellerAddress,
            _nftSeller,
            _nftHighestBid,
            _nftHighestBidder,
            _nftRecipient
        );
    }

    function _payFeesAndSeller(
        NFT memory _nft,
        address _nftSeller,
        uint256 _highestBid
    ) internal {
        uint256 feesPaid;
        for (
            uint256 i = 0;
            i <
            nftContractAuctions[_nft.nftContractAddress][_nft.tokenId][_nft.nftSellerAddress].feeRecipients.length;
            i++
        ) {
            uint256 fee = _getPortionOfBid(
                _highestBid,
                nftContractAuctions[_nft.nftContractAddress][_nft.tokenId][_nft.nftSellerAddress].feePercentages[i]
            );
            feesPaid = feesPaid + fee;
            _payout(
                _nft,
                nftContractAuctions[_nft.nftContractAddress][_nft.tokenId][_nft.nftSellerAddress].feeRecipients[i],
                fee
            );
        }
        _payout(
            _nft,
            _nftSeller,
            (_highestBid - feesPaid)
        );
    }

    function _payout(
        NFT memory _nft,
        address _recipient,
        uint256 _amount
    ) internal {
        address auctionERC20Token = nftContractAuctions[_nft.nftContractAddress][_nft.tokenId][_nft.nftSellerAddress].ERC20Token;
        if (_isERC20Auction(auctionERC20Token)) {
            IERC20(auctionERC20Token).transfer(_recipient, _amount);
        } else {
            // attempt to send the funds to the recipient
            (bool success, ) = payable(_recipient).call{value: _amount}("");
            // if it failed, update their credit balance so they can pull it later
            if (!success) {
                failedTransferCredits[_recipient] =
                    failedTransferCredits[_recipient] +
                    _amount;
            }
        }
    }

    /**********************************/
    /*╔══════════════════════════════╗
      ║             END              ║
      ║  TRANSFER NFT & PAY SELLER   ║
      ╚══════════════════════════════╝*/
    /**********************************/

    /*╔══════════════════════════════╗
      ║      SETTLE & WITHDRAW       ║
      ╚══════════════════════════════╝*/
    function settleAuction(address _nftContractAddress, uint256 _tokenId,address _nftSellerAddress)
        external
    {
        _isAuctionOver(NFT(_nftContractAddress, _tokenId, _nftSellerAddress));
        _transferNftAndPaySeller(NFT(_nftContractAddress, _tokenId , _nftSellerAddress));
        emit AuctionSettled(_nftContractAddress, _tokenId,_nftSellerAddress, msg.sender);
    }

    function withdrawNft(address _nftContractAddress, uint256 _tokenId)
        external
    {
         NFT memory nft = NFT(_nftContractAddress, _tokenId , msg.sender);
        _onlyNftSeller(nft);
        require(!_isMinimumBidMade(nft), "The auction has a valid bid made" );

        uint256[] memory batchTokenIds = nftContractAuctions[ _nftContractAddress ][_tokenId][msg.sender].batchTokenIds;
        uint256 numberOfTokens = batchTokenIds.length;
        if (numberOfTokens > 0) {
            uint256[] memory batchAmounts = nftContractAuctions[ _nftContractAddress ][_tokenId][msg.sender].batchAmounts;
            IERC1155(_nftContractAddress).safeBatchTransferFrom(
                address(this),
                nftContractAuctions[_nftContractAddress][_tokenId][msg.sender].nftSeller,
                batchTokenIds,
                batchAmounts,
                "0x0"
            );

        } else {
           uint256 _amount = nftContractAuctions[ _nftContractAddress ][_tokenId][msg.sender].amount;
            IERC1155(_nftContractAddress).safeTransferFrom(
                address(this),
                nftContractAuctions[_nftContractAddress][_tokenId][msg.sender].nftSeller,
                _tokenId,
                _amount,
                "0x0"
            );

        }
        _resetAuction(nft);
        emit NFTWithdrawn(_nftContractAddress, _tokenId, msg.sender);
    }

    function withdrawBid(address _nftContractAddress, uint256 _tokenId,address _nftSellerAddress)
        external
    {
        NFT memory nft = NFT(_nftContractAddress, _tokenId , _nftSellerAddress);
        require(!_isMinimumBidMade(nft), "The auction has a valid bid made" );
        
        address nftHighestBidder = nftContractAuctions[_nftContractAddress][_tokenId][_nftSellerAddress].nftHighestBidder;
        require(msg.sender == nftHighestBidder, "Cannot withdraw funds");

        uint256 nftHighestBid = nftContractAuctions[_nftContractAddress][_tokenId][_nftSellerAddress].nftHighestBid;
        _resetBids(nft);
        _payout(nft, nftHighestBidder, nftHighestBid);

        emit BidWithdrawn(_nftContractAddress, _tokenId,msg.sender);
    }
    
    /**********************************/
    /*╔══════════════════════════════╗
      ║             END              ║
      ║      SETTLE & WITHDRAW       ║
      ╚══════════════════════════════╝*/
    /**********************************/

    /*╔══════════════════════════════╗
      ║       UPDATE AUCTION         ║
      ╚══════════════════════════════╝*/
    function updateWhitelistedBuyer(
        address _nftContractAddress,
        uint256 _tokenId,
        address _newWhitelistedBuyer
    ) external {
         NFT memory nft = NFT(_nftContractAddress, _tokenId , msg.sender);
        _onlyNftSeller(nft);

        require(_isASale(nft), "Not a sale");
        nftContractAuctions[_nftContractAddress][_tokenId][msg.sender]
            .whitelistedBuyer = _newWhitelistedBuyer;
        //if an underbid is by a non whitelisted buyer,reverse that bid
        address nftHighestBidder = nftContractAuctions[_nftContractAddress][ _tokenId][msg.sender].nftHighestBidder;
        uint256 nftHighestBid = nftContractAuctions[_nftContractAddress][_tokenId][msg.sender].nftHighestBid;
        if (nftHighestBid > 0 && !(nftHighestBidder == _newWhitelistedBuyer)) {
            //we only revert the underbid if the seller specifies a different
            //whitelisted buyer to the highest bider
            _resetBids(nft);
            _payout(nft,nftHighestBidder,nftHighestBid );
        }

        emit WhitelistedBuyerUpdated(
            _nftContractAddress,
            _tokenId,
            msg.sender,
            _newWhitelistedBuyer
        );
    }

    function updateMinimumPrice(
        address _nftContractAddress,
        uint256 _tokenId,
        uint256 _newMinPrice
    )
        external
        priceGreaterThanZero(_newMinPrice)
        minPriceDoesNotExceedLimit(
            nftContractAuctions[_nftContractAddress][_tokenId][msg.sender].buyNowPrice,
            _newMinPrice
        )
    {
        NFT memory nft = NFT(_nftContractAddress, _tokenId , msg.sender);
        _onlyNftSeller(nft);

        require(!_isMinimumBidMade(nft), "The auction has a valid bid made" );
        require(!_isASale(nft), "Not applicable for a sale");

        nftContractAuctions[_nftContractAddress][_tokenId][msg.sender].minPrice = _newMinPrice;
        emit MinimumPriceUpdated(_nftContractAddress, _tokenId,msg.sender, _newMinPrice);
        if (_isMinimumBidMade(nft)) {
            _updateAuctionEnd(nft);
        }
    }

    function updateBuyNowPrice(
        address _nftContractAddress,
        uint256 _tokenId,
        uint256 _newBuyNowPrice
    )
        external
        priceGreaterThanZero(_newBuyNowPrice)
        minPriceDoesNotExceedLimit(
            _newBuyNowPrice,
            nftContractAuctions[_nftContractAddress][_tokenId][msg.sender].minPrice
        )
    {   
        NFT memory nft = NFT(_nftContractAddress, _tokenId , msg.sender);
        _onlyNftSeller(nft);
        nftContractAuctions[_nftContractAddress][_tokenId][msg.sender].buyNowPrice = _newBuyNowPrice;
        emit BuyNowPriceUpdated(_nftContractAddress, _tokenId,msg.sender, _newBuyNowPrice);
        if (_isBuyNowPriceMet(nft)) {
            _transferNftAndPaySeller(nft);
        }
    }

    /*
     * The NFT seller can opt to end an auction by taking the current highest bid.
     */
    function takeHighestBid(address _nftContractAddress, uint256 _tokenId)
        external
    {
         NFT memory nft = NFT(_nftContractAddress, _tokenId , msg.sender);
        _onlyNftSeller(nft);

        require(
            _isABidMade(nft),
            "cannot payout 0 bid"
        );
        _transferNftAndPaySeller(nft);
        emit HighestBidTaken(_nftContractAddress, _tokenId,msg.sender);
    }

    /*
     * Query the owner of an NFT deposited for auction
     */
    function ownerOfNFT(address _nftContractAddress, uint256 _tokenId,address _nftSellerAddress)
        external
        view
        returns (address)
    {
        address nftSeller = nftContractAuctions[_nftContractAddress][_tokenId][_nftSellerAddress].nftSeller;
        if (nftSeller != address(0)) {
            return nftSeller;
        }
        address ownerAddr = nftOwner[_nftContractAddress][_tokenId][_nftSellerAddress];
        require(ownerAddr != address(0), "NFT not deposited");
        return ownerAddr;
    }

    /*
     * If the transfer of a bid has failed, allow the recipient to reclaim their amount later.
     */
    function withdrawAllFailedCredits() external {
        uint256 amount = failedTransferCredits[msg.sender];

        require(amount != 0, "no credits to withdraw");

        failedTransferCredits[msg.sender] = 0;

        (bool successfulWithdraw, ) = msg.sender.call{value: amount}("");
        require(successfulWithdraw, "withdraw failed");
    }

    /**********************************/
    /*╔══════════════════════════════╗
      ║             END              ║
      ║       UPDATE AUCTION         ║
      ╚══════════════════════════════╝*/
    /**********************************/

    function getPayTokens() external view returns (address[] memory)
    {
        return payTokens;
    }

    function setMarketState(uint256 _marketState)  onlyOwner external {
        marketState = _marketState ;
    }

     function setFee(address[] memory _feeRecipients,uint32[] memory _feePercentages)  onlyOwner external {
        if(_feeRecipients.length!=0) feeRecipients = _feeRecipients;
        if(_feePercentages.length!=0) feePercentages = _feePercentages;
    }

    function setPayTokens(address[] memory _payTokens)  onlyOwner external {
        if(_payTokens.length!=0) payTokens = _payTokens;
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
