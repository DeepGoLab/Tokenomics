// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "../utils/AccessControl.sol";
import "../utils/Sig.sol";

contract VoyagerStorage is ERC721, IERC721Enumerable, AccessControl {
    using SafeMath for uint;

    event SetTokenURI(uint tokenId, string tokenURI);
    event SetBaseMintFee(uint256 baseMintFee);
    event SetLevelUpFee(uint256 levelUpFee);


    struct Voyager {
        uint256 id;
        uint256 level;
        uint256 pilotId; // 所在工会id
        address owner;
    }

    uint256 public tokenDecimal = 10 ** 18;
    uint256 public _totalMinted;
    uint256 public baseMintFee = 10 * tokenDecimal; // dgt费用
    uint256 public levelUpFee = 10 * tokenDecimal;
    string public _token0URI;
    
    Voyager[] public voyagers;
    mapping(address => uint[]) public ownedVoyagers;
    mapping(address => mapping( uint256 => uint256 )) public ownedVoyagersIndex;
    mapping(uint256 => uint256) public allVoyagersIndex;
    mapping(uint256 => string) public _tokenURIs;
    mapping(address => uint256) public _tokenIDWithoutURI;
    mapping(address => uint256) public _mintTokenIDWithoutURI;

    
    // 圈子成员数量
    mapping(uint256 => uint256) public voyagerCountOfPilot;
    // Pilot Id -> Voyager Address -> Voyager Id
    mapping(uint256 => mapping(address => uint256)) public voyagerOfAddressOfPilot;

    constructor() ERC721("Voyager", "VOG") {}

    function token0URI(
        string memory _string
    ) public onlyProxy 
    {
        _token0URI = _string;
    }

    function setVoyagerOfAddressOfPilot(
        uint256 pilotTokenId_,
        address addr_,
        uint256 voyagerId_
        ) external onlyProxy {
        voyagerOfAddressOfPilot[pilotTokenId_][addr_] = voyagerId_;
    }
    
    function setTokenURI(uint256 _tokenId, string memory _tokenURI) external onlyProxy {
        require(_exists(_tokenId), "ERC721Metadata: URI set of nonexistent token");
        _tokenURIs[_tokenId] = _tokenURI;
        emit SetTokenURI(_tokenId, _tokenURI);
    }

    function setBaseMintFee(uint256 baseMintFee_) external onlyOwner {
        baseMintFee = baseMintFee_;
        emit SetBaseMintFee(baseMintFee_);
    }

    function setLevelUpFee(uint256 levelUpFee_) external onlyOwner {
        baseMintFee = levelUpFee_;
        emit SetLevelUpFee(levelUpFee_);
    }

    function mintVoyager(
        address _addr, 
        uint256 _tokenId
    ) external onlyProxy
    {
        _safeMint(_addr, _tokenId);
    }

    function setTotalMinted(
        uint256 _amount
    ) public onlyProxy 
    {
        _totalMinted = _amount;
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
    }

    function setVoyagerCountOfPilot(uint256 tokenId_, uint256 count_) external onlyProxy {
        voyagerCountOfPilot[tokenId_] = count_;
    }

    function getTotalMinted() public view returns (uint256) {
        return _totalMinted;
    }

    function getVoyagerOfAddressOfPilot(
        uint tokenId_, 
        address voyager_
    ) public view returns (uint256) {
        return voyagerOfAddressOfPilot[tokenId_][voyager_];
    }

    function getVoyager(
        uint256 _index
    ) public view returns (Voyager memory)
    {
        return voyagers[_index];
    }

    function getVoyagerByTokenId(
        uint256 tokenId_
    ) public view returns (Voyager memory)
    {
        return voyagers[allVoyagersIndex[tokenId_]];
    }

    function getLevel(uint256 tokenId_) external view returns (uint256) {
        return voyagers[allVoyagersIndex[tokenId_]].level;
    }

    function setPilotId(uint256 tokenId_, uint256 pilotId_) external onlyProxy {
        voyagers[allVoyagersIndex[tokenId_]].pilotId = pilotId_;
    }

    function getPilotId(uint256 tokenId_) external view returns(uint256) {
        return voyagers[allVoyagersIndex[tokenId_]].pilotId;
    }

    function burn(uint256 pilotId_, address addr_) external onlyProxy {
        uint256 voyagerTokenId = voyagerOfAddressOfPilot[pilotId_][addr_];
        require(voyagerTokenId > 0, "No Voyager Toke To Burn"); 
        _burn(voyagerTokenId);
        // 清空相关状态
        voyagerCountOfPilot[pilotId_] -= 1;
        voyagerOfAddressOfPilot[pilotId_][addr_] = 0;
    }

    // 到期时间、开通时间、上一次结算时间(锁定)、上一次转给会长时间(结算+1月)、账户余额(treasury)
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
        ownedVoyagers[to].push(tokenId);
        ownedVoyagersIndex[to][tokenId] = length;
    }   

    /**
     * @dev Private function to add a token to this extension's token tracking data structures.
     * @param tokenId uint256 ID of the token to be added to the tokens list
     */
    function _addTokenToAllTokensEnumeration(uint256 tokenId, address to) private {
        allVoyagersIndex[tokenId] = voyagers.length;
        voyagers.push(Voyager(tokenId, 
                              1, 
                              0, // todo: to set pilotId
                              to));
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

        uint256 lastPilot = ownedVoyagers[from][lastTokenIndex];
        ownedVoyagers[from][tokenIndex] = lastPilot;
        ownedVoyagersIndex[from][lastPilot] = tokenIndex;
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

        Voyager storage lastPilot = voyagers[lastTokenIndex];
        voyagers[tokenIndex] = lastPilot;
        allVoyagersIndex[lastPilot.id] = tokenIndex;

        delete allVoyagersIndex[tokenId];
        voyagers.pop();
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
        return ownedVoyagers[owner][index];
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
        return voyagers.length;
    }

    /**
     * @dev See {IERC721Enumerable-tokenByIndex}.
     */
    function tokenByIndex(
        uint256 index
    ) public view virtual override returns (uint256) 
    {
        require(index < totalSupply(), "ERC721Enumerable: global index out of bounds");
        return voyagers[index].id;
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
}
