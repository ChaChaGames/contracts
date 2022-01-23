// SPDX-License-Identifier: GPL-2.0-or-later

import './interface/IERC20.sol';
import './interface/IOracle.sol';
import './libraries/Owned.sol';

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract Oracle is Owned,IOracle{

    using SafeMath for uint256;

    address public chacha_bnb_lp;

    address public chacha_busd_lp;

    address public bnb_busd_lp;

    address public chachaToken;

    address public wbnbToken;

    address public busdToken;

    function setchacha_bnb_lp(
        address _chacha_bnb_lp
    ) public onlyOwner {
        chacha_bnb_lp = _chacha_bnb_lp;
    }

    function setchacha_busd_lp(
        address _chacha_busd_lp
    ) public onlyOwner {
        chacha_busd_lp = _chacha_busd_lp;
    }

    function setbnb_busd_lp(
        address _bnb_busd_lp
    ) public onlyOwner {
        bnb_busd_lp = _bnb_busd_lp;
    }

    function setchachaToken(
        address _chachaToken
    ) public onlyOwner {
        chachaToken = _chachaToken;
    }

    function setwbnbToken(
        address _wbnbToken
    ) public onlyOwner {
        wbnbToken = _wbnbToken;
    }

    function setbusdToken(
        address _busdToken
    ) public onlyOwner {
        busdToken = _busdToken;
    }

    function getChaChaPrice() public override view returns(uint256){
        if(chacha_busd_lp != address(0)){
            return chachaPriceByChaChaBusd();
        }
        if(chacha_bnb_lp != address(0) && bnb_busd_lp != address(0)){
            return chachaPriceByChaChaBnb().mul(bnbPriceByBnbBusd());
        }
        return 1;
    }

    function chachaPriceByChaChaBusd() internal view returns(uint256){
        uint256 chachaBalance = IERC20(chachaToken).balanceOf(chacha_busd_lp);
        uint256 busdBalance = IERC20(busdToken).balanceOf(chacha_busd_lp);

        uint8 chachaDec = IERC20(chachaToken).decimals();
        uint8 busdDec = IERC20(busdToken).decimals();

        return busdBalance.div(10 ** busdDec).div(chachaBalance.div(10 ** chachaDec));
    }

    function chachaPriceByChaChaBnb() internal view returns(uint256){
        uint256 chachaBalance = IERC20(chachaToken).balanceOf(chacha_bnb_lp);
        uint256 wbnbBalance = IERC20(wbnbToken).balanceOf(chacha_bnb_lp);

        uint8 chachaDec = IERC20(chachaToken).decimals();
        uint8 wbnbDec = IERC20(wbnbToken).decimals();

        return wbnbBalance.div(10 ** wbnbDec).div(chachaBalance.div(10 ** chachaDec));
    }

    function bnbPriceByBnbBusd() internal view returns(uint256){
        uint256 busdBalance = IERC20(busdToken).balanceOf(bnb_busd_lp);
        uint256 bnbBalance = IERC20(wbnbToken).balanceOf(bnb_busd_lp);

        uint8 busdDec = IERC20(busdToken).decimals();
        uint8 bnbDec = IERC20(wbnbToken).decimals();

        return busdBalance.div(10 ** busdDec).div(bnbBalance.div(10 ** bnbDec));
    }

    
}