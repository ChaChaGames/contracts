// SPDX-License-Identifier: GPL-2.0-or-later



pragma solidity ^0.8.0;
interface INFTInitialize {
    function initialize(string memory name,string memory symbol,uint256 initSupply,uint256 maxSupply,string memory baseURI,string[] memory  intNames,uint256[] memory minValues,uint256[] memory maxValues ,string[] memory stringNames,string[]  memory values,uint256 ercType,address nftAddress) external;
}
