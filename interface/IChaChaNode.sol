// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

interface IChaChaNode{
     function getMultiplierForNode(uint256 _from, uint256 _to)
        external
        view
        returns (uint256);
}