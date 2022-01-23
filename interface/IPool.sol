// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

interface IPool{
     function mint(address account, uint256 amount)
        external
        returns (bool);
}