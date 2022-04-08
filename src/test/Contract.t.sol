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

    function setUp() public {
        d = new Document();

        alice = vm.addr(2222);
        bob = vm.addr(30);
        charlie = vm.addr(40);

        voterAddresses.push(alice);
        voterAddresses.push(bob);
        voterAddresses.push(charlie);
    }

    function testCreateDoc() public {
        bytes32 docHash = "2323";
        uint256 threshold = 3;
        uint256 voteEndLength = 20;

        vm.startPrank(alice);

        uint256 docId = d.createRootDocument(docHash, voterAddresses, threshold, voteEndLength);

        emit log_uint(docId);

        vm.stopPrank();

        assertGt(docId, 0);
    }

    function testDocEdit() public {
        bytes32 docHash = "2222";

        vm.startPrank(alice);

        uint256 docId = d.createDocumentEdit(docHash, parentDoc);

        vm.stopPrank();

        assertGt(docId, parentDoc);
    }
}
