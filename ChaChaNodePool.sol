// SPDX-License-Identifier: GPL-2.0-or-later

import './interface/IPool.sol';
import './interface/IChaChaNodePool.sol';
import './interface/IChaChaDao.sol';
import './interface/IChaCha.sol';
import './interface/IERC20.sol';
import './libraries/TransferHelper.sol';

contract ChaChaNodePool is IPool,IChaChaNodePool{

    address private daoAddress;

    address private chachaToken;

    uint256 private playFee;

    event Claim(address indexed user,  uint256 amount);

    constructor(address _daoAddress,address _chachaToken){
        daoAddress = _daoAddress;
        chachaToken = _chachaToken;
    }
    
    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyMinter() {
        require(IChaChaDao(daoAddress).isMinter(msg.sender), "Ownable: caller is not the MinterAddress");
        _;
    }

    function setFee(uint256 fee) external override returns (bool){
        require(msg.sender == daoAddress, "Ownable: caller is not the DaoAddress");
        playFee = fee;
        return true;
    }

    function mint(address account, uint256 amount)
        external
        override
        onlyMinter
        returns (bool){
            if(IERC20(chachaToken).balanceOf(address(this)) < amount){
                IChaCha(chachaToken).mint();
            }
        require(IERC20(chachaToken).balanceOf(address(this)) >= amount, "NFT mint may be end");
        TransferHelper.safeTransfer(chachaToken, account, amount);
        return true;
    }

    function burn(address account, uint256 amount)
        external
        onlyMinter
        returns (bool){
            if(IERC20(chachaToken).balanceOf(address(this)) < amount){
                IChaCha(chachaToken).mint();
            }
        require(IERC20(chachaToken).balanceOf(address(this)) >= amount, "Burn error");
        TransferHelper.safeTransfer(chachaToken, account, amount);

        return true;

    }

    function claim() payable
        external
        returns (bool){
        require(msg.value >= playFee);
        emit Claim(msg.sender, playFee);
        return true;
    }
}