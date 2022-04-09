//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
contract FilterNft is ERC721("Filter", "FLT") {
    uint256 _tokenId;

    constructor() {
        _tokenId = 0;
    }

    function mintFilter() public {
        _tokenId++;
        _mint(msg.sender, _tokenId);
    }
}