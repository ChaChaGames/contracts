// SPDX-License-Identifier: GPL-2.0-or-later



pragma solidity ^0.8.0;
interface IGameMerchant {

     struct Merchant {
        uint256 id;
        address addr;
        uint256 erc721Total;
        uint256 erc1155Total;
        uint256 gameTotal;
        uint256 joinTime;
    }
    
    struct Game {
        uint256 id;
        string name;
        uint256 merchantId;
        uint256 createTime;
    }

    struct NFTToken {
        uint256 id;
        uint256 gameId;
        address nftAddress;
        uint256 nftType;
        uint256 createTime;
    }

    function merchants(address addr) external view returns (Merchant memory);
    function games(address addr) external view returns (Game[] memory);
    function gameItem(address addr,uint256 gameId) external view  returns (Game memory);
    function nftTokens(address addr) external view returns (NFTToken[] memory);
    function gameNftTokens(address addr,uint256 gameId,uint256 nftId) external view returns (NFTToken memory);
    function creatNftToken(address merchantAddr,uint256 gameId,address nftAddress,uint256 nftType) external;
}
