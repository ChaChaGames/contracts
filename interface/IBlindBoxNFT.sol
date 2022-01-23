// SPDX-License-Identifier: GPL-2.0-or-later




pragma solidity ^0.8.0;
interface IBlindBoxNFT {
    function unBox(address receiveAddr) external;
    function getRandomValue(uint256 min,uint256 max) external view returns (uint256);
    function maxSupply() external view   returns (uint256 );
    function intNames() external view   returns (string[] memory);
    function minValues() external view   returns (uint256[] memory);
    function maxValues() external view   returns (uint256[] memory);
    function stringNames() external view   returns (string[] memory);
    function values() external view   returns (string[] memory);
}
