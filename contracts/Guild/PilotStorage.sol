// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "../utils/AccessControl.sol";
import "../utils/Sig.sol";
import "./VoyagerStorage.sol";

contract PilotStorage is ERC721, IERC721Enumerable, AccessControl {
    using SafeMath for uint256;

    event SetTokenURI(uint tokenId, string tokenURI);
    event SetTokenIDWithoutURI(address addr, uint tokenId);
    event SetTotalMinted(uint amount);
    event SetWhitelistExpired(uint amount);
    event SetBaseMintFee(uint256 baseMintFee);
    event SetLevelUpExp(uint256 level, uint256 exp);
    event SetDgtAddress(address addr);
    event SetDspAddress(address addr);

    struct Fee {
        address token1;
        uint256 amount1;
        address token2;
        uint256 amount2;
    } 

    struct Pilot {
        string name; // to set
        // address minter;
        address leader;
        uint256 chargeShare; // to set NFT收益占比
        uint256 level;
        uint256 id;
        uint256 a;
        uint256 c;
        // uint256 startHoldingTime;
    }

    // 1. 铸造者即会长(1-x)%收益，NFT持有者x%收益，x由会长设定，会长可变更
    uint256 public chargeShareDecimal = 10 ** 4;

    // 2. 限定数量，前100个空投，白名单铸造无限制，第i个公会花费 50*(i+1) DGT
    uint256 public maxSupply = 100;
    address public dgtAddress = address(0);
    address public dspAddress = address(0);
    uint256 public tokenDecimal = 10 ** 18;

    uint256 public _maxWhitelisted = 100;
    uint256 public _totalMinted;
    uint256 public _whitelistExpired;
    uint256 public baseMintFee = 100 * tokenDecimal;
    string public _token0URI;
    
    // levelUp fee
    mapping(uint256 => Fee) public levelUpFee;

    Pilot[] public pilots;
    mapping(address => uint[]) public ownedPilots;
    mapping(address => mapping( uint256 => uint256 )) public ownedPilotsIndex;
    mapping(uint256 => uint256) public allPilotsIndex;
    mapping(uint256 => string) public _tokenURIs;
    mapping(address => uint256) public _tokenIDWithoutURI;
    mapping(address => uint256) public _mintTokenIDWithoutURI;
    mapping(address => bool) public _expiredWhitelist;
    mapping(uint256 => mapping(address => uint)) public exp;
    mapping(uint256 => mapping(address => bool)) public isBannedOfPilot;
    mapping(uint256 => uint256) public levelUpExp;

    constructor() ERC721("PilotWhale", "PLW") {}

    function token0URI(
        string memory _string
    ) public onlyProxy 
    {
        _token0URI = _string;
    }

    function setLevelUpExp(uint256 level_, uint256 exp_) external onlyOwner {
        levelUpExp[level_] = exp_;
        emit SetLevelUpExp(level_, exp_);
    }

    function setIsBanned(uint256 tokenId_, address addr_) external onlyProxy {
        isBannedOfPilot[tokenId_][addr_] = true;
    }

    function setLevelUpFee(uint256 tokenId_, Fee memory fee_) external onlyProxy {
        levelUpFee[tokenId_] = fee_;
    }

    function getLevelUpFee(uint256 tokenId_) external view onlyProxy returns(Fee memory fee) {
        return levelUpFee[tokenId_];
    }

    function getPilot(
        uint256 _index
    ) public view returns (Pilot memory)
    {
        return pilots[_index];
    }

    function setLeader(uint256 tokenId_, address addr_) external onlyProxy {
        pilots[getAllPilotIndex(tokenId_)].leader = addr_;
    }

    function setLevel(uint256 tokenId_, uint256 level_) external onlyProxy {
        pilots[allPilotsIndex[tokenId_]].level = level_;
    }

    function getLeader(uint256 tokenId_) external view returns (address) {
        return pilots[allPilotsIndex[tokenId_]].leader;
    }

    function getLevel(uint256 tokenId_) external view returns (uint256) {
        return pilots[allPilotsIndex[tokenId_]].level;
    }

    function setChargeShare(uint256 tokenId_, uint256 chargeShare_) external onlyProxy {
        pilots[allPilotsIndex[tokenId_]].chargeShare = chargeShare_;
    }

    function setName(uint256 tokenId_, string memory name_) external onlyProxy {
        pilots[allPilotsIndex[tokenId_]].name = name_;
    }

    function getMintFee(address addr_) public view returns(uint256 mintFee) {
        mintFee = baseMintFee + ownedPilots[addr_].length * baseMintFee * 1 / 2;
    }

    function setBaseMintFee(uint256 baseMintFee_) external onlyOwner {
        baseMintFee = baseMintFee_;
        emit SetBaseMintFee(baseMintFee_);
    }

    function getAllPilotIndex(
        uint256 _tokenId
    ) public view returns (uint256) 
    {
        return allPilotsIndex[_tokenId];
    }

    function getPilotByTokenId(
        uint256 _tokenId
    ) public view returns (Pilot memory)
    {
        return pilots[getAllPilotIndex(_tokenId)];
    }

    function getExpiredWhitelist(
        address _addr
    ) public view returns (bool) 
    {
        return _expiredWhitelist[_addr];
    }

    function setExp(uint tokenId_, address member_, uint256 exp_) external onlyProxy {
        require(exp_ > 0, "Exp Not Positive");
        exp[tokenId_][member_] += exp_;
    }

    function getExp(uint tokenId_, address member_) public view returns (uint256) {
        return exp[tokenId_][member_];
    }

    function setExpiredWhitelist(
        address _addr, 
        bool _isExpired
    ) external onlyProxy 
    {
        _expiredWhitelist[_addr] = _isExpired;
    }

    function setDgtAddress(address addr_) external onlyOwner notZeroAddress(addr_) {
        dgtAddress = addr_;
        emit SetDgtAddress(addr_);
    }

    function setDspAddress(address addr_) external onlyOwner notZeroAddress(addr_) {
        dspAddress = addr_;
        emit SetDspAddress(addr_);
    }

    function setMaxSupply(uint totalSupply_) external onlyProxy {
        require(totalSupply_ > maxSupply, "Less Than Max Supply");
        maxSupply = totalSupply_;
    }

        
    function getTokenIDWithoutURI(
        address _addr
    ) public view returns (uint256) 
    {
        return _tokenIDWithoutURI[_addr];
    }

    function getMintTokenIDWithoutURI(
        address _addr
    ) public view returns (uint256) 
    {
        return _mintTokenIDWithoutURI[_addr];
    }

    function setMintTokenIDWithoutURI(
        address _addr, 
        uint256 _tokenId
    ) external onlyProxy 
    {
        _mintTokenIDWithoutURI[_addr] = _tokenId;
    }

    function setTokenIDWithoutURI(
        address _addr, 
        uint256 _tokenId
    ) external onlyProxy 
    {
        _tokenIDWithoutURI[_addr] = _tokenId;

        emit SetTokenIDWithoutURI(_addr, _tokenId);
    }

    function getMaxWhitelisted() public view returns (uint256) {
        return _maxWhitelisted;
    }

    function getTotalMinted() public view returns (uint256) {
        return _totalMinted;
    }

    function setTotalMinted(
        uint256 _amount
    ) external onlyProxy 
    {
        _totalMinted = _amount;

        emit SetTotalMinted(_amount);
    }

    function setA(
        uint256 tokenId_,
        uint256 a_
    ) external onlyProxy {
        pilots[getAllPilotIndex(tokenId_)].a = a_;
    }

    function getA(uint256 tokenId_) external view returns (uint256) {
        return pilots[allPilotsIndex[tokenId_]].a;
    }

    function setC(
        uint256 tokenId_,
        uint256 c_
    ) external onlyProxy {
        pilots[getAllPilotIndex(tokenId_)].c = c_;
    }

    function getC(uint256 tokenId_) external view returns (uint256) {
        return pilots[allPilotsIndex[tokenId_]].c;
    }

    function getChargeShare(uint256 tokenId_) external view returns (uint256) {
        return pilots[allPilotsIndex[tokenId_]].chargeShare;
    }

    function getWhitelistExpired() public view returns (uint256){
        return _whitelistExpired;
    }

    function setWhitelistExpired(
        uint256 _amount
    ) external onlyProxy 
    {
        _whitelistExpired = _amount;

        emit SetWhitelistExpired(_amount);
    }

    function mintPilot(
        address _addr, 
        uint256 _tokenId
    ) external
    {
        _safeMint(_addr, _tokenId);
    }

    function setTokenURI(uint256 _tokenId, string memory _tokenURI) external onlyProxy {
        require(_exists(_tokenId), "ERC721Metadata: URI set of nonexistent token");
        _tokenURIs[_tokenId] = _tokenURI;
        
        emit SetTokenURI(_tokenId, _tokenURI);   
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        string memory _tokenURI = _tokenURIs[tokenId];
        
        return _tokenURI;
    }

    /**
     * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
     */
    function tokenOfOwnerByIndex(
        address owner, 
        uint256 index
    ) public view virtual override returns (uint256) 
    {
        require(index < balanceOf(owner), "ERC721Enumerable: owner index out of bounds");
        return ownedPilots[owner][index];
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(IERC165, ERC721) returns (bool) 
    {
        return interfaceId == type(IERC721Enumerable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721Enumerable-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return pilots.length;
    }

    /**
     * @dev See {IERC721Enumerable-tokenByIndex}.
     */
    function tokenByIndex(
        uint256 index
    ) public view virtual override returns (uint256) 
    {
        require(index < totalSupply(), "ERC721Enumerable: global index out of bounds");
        return pilots[index].id;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override virtual {
        super._beforeTokenTransfer(from, to, tokenId);

        if (from == address(0)) {
            _addTokenToAllTokensEnumeration(tokenId, to);
        } else if (from != to) {
            _removeTokenFromOwnerEnumeration(from, tokenId);
        }
        if (to == address(0)) {
            _removeTokenFromAllTokensEnumeration(tokenId);
        } else if (to != from) {
            _addTokenToOwnerEnumeration(to, tokenId);
        }
    }

    /**
     * @dev Private function to add a token to this extension's ownership-tracking data structures.
     * @param to address representing the new owner of the given token ID
     * @param tokenId uint256 ID of the token to be added to the tokens list of the given address
     */
    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        uint256 length = balanceOf(to);
        ownedPilots[to].push(tokenId);
        ownedPilotsIndex[to][tokenId] = length;
    }

    /**
     * @dev Private function to add a token to this extension's token tracking data structures.
     * @param tokenId uint256 ID of the token to be added to the tokens list
     */
    function _addTokenToAllTokensEnumeration(uint256 tokenId, address to) private {
        allPilotsIndex[tokenId] = pilots.length;

        pilots.push(Pilot("", to, 0, 1, tokenId, 0, 0));

    }

    /**
     * @dev Private function to remove a token from this extension's ownership-tracking data structures. Note that
     * while the token is not assigned a new owner, the `_ownedTokensIndex` mapping is _not_ updated: this allows for
     * gas optimizations e.g. when performing a transfer operation (avoiding double writes).
     * This has O(1) time complexity, but alters the order of the _ownedTokens array.
     * @param from address representing the previous owner of the given token ID
     * @param tokenId uint256 ID of the token to be removed from the tokens list of the given address
     */
    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId) private {
        uint256 lastTokenIndex = ownedPilots[from].length - 1;
        uint256 tokenIndex = ownedPilotsIndex[from][tokenId];

        uint256 lastPilot = ownedPilots[from][lastTokenIndex];
        ownedPilots[from][tokenIndex] = lastPilot;
        ownedPilotsIndex[from][lastPilot] = tokenIndex;
        delete ownedPilotsIndex[from][tokenId];
        ownedPilots[from].pop();
    }

    /**
     * @dev Private function to remove a token from this extension's token tracking data structures.
     * This has O(1) time complexity, but alters the order of the _allTokens array.
     * @param tokenId uint256 ID of the token to be removed from the tokens list
     */
    function _removeTokenFromAllTokensEnumeration(uint256 tokenId) private {
        uint256 lastTokenIndex = pilots.length - 1;
        uint256 tokenIndex = allPilotsIndex[tokenId];

        Pilot storage lastPilot = pilots[lastTokenIndex];
        pilots[tokenIndex] = lastPilot;
        allPilotsIndex[lastPilot.id] = tokenIndex;

        delete allPilotsIndex[tokenId];
        pilots.pop();
    }
}
