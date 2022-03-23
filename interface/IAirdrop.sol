// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;
interface IAirdrop {
    function airdrop(address receiveAddr,uint256 amount) external returns (uint256);
}