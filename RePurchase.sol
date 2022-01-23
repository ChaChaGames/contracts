// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interface/chachaswapv2/IChaChaswapV2Factory.sol";
import "./interface/chachaswapv2/IChaChaswapV2Pair.sol";
import "./interface/chachaswapv2/IChaChaswapV2Router02.sol";


contract RePurchase is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IChaChaswapV2Router02 public chachaswapV2Router;
    address public uniswapV2Pair;
    address public wbnb;
    uint256 public maxTxPercent = 80;
    uint256 public minTxAmount = 100 * 10**18;

    bool public inSwap;
    bool public swapEnabled;

    address public rePurchaseToken = 0x0000000000000000000000000000000000001000;
    address public burnAddress = 0x0000000000000000000000000000000000001000;
    address public fund = 0x0000000000000000000000000000000000001000;

    event RePurchaseBurn(
        address indexed sellToken,
        address burnToken,
        uint256 sellTokenAmout
    );

    event Burn(
        address indexed burnToken,
        uint256 tokenAmout
    );

    modifier lockTheSwap {
        inSwap = true;
        _;
        inSwap = false;
    }

    event SwapEnabledUpdated(bool enabled);

    constructor(address _chachaswapV2Router ){
        
        chachaswapV2Router = IChaChaswapV2Router02(_chachaswapV2Router);
        wbnb = chachaswapV2Router.WETH();
    }
    
    function setMaxTxPercent(uint256 _maxTxPercent) external onlyOwner() {
       maxTxPercent = _maxTxPercent;
    }

    function setMinTxAmount(uint256 _minTxAmount) external onlyOwner() {
       minTxAmount = _minTxAmount;
    }

    function setToken(address _fund) public onlyOwner {
        if(_fund!=address(0)) fund = _fund;
    }


    function setAddress(address _rePurchaseToken,address _fund) public onlyOwner {
       if(_rePurchaseToken!=address(0)) rePurchaseToken = _rePurchaseToken;
       if(_fund!=address(0)) fund = _fund;
    }

    function setSwapEnabled(bool _enabled) public onlyOwner() {
        swapEnabled = _enabled;
        emit SwapEnabledUpdated(_enabled);
    }   

    //to receive BNB from uniswapV2Router when swapping
    receive() external payable {}
    
    function swapTokensForRePurchaseToken(address sellToken) private  lockTheSwap{
        // generate the uniswap pair path of token -> wbnb
        address[] memory path = new address[](2);
        path[0] = sellToken;
        path[1] = rePurchaseToken;

        uint256 sellTokenAmout = IERC20(sellToken).balanceOf(address(this));
        IERC20(sellToken).approve(address(chachaswapV2Router), 9999999999 * 10 **18);

        // make the swap
        chachaswapV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            sellTokenAmout.mul(maxTxPercent).div(100),
            0, // accept any amount of Token
            path,
            burnAddress,
            block.timestamp
        );
        IERC20(sellToken).safeTransfer(fund,  IERC20(sellToken).balanceOf(address(this)));
        emit RePurchaseBurn(sellToken,rePurchaseToken,sellTokenAmout.mul(maxTxPercent).div(100));
    }
    
    function rePurchaseBurn(address sellToken)   external onlyOwner() {
        require(IERC20(sellToken).balanceOf(address(this)) >= minTxAmount, "Balance is less than minTxAmount.");
        swapTokensForRePurchaseToken(sellToken);
    }

    function burn()   external onlyOwner() {
        require(IERC20(rePurchaseToken).balanceOf(address(this)) >= minTxAmount, "Balance is less than minTxAmount.");
        uint256 tokenAmout = IERC20(rePurchaseToken).balanceOf(address(this));

        IERC20(rePurchaseToken).safeTransfer(burnAddress,  tokenAmout.mul(maxTxPercent).div(100));
        IERC20(rePurchaseToken).safeTransfer(fund, IERC20(rePurchaseToken).balanceOf(address(this)));
        emit Burn(rePurchaseToken,tokenAmout.mul(maxTxPercent).div(100));
    }
    
    function _transferEth(address _to, uint256 _amount) internal {
        (bool success, ) = _to.call{value: _amount}('');
        require(success, "_transferEth: Eth transfer failed");
    }

    // Emergency function: In case any ETH get stuck in the contract unintentionally
    // Only owner can retrieve the asset balance to a recipient address
    function rescueETH() onlyOwner external {
        _transferEth(fund, address(this).balance);
    }

    // Emergency function: In case any ERC20 tokens get stuck in the contract unintentionally
    // Only owner can retrieve the asset balance to a recipient address
    function rescueERC20(address asset) onlyOwner external { 
        IERC20(asset).transfer(fund, IERC20(asset).balanceOf(address(this)));
    }
    

}