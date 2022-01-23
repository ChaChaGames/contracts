// SPDX-License-Identifier: GPL-2.0-or-later



pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ChaChaNode is  Ownable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;
    using Address for address payable;
    using SafeERC20 for IERC20;
    
    uint256 public lastId = 1;
    address public payToken = 0x0000000000000000000000000000000000001000;
    uint256 public initialSalePrice = 5000 ether;
    uint256 public increasePrice = 50 ether;
    uint256 public increaseAmount = 100;
    uint256 public maxSupply = 50000;
    uint256 public totalPublicSale = 0;
    uint256 public batchAmount = 100;
    bool public publicSaleActivated = false;
    bool public paymentTokenActivated = true;
    address[] public tokenRecipients = [0x0000000000000000000000000000000000001000];
    
    uint256 public walletIndex = 0;
    mapping(address => Node) public node;
    mapping(uint256 => address) public idToAddress;
    
    event BuyNode(
        address indexed addr,
        uint256 index,
        uint256 buyPrice,
        uint256 amount,
        uint256 buyTime,
        uint256 userId,  
        address payToken
    );

    struct Node {
        address addr;
        uint256 index;
        uint256 buyPrice;
        uint256 buyTime;
    }

    constructor() {
        
    }

    /**
    @dev setAddress
     */
    function setAddress(address _payToken) public onlyOwner {
        if(_payToken!=address(0)) payToken = _payToken;
    }


   /**
    @dev setMaxSupply
     */
    function setMaxSupply(uint256 _maxSupply) public onlyOwner {
        maxSupply = _maxSupply;
    }
    

    /**
    @dev setIncreasePrice
     */
    function setIncreasePrice(uint256 _increasePrice) public onlyOwner {
        increasePrice = _increasePrice;
    }


    /**
    @dev setIncreaseAmount
     */
    function setIncreaseAmount(uint256 _increaseAmount) public onlyOwner {
        increaseAmount = _increaseAmount;
    }

    /**
    @dev setTotalPublicSale
     */
    function setTotalPublicSale(uint256 _totalPublicSale) public onlyOwner {
        totalPublicSale = _totalPublicSale;
    }

    /**
    @dev setBatchAmount
     */
    function setBatchAmount(uint256 _batchAmount) public onlyOwner {
        batchAmount = _batchAmount;
    }


    function setPublicSaleActivated(bool saleActivated) external onlyOwner {
        publicSaleActivated = saleActivated;
    }

    function setPaymentTokenActivated(bool tokenActivated) external onlyOwner {
        paymentTokenActivated = tokenActivated;
    }

    function setTokenRecipients(address[] memory _tokenRecipients,uint256 _walletIndex)  onlyOwner external {
        tokenRecipients = _tokenRecipients;
        walletIndex = _walletIndex;
    }
    
    /**
    @dev Give current price  
     */
    function getPublicSalePrice()
        public
        view
        returns (uint256)
    {
        return getPublicSalePriceFor(totalPublicSale.add(1));
    }
    
    /**
    @dev Give sale price 
     */
    function getPublicSalePriceFor(uint256 amount)
        public
        view
        returns (uint256)
    {
        if(amount==0){
            return  initialSalePrice;
        }else{
            uint256 diffIncrease = amount.sub(1).div(increaseAmount);
            return initialSalePrice.add(diffIncrease.mul(increasePrice));
        }
    }
    
    function buyNode(uint256 userId,uint256 _limitPrice) external payable {
        require(publicSaleActivated, "Public sale is not active.");
        require(totalPublicSale.add(1) <= maxSupply, "Exceed the upper limit.");
        require(node[msg.sender].addr==address(0), "Already  node.");
        require((_limitPrice==0||_limitPrice>=getPublicSalePrice()), "Exceed the limit price.");
        
        if(paymentTokenActivated){
            require(IERC20(payToken).balanceOf(msg.sender) >= getPublicSalePrice(),"Insufficient amount.");
            IERC20(payToken).transferFrom(msg.sender,address(this),getPublicSalePriceFor(totalPublicSale.add(1)));
        }else{
            require(msg.value >= getPublicSalePrice(), "Insufficient amount.");
        }

        node[msg.sender]  =  Node(msg.sender,totalPublicSale.add(1),getPublicSalePrice(),block.timestamp);
        totalPublicSale = totalPublicSale.add(1);

        if(totalPublicSale.mod(batchAmount)==0&&tokenRecipients.length>0){
            IERC20(payToken).transfer(tokenRecipients[walletIndex], IERC20(payToken).balanceOf(address(this)));
            walletIndex = walletIndex.add(1);
            if(walletIndex>=tokenRecipients.length){
                walletIndex = 0;
            }
        }
        
        idToAddress[lastId] = msg.sender;
        lastId += 1;

        emit BuyNode(msg.sender,totalPublicSale,node[msg.sender].buyPrice,1,block.timestamp,userId,payToken);
    }
        
    receive() external payable {}
    
    function _transferEth(address _to, uint256 _amount) internal {
        (bool success, ) = _to.call{value: _amount}('');
        require(success, "_transferEth: Eth transfer failed");
    }

    // Emergency function: In case any ETH get stuck in the contract unintentionally
    // Only owner can retrieve the asset balance to a recipient address
    function rescueETH(address to) onlyOwner external {
        _transferEth(to, address(this).balance);
    }

    // Emergency function: In case any ERC20 tokens get stuck in the contract unintentionally
    // Only owner can retrieve the asset balance to a recipient address
    function rescueERC20(address asset,address to) onlyOwner external { 
        IERC20(asset).transfer(to, IERC20(asset).balanceOf(address(this)));
    }
}