//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
import "openzeppelin-contracts/contracts/utils/Counters.sol";
import "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import "openzeppelin-contracts/contracts/utils/math/SafeMath.sol";

contract Document is ERC1155, ReentrancyGuard {
    // LIB IMPORTS
    using Counters for Counters.Counter;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeMath for uint256;

    // CONSTRUCTOR
    // TODO: jordan change this to whatever
    constructor() ERC1155("https://localhost/api/item/{id}.json") {
        _tokenIds.increment();
    }

    // EVENTS
    event RootDocumentCreated(uint256 docId, uint256 threshold, uint256 voteEndLength);
    event DocumentEditCreated(uint256 docId, uint256 parentId);
    event VoteFinalized(uint256 docId, uint256 winner);
    event VoteRejected(uint256 docId, uint256 reason);
    event VoteCast(uint256 docId, address byUser);

    // VARIABLES
    Counters.Counter private _tokenIds;

    // who can vote on this doc
    mapping(uint256 => EnumerableSet.AddressSet) private docsVotingAddresses;

    // who has voted on this doc
    mapping(uint256 => EnumerableSet.AddressSet) private docsVoted;

    mapping(uint256 => bool) public docsLatest;

    // if we are a dead child we want to be marked as such
    mapping(uint256 => bool) public docsIsDeadChild;

    mapping(uint256 => uint256) public docsParents;

    // children of this document
    mapping(uint256 => EnumerableSet.UintSet) private docsChildren;
    mapping(uint256 => bytes32) public docsHashes;
    mapping(uint256 => uint256) public docsThresholds;

    // how long we wait until the Vote Ends - static and passed to children
    mapping(uint256 => uint256) public docsVoteEndLength; 
    
    // records absolutely when a vote will end after first child has been created for a parent
    // uint256(max) is the marker for a vote that has ended
    mapping(uint256 => uint256) public docsVoteEnd; 
    
    // PUBLIC FN
    function createRootDocument(bytes32 docHash, address[] memory votingAddresses, uint256 threshold, uint256 voteEndLength) public returns (uint256 createdDoc) {
        _mint(msg.sender, _tokenIds.current(), 1, "");

        // we have no parent
        docsParents[_tokenIds.current()] = 0;
        docsLatest[_tokenIds.current()] = true;
        docsHashes[_tokenIds.current()] = docHash;
        docsThresholds[_tokenIds.current()] = threshold;
        docsVoteEnd[_tokenIds.current()] = 0;
        docsVoteEndLength[_tokenIds.current()] = voteEndLength;
        docsIsDeadChild[_tokenIds.current()] = false;

        for (uint i = 0; votingAddresses.length > i; i++) {
            if (msg.sender != votingAddresses[i]) {
                docsVotingAddresses[_tokenIds.current()].add(votingAddresses[i]);
            }
            docsVotingAddresses[_tokenIds.current()].add(msg.sender);
        }

        createdDoc = _tokenIds.current();
        
        _tokenIds.increment();

        emit RootDocumentCreated(createdDoc, threshold, voteEndLength);
    }

    // TODO: put max on children proposal?
    function createDocumentEdit(bytes32 docHash, uint256 parent) public returns (uint256 createdDoc) {
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

        createdDoc = _tokenIds.current();
        
        _tokenIds.increment();

        emit DocumentEditCreated(createdDoc, parent);
    }

    function castVote(uint256 docId) inVotingAddressesFor(docId) public {
        // make sure we didn't cast this vote already
        require(!docsVoted[docId].contains(msg.sender), "sender has already voted");

        // cast our vote
        docsVoted[docId].add(msg.sender);

        emit VoteCast(docId, msg.sender);
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
        // 1 - vote failed
        // 2 - tie state 
        // 4 - no clear winner
        if (currentWinner == type(uint256).max || tieState || mostVotes < docsThresholds[docId]) {
            _flushChildren(docId, 0);
            _endVote(docId);

            // TODO: cleanup later with valid codes
            emit VoteRejected(docId, 1);

            return 0;
        }

        // WINNING STATE 
        // - mark our winner
        // - flush children
        // - cleanup
        docsLatest[currentWinner] = true;

        _promoteChild(docId, currentWinner);
        _flushChildren(docId, currentWinner);
        _endVote(docId);

        emit VoteFinalized(docId, currentWinner);

        return currentWinner;
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
        docsVoteEnd[docId] = type(uint256).max;
    }

    // promotes a child to a current doc
    function _promoteChild(uint256 docId, uint256 winner) internal nonReentrant() {
        docsLatest[docId] = false;
        docsLatest[winner] = true;
    }

    // flush our children (you monster)
    function _flushChildren(uint256 parentDocId, uint256 winner) internal nonReentrant()  {
        // TODO: ensure we have children or are a valid parent, etc.

        // TODO: assume you are not a dead parent

        for (uint256 i = 0; docsChildren[parentDocId].length() > i; i++) {
            // make sure we are not killing winning children 
            if (docsChildren[parentDocId].at(i) != winner) {
                docsIsDeadChild[docsChildren[parentDocId].at(i)] = true;
            }
        }
    }
}