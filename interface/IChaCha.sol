// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import './IChaChaLP.sol'; 
import './IChaChaNFT.sol'; 
import './IChaChaNode.sol';
import './IChaChaSwitch.sol';

interface IChaCha is IChaChaLP,IChaChaNFT,IChaChaNode,IChaChaSwitch{
     function mint()
        external
        returns (bool);
}