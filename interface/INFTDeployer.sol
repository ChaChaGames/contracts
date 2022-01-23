// SPDX-License-Identifier: GPL-2.0-or-later



pragma solidity ^0.8.0;
interface INFTDeployer {
    
    function parameters()
        external
        view
        returns (
            uint256 gameId,
            string memory name,
            string memory symbol,
            uint256 maxSupply,
            string memory baseURI,
            string[] memory intNames,
            uint256[] memory minValues,
            uint256[] memory maxValues,
            string[] memory stringNames,
            string[] memory values,
            uint256  ercType
        );
}