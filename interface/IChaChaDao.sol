// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.7.6;

interface IChaChaDao {
    function getChaCha() external view returns (address);
    function lpRate() external view returns (uint256);
    function nftRate() external view returns (uint256);
    function nodeRate() external view returns (uint256);
    function protocolRate() external view returns (uint256);
    function lpPool() external view returns(address);
    function nftPool() external view returns(address);
    function nodePool() external view returns(address);
    function protocolAddress() external view returns(address);
    function boxAddress() external view returns(address);
    function isPool(address pool) external view returns(bool);
    function isMinter(address minter) external view returns(bool);
    function setMinter(address minter,bool isMinter) external  returns(bool);
    function setLpRate(uint256 lpRate) external returns (uint256);
    function setNodeRate(uint256 nodeRate) external returns (uint256);
    function setNftRate(uint256 nftRate) external returns (uint256);
    function setProtocolRate(uint256 protocolRate) external returns (uint256);
    function setChachaToken(address chachaToken) external returns (address);
    function setLpPool(address lpPool) external returns (address);
    function setNftPool(address nftPool) external returns (address);
    function setNodePool(address nodePool) external returns (address);
    function setProtocolAddress(address protocolAddress) external returns (address);
    function setBoxAddress(address boxAddress) external returns (address);

}