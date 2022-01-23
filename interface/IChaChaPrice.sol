// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

interface IChaChaPrice{
    function getPublicSalePrice()
        external
        view
        returns (uint256);

    function maxSupply()
        external
        view
        returns (uint256);
}