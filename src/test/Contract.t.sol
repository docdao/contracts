// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/src/Vm.sol";
import "ds-test/test.sol";

import "../Document.sol";

contract DocumentTest is DSTest {
    Vm public constant vm = Vm(HEVM_ADDRESS);

    Document public d;

    address alice; 
    address bob; 
    address charlie;

    address[] voterAddresses;

    uint256 parentDoc;
    uint256 childDoc;

    function setUp() public {
        d = new Document();

        alice = vm.addr(2222);
        bob = vm.addr(30);
        charlie = vm.addr(40);

        voterAddresses.push(alice);
        voterAddresses.push(bob);
        voterAddresses.push(charlie);

        emit log_named_address("doc id: ", address(d));
    }

    function makeSimpleVote(uint256 pDoc, bytes32 docHash, uint256 warp) public {
        createDocEdit(docHash);

        vm.startPrank(bob);

        d.castVote(childDoc);

        vm.stopPrank();

        vm.startPrank(charlie);

        d.castVote(childDoc);

        vm.stopPrank();

        vm.startPrank(alice);

        vm.warp(warp);

        d.finalizeVoting(pDoc);

        vm.stopPrank();
    }

    function createDoc() public {
        bytes32 docHash = "2323";
        uint256 threshold = 2;
        uint256 voteEndLength = 20;

        vm.startPrank(alice);

        parentDoc = d.createRootDocument(docHash, voterAddresses, threshold, voteEndLength);

       emit log_named_uint("parent doc id", parentDoc);

        vm.stopPrank();
    }

    function createDocEdit(bytes32 docHash) public {
        vm.startPrank(alice);

        childDoc = d.createDocumentEdit(docHash, parentDoc);

        emit log_named_uint("child doc id", childDoc);

        vm.stopPrank();
    }

    function testCreateDoc() public {
        createDoc();

        assertGt(parentDoc, 0);
    }

    function testDocEdit() public {
        createDoc();
        createDocEdit("2323");

        assertGt(childDoc, parentDoc);
    }

    function testTwoDocEdit() public {
        createDoc();
        createDocEdit("44232");
        createDocEdit("2323");

        assertGt(childDoc, parentDoc);
    }

    function testSimpleVotesSuccess() public {
        vm.warp(10);

        createDoc();

        makeSimpleVote(parentDoc, "23322", 100);
    }

    function testTwoVotesSuccess() public {
        vm.warp(10);

        createDoc();

        makeSimpleVote(parentDoc, "23322", 200);
        makeSimpleVote(childDoc, "4232", 400);
    }
}
