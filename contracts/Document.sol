//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract Document is ERC1155 {
    using Counters for Counters.Counter;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    Counters.Counter private _tokenIds;

    mapping(uint256 => EnumerableSet.AddressSet) private docsVotingAddresses;
    mapping(uint256 => bool) public docsLatest;
    mapping(uint256 => uint256) public docsParents;
    mapping(uint256 => EnumerableSet.UintSet) private docsChildren;
    mapping(uint256 => bytes32) public docsHashes;
    mapping(uint256 => uint256) public docsThresholds;
    mapping(uint256 => uint256) public docsVoteEnd;

    constructor() {  }

    function createRootDocument(bytes32 docHash, address[] memory votingAddresses, uint256 threshold, uint256 voteEnd) public {
        _mint(msg.sender, _tokenIds.current(), 1, "");

        // TODO: assert you're in the votingAddresses set

        docsParents[_tokenIds.current()] = _tokenIds.current();
        docsLatest[_tokenIds.current()] = true;
        docsHashes[_tokenIds.current()] = docHash;
        docsThresholds[_tokenIds.current()] = threshold;
        docsVoteEnd[_tokenIds.current()] = voteEnd;
        
        _tokenIds.increment();
    }

    function createDocumentEdit(bytes32 docHash, uint256 parent) public {
        _mint(msg.sender, _tokenIds.current(), 1, "");

        // TODO: enforce parent exists/legit
        docsParents[_tokenIds.current()] = parent;
        docsHashes[_tokenIds.current()] = docHash;
        docsLatest[_tokenIds.current()] = false;

        // inherit items from parent
        docsThresholds[_tokenIds.current()] = docsThresholds[parent];
        docsVoteEnd[_tokenIds.current()] = docsVoteEnd[parent];

        // add this as a child to the parent
        docsChildren[parent].add(_tokenIds.current());
        
        _tokenIds.increment();
    }

    
}