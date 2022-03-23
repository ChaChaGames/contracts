// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.7.6;

interface IChaChaLP{
     function getMultiplierForLp(uint256 _from, uint256 _to)
        external
        view
        returns (uint256);
}