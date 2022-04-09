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

    function createDoc() public {
        bytes32 docHash = "2323";
        uint256 threshold = 2;
        uint256 voteEndLength = 20;

        vm.startPrank(alice);

        parentDoc = d.createRootDocument(docHash, voterAddresses, threshold, voteEndLength);

        emit log_named_uint("parent doc id", parentDoc);

        vm.stopPrank();
    }

    function createDocEdit() public {
        bytes32 docHash = "2222";

        vm.startPrank(alice);

        childDoc = d.createDocumentEdit(docHash, parentDoc);

        vm.stopPrank();
    }

    function testCreateDoc() public {
        createDoc();

        assertGt(parentDoc, 0);
    }

    function testDocEdit() public {
        createDoc();
        createDocEdit();

        assertGt(childDoc, parentDoc);
    }

    function testVotesSuccess() public {
        vm.warp(10);

        createDoc();

        createDocEdit();

        vm.startPrank(bob);

        d.castVote(childDoc);

        vm.stopPrank();

        vm.startPrank(charlie);

        d.castVote(childDoc);

        vm.stopPrank();

        vm.startPrank(alice);

        vm.warp(100);

        d.finalizeVoting(parentDoc);

        vm.stopPrank();
    }


}
