// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "../utils/AccessControl.sol";
import "./BaseStorage.sol";
import "../utils/Sig.sol";

contract VoyagerStorage is ERC721, IERC721Enumerable, BaseStorage, AccessControl {
    using SafeMath for uint;

    event SetSetByOwner(uint tokenId, uint level, bool isSet);
    event SetTokenIDWithoutURI(address addr, uint tokenId);
    event SetTotalMinted(uint amount);
    event SetWhitelistExpired(uint amount);
    event Token0URI(string _string);
    event SetExpiredWhitelist(address addr, bool isExpired);
    event SetMaxLevelOfOwner(address addr, uint level);
    event SetTokenLevelCount(address addr, uint level, uint amount);
    event SetLevelUpFee(uint toLevel, uint dgt, uint dsp);
    event SetCoolDown(uint toLevel, uint interval);
    event SetLevelStartHoldingTime(uint tokenId, uint curTimeStamp);
    event SetLevel(uint tokenId, uint level);
    event SetTokenURI(uint tokenId, string tokenURI); 
    event SetFee1TokenAddress(address token1);
    event SetFee2TokenAddress(address token2);
    event SetWhitelistLevel(address addr, uint level);

    Voyager[] public voyagers;

    mapping(address => uint[]) public ownedVoyagers;
    mapping(address => mapping( uint256 => uint256 )) public ownedVoyagersIndex;
    mapping(uint256 => uint256) public allVoyagersIndex;
    mapping(address => uint256) public maxLevelOfOwner;
    mapping(address => mapping(uint256 => uint256)) public tokenLevelCount;
    mapping(uint256 => string) private _tokenURIs;
    mapping(uint256 => mapping(uint256 => bool)) public setByOwner;
    mapping(address => uint256) private _tokenIDWithoutURI;
    mapping(address => uint256) private _mintTokenIDWithoutURI;
    mapping(address => bool) private _expiredWhitelist;
    mapping(address => uint) public whitelistLevelOf;

    uint256 private _maxWhitelisted = 1000;
    uint256 private _totalMinted;
    uint256 private _whitelistExpired;
    string private _token0URI;

    constructor(
        uint256 _maxLevel
    ) ERC721("Voyager", "VOG")  
    {
        require(_maxLevel <= levelUpDGT.length && _maxLevel <= levelUpDSP.length, "_maxLevel is too large.");
        maxLevel = _maxLevel;
        initialLevelUpFees();
    }
    
    function getOwnedVoyagers(
        address _addr
    ) public view returns (uint[] memory) 
    {
        return ownedVoyagers[_addr];
    }

    function getValidMaxLevel(
        address owner, 
        uint256 continueDays
    ) public view returns (uint256) 
    {
        uint256 balance = ERC721.balanceOf(owner); 
        uint256 maxLevel;
        Voyager memory voyager;
        for (uint256 i=0; i<balance; i++) {
            uint256 tokenId = ownedVoyagers[owner][i];
            voyager = getVoyagerByTokenId(tokenId);
            if (voyager.minter == ownerOf(tokenId) && voyager.level > maxLevel) {
                maxLevel = voyager.level;
            } else if (block.timestamp - voyager.startHoldingTime > (1 days) * continueDays
                && voyager.level > maxLevel) {
                maxLevel = voyager.level;
            }
        }
        return maxLevel;
    }
    
    function getVoyager(
        uint256 _index
    ) public view returns (Voyager memory)
    {
        return voyagers[_index];
    }

    function getVoyagerByTokenId(
        uint256 _tokenId
    ) public view returns (Voyager memory)
    {
        return voyagers[getAllVoyagerIndex(_tokenId)];
    }
    
    function getSetByOwner(
        uint256 _tokenId, 
        uint256 _level
    ) public view returns (bool) 
    {
        return setByOwner[_tokenId][_level];
    }

    function setSetByOwner(
        uint256 _tokenId, 
        uint256 _level, 
        bool _isSet
    ) public onlyProxy
    {
        setByOwner[_tokenId][_level] = _isSet;

        emit SetSetByOwner(_tokenId, _level, _isSet);
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
    ) public onlyProxy 
    {
        _mintTokenIDWithoutURI[_addr] = _tokenId;
    }

    function setTokenIDWithoutURI(
        address _addr, 
        uint256 _tokenId
    ) public onlyProxy 
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
    ) public onlyProxy 
    {
        _totalMinted = _amount;

        emit SetTotalMinted(_amount);
    }

    function getWhitelistExpired() public view returns (uint256){
        return _whitelistExpired;
    }

    function setWhitelistExpired(
        uint256 _amount
    ) public onlyProxy 
    {
        _whitelistExpired = _amount;

        emit SetWhitelistExpired(_amount);
    }

    function getToken0URI() public view returns (string memory) {
        return _token0URI;
    }

    function token0URI(
        string memory _string
    ) public onlyProxy 
    {
        _token0URI = _string;

        emit Token0URI(_string);
    }

    function getExpiredWhitelist(
        address _addr
    ) public view returns (bool) 
    {
        return _expiredWhitelist[_addr];
    }

    function setExpiredWhitelist(
        address _addr, 
        bool _isExpired
    ) public onlyProxy 
    {
        _expiredWhitelist[_addr] = _isExpired;

        emit SetExpiredWhitelist(_addr, _isExpired);
    }

    function getAllVoyagerIndex(
        uint256 _tokenId
    ) public view returns (uint256) 
    {
        return allVoyagersIndex[_tokenId];
    }

    function getMaxLevelOfOwner(
        address _addr
    ) public view returns (uint256) 
    {
        return maxLevelOfOwner[_addr];
    }

    function setMaxLevelOfOwner(
        address _addr, 
        uint256 _level
    ) public onlyProxy 
    {
        maxLevelOfOwner[_addr] = _level;

        emit SetMaxLevelOfOwner(_addr, _level);
    }

    function getTokenLevelCount(
        address _addr, 
        uint256 _level
    ) public view returns (uint256) 
    {
        return tokenLevelCount[_addr][_level];
    }

    function setTokenLevelCount(
        address _addr, 
        uint256 _level, 
        uint256 _amount
    ) public onlyProxy 
    {
        tokenLevelCount[_addr][_level] = _amount;

        emit SetTokenLevelCount(_addr, _level, _amount);
    }

    function getWhitelistLevel(address addr) external view returns(uint) {
        return whitelistLevelOf[addr];
    }

    function setWhitelistLevel(address addr, uint level) external onlyProxy {
        whitelistLevelOf[addr] = level;

        emit SetWhitelistLevel(addr, level);
    }

    function mintVoyager(
        address _addr, 
        uint256 _tokenId
    ) external onlyProxy 
    {
        _safeMint(_addr, _tokenId);
    }

    function transferVoyager(
        address _to, 
        uint256 _tokenId
    ) external 
    {
        require(getTokenIDWithoutURI(msg.sender) == 0  &&
                getMintTokenIDWithoutURI(msg.sender) == 0, 
                "Set tokenURI first");
        _safeTransfer(msg.sender, _to, _tokenId, "");
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
     * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
     */
    function tokenOfOwnerByIndex(
        address owner, 
        uint256 index
    ) public view virtual override returns (uint256) 
    {
        require(index < ERC721.balanceOf(owner), "ERC721Enumerable: owner index out of bounds");
        return ownedVoyagers[owner][index];
    }

    /**
     * @dev See {IERC721Enumerable-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return voyagers.length;
    }

    /**
     * @dev See {IERC721Enumerable-tokenByIndex}.
     */
    function tokenByIndex(
        uint256 index
    ) public view virtual override returns (uint256) 
    {
        require(index < VoyagerStorage.totalSupply(), "ERC721Enumerable: global index out of bounds");
        return voyagers[index].id;
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
            _updateSenderMaxLevel(from, tokenId);
        }
        if (to == address(0)) {
            _removeTokenFromAllTokensEnumeration(tokenId);
        } else if (to != from) {
            _addTokenToOwnerEnumeration(to, tokenId);
            _updateReceiverMaxLevel(to, tokenId);
            voyagers[allVoyagersIndex[tokenId]].startHoldingTime = block.timestamp;
            voyagers[allVoyagersIndex[tokenId]].levelStartHoldingTime = block.timestamp;
            tokenLevelCount[to][voyagers[allVoyagersIndex[tokenId]].level] += 1;
        }
    }

    function _updateSenderMaxLevel(
        address from, 
        uint256 tokenId
    ) private 
    {
        uint256 curLevel = voyagers[allVoyagersIndex[tokenId]].level;
        require(curLevel <= maxLevelOfOwner[from], "Level over max");

        tokenLevelCount[from][curLevel] -= 1;

        if (ERC721.balanceOf(from) == 0) {
            maxLevelOfOwner[from] = 0;
        } else if ( curLevel == maxLevelOfOwner[from] ) {
            for (; curLevel > 0; curLevel--) {
                if (tokenLevelCount[from][curLevel] > 0) {
                    maxLevelOfOwner[from] = curLevel;
                    break;
                }
            }
        }
    }

    function _updateReceiverMaxLevel(
        address to, 
        uint256 tokenId
    ) private 
    {
        uint256 curLevel = voyagers[allVoyagersIndex[tokenId]].level;
        if (curLevel > maxLevelOfOwner[to]) {
            maxLevelOfOwner[to] = curLevel;
        }
    }

    /**
     * @dev Private function to add a token to this extension's ownership-tracking data structures.
     * @param to address representing the new owner of the given token ID
     * @param tokenId uint256 ID of the token to be added to the tokens list of the given address
     */
    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        uint256 length = ERC721.balanceOf(to);
        ownedVoyagers[to].push(tokenId);
        ownedVoyagersIndex[to][tokenId] = length;
    }

    /**
     * @dev Private function to add a token to this extension's token tracking data structures.
     * @param tokenId uint256 ID of the token to be added to the tokens list
     */
    function _addTokenToAllTokensEnumeration(uint256 tokenId, address to) private {
        allVoyagersIndex[tokenId] = voyagers.length;
        if (tokenId == 0) {
            voyagers.push(Voyager(uint8(maxLevel), tokenId, to, block.timestamp, block.timestamp));
        } else {
            voyagers.push(Voyager(uint8(minLevel), tokenId, to, block.timestamp, block.timestamp));
        }
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
        uint256 lastTokenIndex = ownedVoyagers[from].length - 1;
        uint256 tokenIndex = ownedVoyagersIndex[from][tokenId];

        uint256 lastVoyager = ownedVoyagers[from][lastTokenIndex];
        ownedVoyagers[from][tokenIndex] = lastVoyager;
        ownedVoyagersIndex[from][lastVoyager] = tokenIndex;
        delete ownedVoyagersIndex[from][tokenId];
        ownedVoyagers[from].pop();
    }

    /**
     * @dev Private function to remove a token from this extension's token tracking data structures.
     * This has O(1) time complexity, but alters the order of the _allTokens array.
     * @param tokenId uint256 ID of the token to be removed from the tokens list
     */
    function _removeTokenFromAllTokensEnumeration(uint256 tokenId) private {
        uint256 lastTokenIndex = voyagers.length - 1;
        uint256 tokenIndex = allVoyagersIndex[tokenId];

        Voyager storage lastVoyager = voyagers[lastTokenIndex];
        voyagers[tokenIndex] = lastVoyager;
        allVoyagersIndex[lastVoyager.id] = tokenIndex;

        delete allVoyagersIndex[tokenId];
        voyagers.pop();
    }

    function setLevelUpFee(uint256 _toLevel, uint256 _dgt, uint256 _dsp) external onlyOwner {
        require(_toLevel <= maxLevel, "Over max level");
        require(levelUpFees.length >= _toLevel-1, "Add fee from low level");
        if (levelUpFees.length == _toLevel-1) {
            levelUpFees.push(FeeComponent(_dgt, _dsp));
        } else {
            levelUpFees[_toLevel-1] = FeeComponent(_dgt, _dsp);
        }

        emit SetLevelUpFee(_toLevel, _dgt, _dsp);
    }

    function setCoolDown(uint256 _toLevel, uint32 _interval) external onlyOwner {
        require (_toLevel > 1 && _toLevel <= cooldowns.length.add(1), "Over max level"); 
        cooldowns[_toLevel-2] = _interval;

        emit SetCoolDown(_toLevel, _interval);
    }

    function initialLevelUpFees() internal {
        for (uint256 i=0; i < maxLevel; i++) {
            levelUpFees.push(FeeComponent(levelUpDGT[i] * decimals, levelUpDSP[i] * decimals));
        }
    }

    function getLevelUpDSP(uint256 level, uint256 holdingDays) public view returns (uint256 cost) {
        if (level == 0) {
            cost = levelUpDSPParam1[0];
        } else {
            if (holdingDays < 153) {
                cost = levelUpDSPParam1[level].sub(2 * holdingDays);
            } else {
                cost = levelUpDSPParam2[level];
            }
        }

        cost = cost.mul(decimals);
    }

    function getLevelUpFee(uint256 level) public view returns (uint, uint256) {
        return (levelUpFees[level].dgt, levelUpFees[level].dsp);
    }

    function getMintFee() public view returns (uint, uint256) {
        return (levelUpDGT[0] * decimals, getLevelUpDSP(0, 1));
    }

    function getLevelUpFeeV2(uint256 tokenId) public view returns (uint, uint256) {
        uint256 level = getLevel(tokenId);
        uint256 holdingDays = getCurLevelHoldingDays(tokenId);
        return (levelUpDGT[level] * decimals, getLevelUpDSP(level, holdingDays));
    }

    function getLevel(uint256 tokenId) public view returns (uint256){
        return voyagers[allVoyagersIndex[tokenId]].level;
    }

    function getHoldingDays(uint256 tokenId) public view returns (uint256){
        return block.timestamp.sub(voyagers[allVoyagersIndex[tokenId]].startHoldingTime)
                              .div(1 days);
    }

    function getCurLevelHoldingDays(uint256 tokenId) public view returns (uint256){
        return block.timestamp.sub(voyagers[allVoyagersIndex[tokenId]].levelStartHoldingTime)
                              .div(1 days);
    }

    function setLevelStartHoldingTime(uint256 tokenId, uint256 _curTimeStamp) public onlyProxy {
        voyagers[allVoyagersIndex[tokenId]].levelStartHoldingTime = _curTimeStamp;
    
        emit SetLevelStartHoldingTime(tokenId, _curTimeStamp);
    }

    function setLevel(uint256 tokenId, uint256 level) public onlyProxy {
        voyagers[allVoyagersIndex[tokenId]].level = uint8(level);

        emit SetLevel(tokenId, level);
    }

    function _setTokenURI(uint256 _tokenId, string memory _tokenURI) public virtual onlyProxy {
        require(_exists(_tokenId), "ERC721Metadata: URI set of nonexistent token");
        _tokenURIs[_tokenId] = _tokenURI;
        
        emit SetTokenURI(_tokenId, _tokenURI);   
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        string memory _tokenURI = _tokenURIs[tokenId];
        
        return _tokenURI;
    }

    function setFee1TokenAddress(address _token1) public onlyProxy {
        dgtAddress = _token1;

        emit SetFee1TokenAddress(_token1);
    }

    function setFee2TokenAddress(address _token2) public onlyProxy {
        dspAddress = _token2;

        emit SetFee2TokenAddress(_token2);
    }
}
