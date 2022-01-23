// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import './interface/IChaChaSwitch.sol';
import './interface/IChaChaDao.sol';
import './interface/IChaChaNodePool.sol';
import './libraries/Owned.sol';

contract ChachaDao is IChaChaDao,IChaChaSwitch,IChaChaNodePool,Owned{
    uint256 private _lpRate = 1000;
    uint256 private _nodeRate = 5000;
    uint256 private _nftRate = 2000;
    uint256 private _protocolRate = 2000;

    address private _chachaToken;

    address private _lpPool;

    address private _nftPool;

    address private _nodePool;

    address private _protocolAddress;

    address private _boxAddress;

    mapping (address => bool) private minter;

    function getChaCha()
        external
        view
        override
        returns (address)
    {
        return _chachaToken;
    }

    function isPool(address pool) external view override returns(bool){
        return _protocolAddress == pool || _nodePool == pool || _nftPool == pool || _lpPool == pool;
    }

    function isMinter(address minterAddress) external view override returns(bool){
        return minter[minterAddress];
    }

    function lpPool() external view override returns(address){
        return _lpPool;
    }

    function lpRate() external view override returns (uint256){
        return _lpRate;
    }

    function nftPool() external view override returns(address){
        return _nftPool;
    }

    function nftRate() external view override returns (uint256){
        return _nftRate;
    }
    function nodePool() external view override returns(address){
        return _nodePool;
    }

    function nodeRate() external view override returns (uint256){
        return _nodeRate;
    }

    function protocolAddress() external view override returns(address){
        return _protocolAddress;
    }

    function boxAddress() external view override returns(address){
        return _boxAddress;
    }

    function protocolRate() external view override returns (uint256){
        return _protocolRate;
    }
    function setStart() external override onlyOwner returns (uint256){
        IChaChaSwitch(_chachaToken).setStart();
        return block.timestamp;
    }

    function setLpRate(uint256 LpRate) external override onlyOwner returns (uint256){
        _lpRate = LpRate;
        return _lpRate;
    }

    function setNodeRate(uint256 NodeRate) external override onlyOwner returns (uint256){
        _nodeRate = NodeRate;
        return _nodeRate;
    }

    function setNftRate(uint256 NftRate) external override onlyOwner returns (uint256){
        _nftRate = NftRate;
        return _nftRate;
    }

    function setProtocolRate(uint256 ProtocolRate) external override onlyOwner returns (uint256){
        _protocolRate = ProtocolRate;
        return _protocolRate;
    }

    function setMinter(address minterAddress,bool IsMinter) external override onlyOwner returns (bool){
        minter[minterAddress] = IsMinter;
        return IsMinter;
    }

    function setChachaToken(address ChachaToken) external override onlyOwner returns (address){
        _chachaToken = ChachaToken;
        return _chachaToken;
    }

    function setLpPool(address LpPool) external override onlyOwner returns (address){
        _lpPool = LpPool;
        return _lpPool;
    }

    function setNftPool(address NftPool) external override onlyOwner returns (address){
        _nftPool = NftPool;
        return _nftPool;
    }

    function setNodePool(address NodePool) external override onlyOwner returns (address){
        _nodePool = NodePool;
        return _nodePool;
    }

    function setProtocolAddress(address ProtocolAddress) external override onlyOwner returns (address){
        _protocolAddress = ProtocolAddress;
        return _protocolAddress;
    }

    function setBoxAddress(address BoxAddress) external override onlyOwner returns (address){
        _boxAddress = BoxAddress;
        return _boxAddress;
    }
    function setFee(uint256 fee) external override onlyOwner returns (bool){
        require(_nodePool != address(0));
        IChaChaNodePool(_nodePool).setFee(fee);
        return true;
    }
}

