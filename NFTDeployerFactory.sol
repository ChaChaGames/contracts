// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "./ChaChaERC721.sol";
import "./ChaChaERC1155.sol";
import "./interface/INFTInitialize.sol";
import "./interface/IGameMerchant.sol";
import "./interface/IOwnable.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

contract NFTDeployerFactory is Ownable, ERC1155Holder {
    address public gameMerchant;

    event DeployNFT(
        address indexed addr ,
        uint256 indexed gameMerchant,
        uint256 indexed gameId ,
        string  name,
        string  symbol,
        uint256  maxSupply,
        string  baseURI,
        string[]  intNames,
        uint256[] minValues,
        uint256[] maxValues,
        string[]  stringNames,
        string[]  values,
        address  nftAddress
    );

    struct NFT {
        address nftAddr;
        uint256 ercType;
    }

    NFT[] public allNFT;
    
    function allLength() external view returns (uint) {
        return allNFT.length;
    }

    function setGameMerchant(address _gameMerchant) external  onlyOwner()  {
        gameMerchant = _gameMerchant;
    }

    // function deployNFT(
    //     uint256 gameId,
    //     string memory name,
    //     string memory symbol,
    //     uint256 initSupply_,
    //     uint256  maxSupply,
    //     string memory baseURI,
    //     string[] memory intNames,
    //     uint256[] memory  minValues,
    //     uint256[] memory  maxValues,
    //     string[] memory stringNames,
    //     string[] memory values,
    //     address  nftAddress
    // ) external {
    //     // require(IGameMerchant(gameMerchant).gameItem(msg.sender,gameId).id != 0, 'NFTDeployerFactory: Game does not exist'); 
    //     address nftAddr = address(new ChaChaERC1155());
    //     INFTInitialize(nftAddr).initialize(name, symbol,initSupply_,maxSupply, baseURI, intNames, minValues, maxValues, stringNames, values, 1,nftAddress);
    //     IERC1155(nftAddr).safeTransferFrom(address(this), msg.sender, 1, maxSupply, "");
    //     IOwnable(nftAddr).transferOwnership(msg.sender);
    //     allNFT.push(NFT(nftAddr,1));
    //     // IGameMerchant(gameMerchant).creatNftToken(msg.sender,gameId,nftAddr,1);
    //     //emit DeployNFT(msg.sender,IGameMerchant(gameMerchant).gameItem(msg.sender,gameId).id,gameId,name, symbol,maxSupply, baseURI, intNames, minValues, maxValues, stringNames, values, nftAddress);
    //     emit DeployNFT(msg.sender,0,0,"", symbol,maxSupply, baseURI, intNames, minValues, maxValues, stringNames, values, nftAddress);
    // }
    
    function deployNFT(
        string memory name,
        string memory symbol,
        uint256 initSupply_,
        uint256  maxSupply,
        string memory baseURI,
        string[] memory intNames,
        uint256[] memory  minValues,
        uint256[] memory  maxValues,
        string[] memory stringNames,
        string[] memory values,
        address  nftAddress
    ) external  onlyOwner() {
        // require(IGameMerchant(gameMerchant).gameItem(msg.sender,gameId).id != 0, 'NFTDeployerFactory: Game does not exist'); 
        address nftAddr = address(new ChaChaERC1155());
        INFTInitialize(nftAddr).initialize(name, symbol,initSupply_,maxSupply, baseURI, intNames, minValues, maxValues, stringNames, values, 1,nftAddress);
        IERC1155(nftAddr).safeTransferFrom(address(this), msg.sender, 1, initSupply_, "");
        IOwnable(nftAddr).transferOwnership(msg.sender);
        allNFT.push(NFT(nftAddr,1));
        // IGameMerchant(gameMerchant).creatNftToken(msg.sender,gameId,nftAddr,1);
        //emit DeployNFT(msg.sender,IGameMerchant(gameMerchant).gameItem(msg.sender,gameId).id,gameId,name, symbol,maxSupply, baseURI, intNames, minValues, maxValues, stringNames, values, nftAddress);
        emit DeployNFT(msg.sender,0,0,name, symbol,maxSupply, baseURI, intNames, minValues, maxValues, stringNames, values, nftAddress);
    }
}

