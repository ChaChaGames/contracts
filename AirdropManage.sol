// SPDX-License-Identifier: GPL-2.0-or-later


import './interface/IAirdrop.sol';
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import './libraries/TransferHelper.sol';
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";


contract AirdropManage is Context,Ownable,IERC1155Receiver {
    using Address for address;
    using Strings for uint256;

    mapping(address=>mapping(uint256=>bool)) private claimed;


    mapping(address=>mapping(uint256=>uint256)) private claimedAmount;

    struct AirdropInfo {
        bytes32 merkleRoot; // merkle根
        address rewardToken; // Address of reword token contract.
        uint256 rewardType; // 奖励类型  0  ERC20  1 ERC1155  ERC721
        uint256 rewardTokenId; // 奖励为 ERC1155 如果没有继承空投接口奖励 则需要传奖励的tokenId
        bool isInheritAir;// 奖励token是否继承空投接口奖励
        uint256 totalAmount;//奖励总数
        uint256 receivedAmount;//已领取奖励
    }


    AirdropInfo[] public airdropInfo;

    event AirdropAdd(bytes32 merkleRoot,uint256 rewardNo,address rewardToken,uint256 rewardType,uint256 totalAmount);

    event ModifyAirdrop(uint256 pid, bytes32 merkleRoot,uint256 rewardNo,address rewardToken,uint256 rewardType,uint256 totalAmount);

    event Claim(address indexed claimant, uint256 pid,uint256 tokenId,uint256 totalReceivedAmount,uint256 userReceivedAmount);

    constructor () {
       
    }

     function airdropInfoLength() external view returns (uint256) {
        return airdropInfo.length;
    }

    /**
     * @dev Returns true if the claim at the given index in the merkle tree has already been made.
     * @param account The address to check if claimed.
     */
    function hasClaimed(address account,uint256 pid) public view returns (bool) {
        return claimed[account][pid];
    }
    /**
     * @dev Returns true if the claim at the given index in the merkle tree has already been made.
     * @param account The address to check if claimed.
     */
    function userClaimedAmount(address account,uint256 pid) public view returns (uint256) {
        return claimedAmount[account][pid];
    }
    /**
     * @dev Sets the merkle root. Only callable by onwer.
     * @param _merkleRoot The merkle root to set.
     */
    function addAirdrop(bytes32 _merkleRoot,address _rewardToken, uint256 _rewardType,uint256 _rewardTokenId,bool _isInheritAir,uint256 _totalAmount) public onlyOwner {
        airdropInfo.push(
            AirdropInfo({
                merkleRoot: _merkleRoot,
                rewardToken: _rewardToken,
                rewardType: _rewardType,
                rewardTokenId: _rewardTokenId,
                isInheritAir:_isInheritAir,
                totalAmount:_totalAmount,
                receivedAmount:0
            })
        );
        emit AirdropAdd(_merkleRoot,airdropInfo.length,_rewardToken,_rewardType,_totalAmount);
    }

    /**
     * @dev Sets the merkle root. Only callable by onwer.
     * @param _merkleRoot The merkle root to set.
     */
    function modifyAirdrop(uint256 pid,bytes32 _merkleRoot,address _rewardToken, uint256 _rewardType,uint256 _rewardTokenId,bool _isInheritAir,uint256 _totalAmount) public onlyOwner {
        require(pid<airdropInfo.length, "pid less than airdropInfoLength required.");
        AirdropInfo storage info =  airdropInfo[pid];
        info.merkleRoot = _merkleRoot;
        info.rewardToken = _rewardToken;
        info.rewardType = _rewardType;
        info.rewardTokenId = _rewardTokenId;
        info.isInheritAir = _isInheritAir;
        info.totalAmount = _totalAmount;
        emit ModifyAirdrop(pid,_merkleRoot,airdropInfo.length,_rewardToken,_rewardType,_totalAmount);
    }

    /**
     * @dev Claims airdropped tokens.
     * @param merkleProof A merkle proof proving the claim is valid.
     */
    function claim(uint256 pid ,bytes32[] calldata merkleProof,uint256 amount) public {
        require(pid<airdropInfo.length, "pid less than airdropInfoLength required.");
        AirdropInfo storage info =  airdropInfo[pid];
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender,amount));
        bool valid = MerkleProof.verify(merkleProof, info.merkleRoot, leaf);
        require(valid, "Valid proof required.");
        require(!claimed[msg.sender][pid], "Tokens already claimed.");
        if(info.totalAmount != 0){
            require(info.receivedAmount  < info.totalAmount, "less than total required.");
            if (info.totalAmount - info.receivedAmount < amount){
                amount = info.totalAmount - info.receivedAmount;
            }
        }
        claimed[msg.sender][pid] = true;
        claimedAmount[msg.sender][pid] = amount;
        info.receivedAmount += amount;
        
        if(info.rewardType == 0){
            claimERC20(msg.sender,amount,info.rewardToken,info.isInheritAir,info.receivedAmount,pid);
        }else if(info.rewardType == 1){
            claimERC1155(msg.sender,amount,info.rewardToken,info.rewardTokenId,info.isInheritAir,info.receivedAmount,pid);
        }else{
            claimERC721(msg.sender,amount,info.rewardToken,info.isInheritAir,info.receivedAmount,pid);
        }
    }
    function claimERC20(address user ,uint256 amount,address token,bool isInheritAir,uint256 receivedAmount,uint256 pid) internal{
        if(isInheritAir){
            IAirdrop(token).airdrop(user, amount);
        }else{
            require(IERC20(token).balanceOf(address(this)) >= amount,"balance is not enough");
            TransferHelper.safeTransfer(token, user, amount);
        }
        emit Claim(user, pid,0,receivedAmount,amount);
    }
    function claimERC1155(address user ,uint256 amount,address token,uint256 tokenId,bool isInheritAir,uint256 receivedAmount,uint256 pid) internal{
        if(isInheritAir){
            tokenId = IAirdrop(token).airdrop(user, amount);
        }else{
            require(IERC1155(token).balanceOf(address(this),tokenId) >= amount,"balance is not enough");
            IERC1155(token).safeTransferFrom(address(this), user, tokenId,amount,"airdrop");
        }
        emit Claim(user, pid,tokenId,receivedAmount,amount);
    }

    function claimERC721(address user ,uint256 amount,address token,bool isInheritAir,uint256 receivedAmount,uint256 pid) internal{
        require(isInheritAir,"rewardToken non IAirdrop implementer");
        uint256 tokenId = IAirdrop(token).airdrop(user, amount);
        emit Claim(user, pid,tokenId,receivedAmount,amount);
    }

    function onERC1155Received(address _operator, address _from, uint256 _id, uint256 _value, bytes calldata _data) external override returns(bytes4){
        return bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
    }

    function onERC1155BatchReceived(address _operator, address _from, uint256[] calldata _ids, uint256[] calldata _values, bytes calldata _data) external override returns(bytes4){
        return bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"));
    }

    function supportsInterface(bytes4 interfaceId) external override view returns (bool){
        return false;
    }

    
}   