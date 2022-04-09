//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

contract L1DAO {
    constructor() {}

    string public finalProposalVersion;

    function getFinalProposalVersion() public view returns (string memory) {
        return finalProposalVersion;
    }

    function setFinalProposalVersion(string memory _finalProposalVersion) public {
        finalProposalVersion = _finalProposalVersion;
    }
}
