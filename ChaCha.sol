// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import './abstract/ERC20.sol';
import './libraries/Address.sol';
import './libraries/SafeMath.sol';
import './interface/IChaChaDao.sol';
import './interface/IChaCha.sol';

contract ChaCha is ERC20,IChaCha{

    using Address for address;
    using SafeMath for uint256;

    address private _daoAddress;

    uint256 private _maxSupply;

    uint256 public startMintTime;

    uint256 public firstYearMinted = 50 * 10 ** 8 * 10 ** 18;

    uint256 public decreaseRate = 10;

    uint256 public constant YEAR_SECONDS = 365*24*60*60;

    uint256 public lastMintTime;


    constructor(address daoAddress) public ERC20("CHACHA GAME", "CHACHA") {
        _maxSupply = 275 * 10 ** 8 * 10 ** 18;
        _daoAddress = daoAddress;
    }
    

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyDao() {
        require(_daoAddress == _msgSender(), "Ownable: caller is not the daoAddress");
        _;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyPool() {
        require(IChaChaDao(_daoAddress).isPool(_msgSender()), "Ownable: caller is not the PoolAddress");
        _;
    }
    function mint(address account, uint256 amount) internal {
        require(startMintTime != 0,"mint not started");
        super._mint(account,amount);
    }
    function availableQuantity() external view returns(uint256){
        uint256 timeInterval = block.timestamp.sub(startMintTime);
        uint256 yearIndex = timeInterval.div(YEAR_SECONDS);
        if (yearIndex < 1) {
            return firstYearMinted.mul(timeInterval).div(YEAR_SECONDS);
        } else {
            uint256 availableTotalMint = firstYearMinted;
            uint256 availableIndex = firstYearMinted;
            timeInterval -= (YEAR_SECONDS);
            yearIndex --;
            for(uint256 i = 0; i < yearIndex; i++){
                availableIndex -= firstYearMinted.mul(decreaseRate).div(100);
                availableTotalMint += availableIndex;
                timeInterval -= (YEAR_SECONDS);
            }

            availableIndex -= firstYearMinted.mul(decreaseRate).div(100);

            availableTotalMint += availableIndex.mul(timeInterval).div(YEAR_SECONDS);
            if(availableTotalMint > totalSupply()){
                return totalSupply();
            }
            return availableTotalMint;
        } 
    }
    function availableQuantity(uint256 time) external view returns(uint256){
        if(time < startMintTime){
            return 0;
        }
        uint256 timeInterval = time.sub(startMintTime);
        uint256 yearIndex = timeInterval.div(YEAR_SECONDS);
        if (yearIndex < 1) {
            return firstYearMinted.mul(timeInterval).div(YEAR_SECONDS);
        } else {
            uint256 availableTotalMint = firstYearMinted;
            uint256 availableIndex = firstYearMinted;
            timeInterval -= (YEAR_SECONDS);
            yearIndex --;
            for(uint256 i = 0; i < yearIndex; i++){
                availableIndex -= firstYearMinted.mul(decreaseRate).div(100);
                availableTotalMint += availableIndex;
                timeInterval -= (YEAR_SECONDS);
            }

            availableIndex -= firstYearMinted.mul(decreaseRate).div(100);

            availableTotalMint += availableIndex.mul(timeInterval).div(YEAR_SECONDS);
            if(availableTotalMint > totalSupply()){
                return totalSupply();
            }
            return availableTotalMint;
        } 
    }
     // Return reward multiplier over the given _from to _to block.
    function getMultiplierForLp(uint256 _from, uint256 _to)
        external
        view
        override
        returns (uint256)
    {
        require(_from < _to);
        uint256 amountForm = this.availableQuantity(_from);
        uint256 amountTo = this.availableQuantity(_to);
        return
            (amountTo.sub(amountForm)).mul(IChaChaDao(_daoAddress).lpRate()).div(10000);
    }
    function getMultiplierForNode(uint256 _from, uint256 _to)
        external
        view
        override
        returns (uint256)
    {
        require(_from < _to);
        uint256 amountForm = this.availableQuantity(_from);
        uint256 amountTo = this.availableQuantity(_to);
        return
            (amountTo.sub(amountForm)).mul(IChaChaDao(_daoAddress).nodeRate()).div(10000);
    }

    function getMultiplierForNFT(uint256 _from, uint256 _to)
        external
        view
        override
        returns (uint256)
    {
        require(_from < _to);
        uint256 amountForm = this.availableQuantity(_from);
        uint256 amountTo = this.availableQuantity(_to);
        return
            (amountTo.sub(amountForm)).mul(IChaChaDao(_daoAddress).nftRate()).div(10000);
    }

    function mint()
        public
        override
        onlyPool
        returns (bool)
    {   
        uint256 amount = this.availableQuantity().sub(this.availableQuantity(lastMintTime));
        uint256 amountLp = amount.mul(IChaChaDao(_daoAddress).lpRate()).div(10000);
        uint256 amountNft = amount.mul(IChaChaDao(_daoAddress).nftRate()).div(10000);
        uint256 amountNode = amount.mul(IChaChaDao(_daoAddress).nodeRate()).div(10000);
        uint256 amountProtocol = amount.sub(amountLp).sub(amountNft).sub(amountNode);
        mint(IChaChaDao(_daoAddress).lpPool(),amountLp);
        mint(IChaChaDao(_daoAddress).nftPool(),amountNft);
        mint(IChaChaDao(_daoAddress).nodePool(),amountNode);
        mint(IChaChaDao(_daoAddress).protocolAddress(),amountProtocol);
        lastMintTime = block.timestamp;
        return true;
    }
    

    function setStart()
        public
        override
        onlyDao
        returns (uint256)
    {
        startMintTime = block.timestamp;
        lastMintTime = startMintTime;
        return startMintTime;
    }
}