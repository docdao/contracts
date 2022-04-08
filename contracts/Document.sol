//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Document is ERC1155, ReentrancyGuard {
    // LIB IMPORTS
    using Counters for Counters.Counter;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeMath for uint256;

    // EVENTS

    // VARIABLES
    Counters.Counter private _tokenIds;

    // who can vote on this doc
    mapping(uint256 => EnumerableSet.AddressSet) private docsVotingAddresses;

    // who has voted on this doc
    mapping(uint256 => EnumerableSet.AddressSet) private docsVoted;

    mapping(uint256 => bool) public docsLatest;
    mapping(uint256 => uint256) public docsParents;

    // children of this document
    mapping(uint256 => EnumerableSet.UintSet) private docsChildren;
    mapping(uint256 => bytes32) public docsHashes;
    mapping(uint256 => uint256) public docsThresholds;

    // how long we wait until the Vote Ends - static and passed to children
    mapping(uint256 => uint256) public docsVoteEndLength; 
    
    // records absolutely when a vote will end after first child has been created for a parent
    mapping(uint256 => uint256) public docsVoteEnd; 
    
    // CONSTRUCTOR
    constructor() {
        // we reserve 0 for a const doc that has no parent
        _tokenIds.increment();
    }

    // PUBLIC FN
    function createRootDocument(bytes32 docHash, address[] memory votingAddresses, uint256 threshold, uint256 voteEndLength) public {
        _mint(msg.sender, _tokenIds.current(), 1, "");

        // TODO: assert you're in the votingAddresses set

        // we have no parent
        docsParents[_tokenIds.current()] = 0;
        docsLatest[_tokenIds.current()] = true;
        docsHashes[_tokenIds.current()] = docHash;
        docsThresholds[_tokenIds.current()] = threshold;
        docsVoteEnd[_tokenIds.current()] = 0;
        docsVoteEndLength[_tokenIds.current()] = voteEndLength;
        
        _tokenIds.increment();
    }

    // TODO: put max on children proposal?
    function createDocumentEdit(bytes32 docHash, uint256 parent) public {
        _mint(msg.sender, _tokenIds.current(), 1, "");

        // TODO: enforce parent exists/legit
        docsParents[_tokenIds.current()] = parent;
        docsHashes[_tokenIds.current()] = docHash;
        docsLatest[_tokenIds.current()] = false;

        // inherit items from parent
        docsThresholds[_tokenIds.current()] = docsThresholds[parent];
        docsVoteEndLength[_tokenIds.current()] = docsVoteEndLength[parent];

        // add this as a child to the parent
        docsChildren[parent].add(_tokenIds.current());

        // if we are the first child, we need to kick off the ending of the vote counter
        if (docsChildren[parent].length() == 1) {
            docsVoteEnd[parent] = block.timestamp.add(docsVoteEndLength[parent]);
        }
        
        _tokenIds.increment();
    }

    function castVote(uint256 docId) inVotingAddressesFor(docId) public {
        // make sure we didn't cast this vote already
        require(!docsVoted[docId].contains(msg.sender), "sender has already voted");

        // cast our vote
        docsVoted[docId].add(msg.sender);
    }

    function finalizeVoting(uint256 docId) public returns (uint256) {
        // docId in this case is the "parent" for the winning doc

        // EXIT STATES
        // - tie breaker for children => no vote, flush children, end vote
        // - not above threshold => no vote, flush children, end vote
        // - we are not above the parent vote TTL => exit cleanly with error
        // - clear winner above threshold => promote child to doc, flush other children, end vote

        // ensure token exists
        require(_tokenIds.current() >= docId, "doc id DNE");

        // determine if the vote has ended or not
        require(block.timestamp < docsVoteEnd[docId], "vote has not ended");

        // determine winner (if exists over children set)
        // TODO: this isn't scalable, will need to be re-written for >20 children

        
        // TODO: known to be wrong if we hit the max in solidity
        uint256 currentWinner = type(uint256).max;
        uint256 mostVotes = 0;
        uint256 iter;
        uint256 currentChild;
        bool tieState = false;

        // step through our children to determine a winner if any
        for (iter = 0; docsChildren[docId].length() > iter; iter++) {
            currentChild = docsChildren[docId].at(iter);

            if (docsVoted[currentChild].length() > mostVotes) {
                currentWinner = currentChild;
            }

            if (docsVoted[currentChild].length() == mostVotes) {
                tieState = true;
                currentWinner = currentChild;
            }
        }

        // FAILURE STATE
        // vote failed or tie state or no clear winner
        if (currentWinner == type(uint256).max || tieState || mostVotes < docsThresholds[docId]) {
            _flushChildren(docId, 0);
            _endVote(docId);
            return 0;
        }

        // WINNING STATE 
        // - mark our winner
        // - flush children
        // - cleanup
        docsLatest[currentWinner] = true;
        _flushChildren(docId, currentWinner);
        _endVote(docId);

        return 1;
    }

    // MODIFIERS
    modifier inVotingAddressesFor(uint256 docId) {
        // base check to ensure we are basically not 0
        require(_tokenIds.current() > 0 && docId > 0, "zero document id passed");

        // make sure passed id in the set of token ids
        require(_tokenIds.current() >= docId, "document id DNE");

        // make sure the passed doc id has our address
        uint256 parent = docsParents[docId];

        // TODO: add some checking ensure parent id exists

        // voter in set
        require(docsVotingAddresses[parent].contains(msg.sender), "voter not in voting set");

        _; 
    } 

    // INTERNAL FNs

    // cleanup vote state for a parent doc and children
    function _endVote(uint256 docId) internal nonReentrant() {

    }

    // promotes a child to a current doc
    function _promoteChild() internal nonReentrant() {
        
    }

    // flush our children (you monster)
    function _flushChildren(uint256 docId, uint256 winner) internal nonReentrant() {

    }
}