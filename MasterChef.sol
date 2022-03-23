// SPDX-License-Identifier: GPL-2.0-or-later








pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interface/IChaChaLP.sol";
import "./interface/IPool.sol";


interface IMigratorChef {
    // Perform LP token migration from legacy UniswapV2 to ChaChaSwap.
    // Take the current LP token address and return the new LP token address.
    // Migrator should have full access to the caller's LP token.
    // Return the new LP token address.
    //
    // XXX Migrator must have allowance access to UniswapV2 LP tokens.
    // ChaChaSwap must mint EXACTLY the same amount of ChaChaSwap LP tokens or
    // else something bad will happen. Traditional UniswapV2 does not
    // do that so be careful!
    function migrate(IERC20 token) external returns (IERC20);
}



// MasterChef is the master of ChaCha. He can make ChaCha and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once ChaCha is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract MasterChef is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of ChaChas
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accChaChaPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accChaChaPerShare` (and `lastRewardTime`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }
    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. ChaChas to distribute per block.
        uint256 lastRewardTime; // Last block number that ChaChas distribution occurs.
        uint256 accChaChaPerShare; // Accumulated ChaChas per share, times 1e12. See below.
    }
    // The migrator contract. It has a lot of power. Can only be set through governance (owner).
    IMigratorChef public migrator;
    // The ChaCha TOKEN!
    IERC20 public ChaCha;

    // Block number when bonus ChaCha period ends.
    uint256 public bonusEndTime;
    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when ChaCha mining starts.
    uint256 public startTime;

    address public lpPoolAddress;

    mapping(address => bool) public poolIsAdd;

  

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );

    constructor(
        IERC20 _ChaCha,
        address _lpPoolAddress,
        uint256 _startTime,
        uint256 _bonusEndTime
    )  {
        ChaCha = _ChaCha;
        bonusEndTime = _bonusEndTime;
        startTime = _startTime;
        lpPoolAddress = _lpPoolAddress;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(
        uint256 _allocPoint,
        IERC20 _lpToken,
        bool _withUpdate
    ) public onlyOwner {
        require(!poolIsAdd[address(_lpToken)],"add same LP token is not allow");
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardTime =
            block.timestamp > startTime ? block.timestamp : startTime;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardTime: lastRewardTime,
                accChaChaPerShare: 0
            })
        );
        poolIsAdd[address(_lpToken)] = true;
    }

    // Update the given pool's ChaCha allocation point. Can only be called by the owner.
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
    // View function to see pending ChaChas on frontend.
    function pendingChaCha(uint256 _pid, address _user)
        external
        view
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accChaChaPerShare = pool.accChaChaPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.timestamp > pool.lastRewardTime && lpSupply != 0) {
            uint256 ChaChaReward =  IChaChaLP(address(ChaCha)).getMultiplierForLp(pool.lastRewardTime, block.timestamp).mul(pool.allocPoint).div(
                    totalAllocPoint
                );
            accChaChaPerShare = accChaChaPerShare.add(
                ChaChaReward.mul(1e12).div(lpSupply)
            );
        }
        return user.amount.mul(accChaChaPerShare).div(1e12).sub(user.rewardDebt);
    }

    // View function to see lp Info on frontend.
        function lpInfo(uint256 _pid, address _user)
        external
        view
        returns (uint256,uint256,uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        uint256 chachaReward =  IChaChaLP(address(ChaCha)).getMultiplierForLp(block.timestamp - 600, block.timestamp);
        if(chachaReward==0||lpSupply == 0){
            return (user.amount,lpSupply,0);
        }else{
            uint256 lpbalance = ChaCha.balanceOf(address(pool.lpToken)).mul(10e6).mul(lpSupply).div(pool.lpToken.totalSupply()).mul(2);
            uint256 dayChaChaReward =  chachaReward.mul(1 ether).mul(10e6).div(lpbalance);
            return (user.amount,lpSupply,dayChaChaReward.mul(365 * 24 * 6 ));
        }
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
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardTime = block.timestamp;
            return;
        }
        uint256 ChaChaReward = 
            IChaChaLP(address(ChaCha)).getMultiplierForLp(pool.lastRewardTime, block.timestamp).mul(pool.allocPoint).div(
                totalAllocPoint
            );
        // ChaCha.mint(devaddr, ChaChaReward.div(10));
        // ChaCha.mint(address(this), ChaChaReward);
        pool.accChaChaPerShare = pool.accChaChaPerShare.add(
            ChaChaReward.mul(1e12).div(lpSupply)
        );
        pool.lastRewardTime = block.timestamp;
    }

    // Deposit LP tokens to MasterChef for ChaCha allocation.
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
        pool.lpToken.safeTransferFrom(
            address(msg.sender),
            address(this),
            _amount
        );
        user.amount = user.amount.add(_amount);
        user.rewardDebt = user.amount.mul(pool.accChaChaPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public returns(bool){
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
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        emit Withdraw(msg.sender, _pid, _amount);
        return true;
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public returns(bool){
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
        return true;
    }

    // Safe ChaCha transfer function, just in case if rounding error causes pool to not have enough ChaChas.
    function safeChaChaTransfer(address _to, uint256 _amount) internal {
        uint256 ChaChaBal = ChaCha.balanceOf(address(this));
        if (_amount > ChaChaBal) {
            IPool(lpPoolAddress).mint(_to,_amount);
        } else {
            ChaCha.transfer(_to, ChaChaBal);
        }
    }


}