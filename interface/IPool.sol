// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.7.6;

interface IPool{
     function mint(address account, uint256 amount)
        external
        returns (bool);
}