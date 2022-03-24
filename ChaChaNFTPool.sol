// SPDX-License-Identifier: GPL-2.0-or-later

import './interface/IPool.sol';
import './interface/IChaChaDao.sol';
import './interface/IChaCha.sol';
import './interface/IERC20.sol';
import './interface/IOracle.sol';
import './libraries/Owned.sol';
import './libraries/TransferHelper.sol';


import './interface/IChaChaNFT.sol';
import './interface/IChaChaNode.sol';

import './interface/IChaChaPrice.sol';

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract ChaChaNFTPool is IPool,Owned,IERC1155Receiver{

    using SafeMath for uint256;

    address private daoAddress;

    address private chachaToken;

    uint256 public totalAllocPoint = 0;

    address public nodeSaleAddress;

    address public boxSaleAddress;

    address public orcale;

    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC1155 nftToken; // Address of LP token contract.
        uint256 id;
        uint256 allocPoint; // How many allocation points assigned to this pool. SUSHIs to distribute per block.
        uint256 lastRewardTime; // Last block number that SUSHIs distribution occurs.
        uint256 accChaChaPerShare; // Accumulated SUSHIs per share, times 1e12. See below.
        uint256 deadAmount;
    }

       // Info of each pool.
    PoolInfo[] public poolInfo;

    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    bool private isStart;

    uint256 private startTime;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );

    constructor(address _daoAddress,address _chachaToken,uint256 _startTime){
        require(_daoAddress != address(0) && _chachaToken != address(0),"daoAddress or chachaToken is not zero address require");
        daoAddress = _daoAddress;
        chachaToken = _chachaToken;
        startTime = _startTime;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyMinter() {
        require(IChaChaDao(daoAddress).isMinter(msg.sender), "Ownable: caller is not the MinterAddress");
        _;
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

    function setNodeSaleAddress(
        address _nodeSaleAddress
    ) public onlyOwner {
        nodeSaleAddress = _nodeSaleAddress;
    }

    function setOrcale(
        address _orcale
    ) public onlyOwner {
        orcale = _orcale;
    }

    function setBoxSaleAddress(
        address _boxSaleAddress
    ) public onlyOwner {
        boxSaleAddress = _boxSaleAddress;
    }

    function add(
        uint256 _allocPoint,
        IERC1155 _nftToken,
        uint256 _id,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardTime =
            block.timestamp > startTime ? block.timestamp : startTime;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                nftToken: _nftToken,
                id:_id,
                allocPoint: _allocPoint,
                lastRewardTime: lastRewardTime,
                accChaChaPerShare: 0,
                deadAmount:0
            })
        );
    }

     // Update reward vairables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.timestamp <= pool.lastRewardTime) {
            return;
        }
        uint256 lpSupply = pool.nftToken.balanceOf(address(this),pool.id);
        if (lpSupply == 0) {
            pool.lastRewardTime = block.timestamp;
            return;
        }
        uint256 chachaReward = 
            IChaChaNFT(address(chachaToken)).getMultiplierForNFT(pool.lastRewardTime, block.timestamp).mul(pool.allocPoint).div(
                totalAllocPoint
            );
        if(chachaReward.div(lpSupply) >= getMaxReward(pool.lastRewardTime,block.timestamp)){
            pool.accChaChaPerShare = pool.accChaChaPerShare.add(
                getMaxReward(pool.lastRewardTime,block.timestamp).mul(1e12)
            );
            pool.deadAmount += (chachaReward.sub(getMaxReward(pool.lastRewardTime,block.timestamp).mul(lpSupply)));
        }else{
            pool.accChaChaPerShare = pool.accChaChaPerShare.add(
            chachaReward.mul(1e12).div(lpSupply)
            );
        }
        pool.lastRewardTime = block.timestamp;
    }

    function getMaxReward(uint256 from,uint256 to) public view returns(uint256){
        uint256 reward = IChaChaNode(address(chachaToken)).getMultiplierForNode(from,to);

        uint256 maxSupply = IChaChaPrice(nodeSaleAddress).maxSupply();

        uint256 price = IChaChaPrice(nodeSaleAddress).getPublicSalePrice();

        uint256 boxPrice = IChaChaPrice(boxSaleAddress).getPublicSalePrice();

        return reward.mul(60).mul(boxPrice).div(price).div(100).div(maxSupply);
    }

    // Update the given pool's SUSHI allocation point. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(
            _allocPoint
        );
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    
    // View function to see pending SUSHIs on frontend.
    function pendingChaCha(uint256 _pid, address _user)
        external
        view
        returns (uint256,uint256,uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accChaChaPerShare = pool.accChaChaPerShare;
        uint256 lpSupply = pool.nftToken.balanceOf(address(this),pool.id);
        uint256 totalReward = 0;
        if (block.timestamp > pool.lastRewardTime && lpSupply != 0) {
            uint256 chachaReward = 
            IChaChaNFT(address(chachaToken)).getMultiplierForNFT(pool.lastRewardTime, block.timestamp).mul(pool.allocPoint).div(
                totalAllocPoint
            );
            if(chachaReward.div(lpSupply) >= getMaxReward(pool.lastRewardTime,block.timestamp)){
                totalReward = getMaxReward(pool.lastRewardTime,block.timestamp).mul(lpSupply);
                accChaChaPerShare = pool.accChaChaPerShare.add(
                    getMaxReward(pool.lastRewardTime,block.timestamp).mul(1e12)
                );
            }else{
                accChaChaPerShare = pool.accChaChaPerShare.add(
                    chachaReward.mul(1e12).div(lpSupply)
                );
                totalReward = chachaReward;
            }
        }
        if(IERC1155(pool.nftToken).balanceOf(address(this), pool.id) > 0){
            uint256 total = totalReward.mul(IOracle(orcale).getChaChaPrice()).mul(365 * 24 * 60 * 60) .div(block.timestamp.sub(pool.lastRewardTime));
            uint256 apy = total.div(IERC1155(pool.nftToken).balanceOf(address(this), pool.id).mul(IChaChaPrice(boxSaleAddress).getPublicSalePrice()));
            return (user.amount.mul(accChaChaPerShare).div(1e12).sub(user.rewardDebt),user.amount,apy);
        }else{
            return (user.amount.mul(accChaChaPerShare).div(1e12).sub(user.rewardDebt),user.amount,0);
        }
        
    }

     // Deposit LP tokens to MasterChef for SUSHI allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending =
                user.amount.mul(pool.accChaChaPerShare).div(1e12).sub(
                    user.rewardDebt
                );
            safeChaChaTransfer(msg.sender, pending);
        }
        if(_amount >0 ){
            IERC1155(pool.nftToken).safeTransferFrom(
            address(msg.sender),
            address(this),
            pool.id,
            _amount,
            "deposit"
            );
        }
        
        user.amount = user.amount.add(_amount);
        user.rewardDebt = user.amount.mul(pool.accChaChaPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    //Withdraw NFT tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending =
            user.amount.mul(pool.accChaChaPerShare).div(1e12).sub(
                user.rewardDebt
            );
        safeChaChaTransfer(msg.sender, pending);
        user.amount = user.amount.sub(_amount);
        user.rewardDebt = user.amount.mul(pool.accChaChaPerShare).div(1e12);
        if(_amount >0 ){
            IERC1155(pool.nftToken).safeTransferFrom(address(this), address(msg.sender), pool.id, _amount, "withdraw");
        }
        if(pool.deadAmount != 0 ){
            safeChaChaBurn(pool.deadAmount);
            pool.deadAmount = 0;
        }
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        IERC1155(pool.nftToken).safeTransferFrom(address(this), address(msg.sender), pool.id, user.amount, "emergencyWithdraw");
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    // Safe sushi transfer function, just in case if rounding error causes pool to not have enough SUSHIs.
    function safeChaChaTransfer(address _to, uint256 _amount) internal {
        uint256 sushiBal = IERC20(chachaToken).balanceOf(address(this));
        if (_amount > sushiBal) {
            IChaCha(chachaToken).mint();
            TransferHelper.safeTransfer(chachaToken, _to, _amount);
        } else {
            TransferHelper.safeTransfer(chachaToken, _to, _amount);
        }
    }

    function safeChaChaBurn(uint256 _amount) internal{
        uint256 sushiBal = IERC20(chachaToken).balanceOf(address(this));
        if (_amount > sushiBal) {
            IChaCha(chachaToken).mint();
            TransferHelper.safeTransfer(chachaToken, address(0), _amount);
        } else {
            TransferHelper.safeTransfer(chachaToken, address(0), _amount);
        }
        
    }
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external override view returns (bytes4){
        return bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external override view returns (bytes4){
        return bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"));
    }

    function supportsInterface(bytes4 interfaceId) external override view returns (bool){
        return true;
    }

    
}
