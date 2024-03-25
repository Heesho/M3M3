// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GNFT is ERC721Enumerable, Ownable {
    using Counters for Counters.Counter;
    using SafeERC20 for IERC20;

    Counters.Counter private _tokenIdCounter;


    string public _contractURI;
    uint256 public immutable maxSupply;


    mapping (uint256 => int256) public gumballIndex;
    uint256[] public gumballs;


    constructor(
        string memory name,
        string memory symbol
        ) ERC721(name, symbol)  {

    }

    // The following functions are overrides required by Solidity.

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    function setApprovalForAll(address operator, bool approved) public override(ERC721, IERC721) onlyAllowedOperatorApproval(operator) {
        super.setApprovalForAll(operator, approved);
    }

    function approve(address operator, uint256 tokenId) public override(ERC721, IERC721) onlyAllowedOperatorApproval(operator) {
        super.approve(operator, tokenId);
    }

    function transferFrom(address from, address to, uint256 tokenId) public override(ERC721, IERC721) onlyAllowedOperator(from) {
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public override(ERC721, IERC721) onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data)
        public
        override(ERC721, IERC721)
        onlyAllowedOperator(from)
    {
        super.safeTransferFrom(from, to, tokenId, data);
    }

    ////////////////////
    //// Restricted ////
    ////////////////////

    /** @dev Allows the protocol to set {baseURI}
      * @param uri is the updated URI
    */
    function setBaseURI(string calldata uri) external OnlyArtist {
        baseTokenURI = uri;

        emit SetBaseURI(uri);
    }

    /** @dev Allows the protocol to set {contractURI} 
      * @param uri is the updated URI
    */
    function setContractURI(string calldata uri) external OnlyArtist {
        _contractURI = uri;

        emit SetContractURI(uri);
    }

}