// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.7.6;

import './interface/IPool.sol';
import './interface/IChaChaNodePool.sol';
import './interface/IChaChaDao.sol';
import './interface/IChaCha.sol';
import './interface/IERC20.sol';
import './libraries/TransferHelper.sol';
import "@openzeppelin/contracts/access/Ownable.sol";

contract ChaChaNodePool is IPool,IChaChaNodePool,Ownable{

    address private daoAddress;

    mapping(address => uint256) private claimTime;

    uint256 private startTime = 1645747200;


    address private chachaToken;

    uint256 public fee;

    address public feeAddress;

    event Claim(address indexed user,  uint256 amount);

    event Mint(address indexed user,  uint256 amount);

    event Burn(address indexed user,  uint256 amount);

    event FeeChange(uint256 fee,address  feeAddress);

    constructor(address _daoAddress,address _chachaToken){
        require(_daoAddress != address(0) && _chachaToken != address(0),"daoAddress or chachaToken is not zero address require");
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

    function setFee(uint256 _fee,address _feeAddress) external override returns (bool){
        require(msg.sender == daoAddress, "Ownable: caller is not the DaoAddress");
        fee = _fee;
        feeAddress = _feeAddress;
        emit FeeChange(_fee,_feeAddress);
        return true;
    }



    function mint(address account, uint256 amount)
        external
        override
        onlyMinter
        returns (bool){
            if(IERC20(chachaToken).balanceOf(address(this)) < amount){
                IChaCha(chachaToken).mint(); // CHACHA issue function。 
            }
        require(IERC20(chachaToken).balanceOf(address(this)) >= amount, "NFT mint may be end");
        TransferHelper.safeTransfer(chachaToken, account, amount);
        emit Mint(account,amount);
        return true;
    }

    function burn(uint256 amount)
        external
        onlyMinter
        returns (bool){
            if(IERC20(chachaToken).balanceOf(address(this)) < amount){
                IChaCha(chachaToken).mint();
            }
        require(IERC20(chachaToken).balanceOf(address(this)) >= amount, "Burn error");
        TransferHelper.safeTransfer(chachaToken, address(0), amount);
        emit Burn(address(0),amount);
        return true;

    }

    function claim() payable
        external
        returns (bool){
        require(msg.value >= fee);
        require(fee != 0 && feeAddress != address(0));
        uint256 lastTime = (((block.timestamp - startTime)/ 1 days)) * 1 days + startTime;
        require(claimTime[msg.sender] == 0 || claimTime[msg.sender] <= lastTime);
        claimTime[msg.sender] = block.timestamp;
        TransferHelper.safeTransferETH(feeAddress, msg.value);
        emit Claim(msg.sender,msg.value);
        return true;
    }
    function withdrawETH() public onlyOwner{
        TransferHelper.safeTransferETH(msg.sender, address(this).balance);
    } 
}
