// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../utils/Sig.sol";

/**
 * @title DeepGoNFT contract
 * @dev Extends ERC721 Non-Fungible Token Standard basic implementation
 */
contract NFT is ERC721Enumerable, ReentrancyGuard, Ownable {
    using SafeMath for uint256;
    using Strings for uint256;

    address public admin;
    uint256 public MAX_ANIMALS;
    bool public mintIsActive = true;

    mapping(uint256 => string) private _tokenURIs;
    mapping(address => bool) public expired;

    event SetTokenURI(uint256 _tokenId, string _tokenURI);
    event TransferAdmin(address indexed from, address indexed to);
    event MintAnimal(address indexed addr, uint256 tokenId, string _tokenURI);
    event Expired(address _addr);

    constructor() ERC721("NFT", "NFT") {}

    /*     
    * Transfer admin
    */
    function transferAdmin(address _to) external onlyOwner {
        require(_to != admin, "Transfer Meaningless");
        address _from = admin;
        admin = _to;

        emit TransferAdmin(_from, _to);
    }

    /*     
    * Set URI for NFT with tokenId 
    */
    function _setTokenURI(uint256 _tokenId, string memory _tokenURI) internal virtual {
        require(_exists(_tokenId), "ERC721Metadata: URI set of nonexistent token");
        _tokenURIs[_tokenId] = _tokenURI;

        emit SetTokenURI(_tokenId, _tokenURI);
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        string memory _tokenURI = _tokenURIs[tokenId];
        
        return _tokenURI;
    }

    /*
    * Pause sale if active, make active if paused
    */
    function flipMintableState() public {
        mintIsActive = !mintIsActive;
    }

    /**
    * Mint Animals
    */
    function mint() public nonReentrant
    {
        uint tokenID = totalSupply();
        
        _safeMint(msg.sender, tokenID);
        _setTokenURI(tokenID, "it's uri");

        emit MintAnimal(msg.sender, tokenID, "it's uri");
        emit Expired(msg.sender);
    }

}
