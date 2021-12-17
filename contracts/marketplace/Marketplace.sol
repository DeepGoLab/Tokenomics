// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./HasQuoteTokens.sol";
import "hardhat/console.sol";

contract Marketplace is ReentrancyGuard, HasQuoteTokens{
  using Counters for Counters.Counter;
  using SafeERC20 for IERC20;

  Counters.Counter private _itemIds;
  Counters.Counter private _itemsSold;
  Counters.Counter private _itemsCanceled;

  struct MarketItem {
    uint itemId;
    address nftContract;
    uint256 tokenId;
    address seller;
    address owner;
    uint256 price;
    address quoteTokenContract;
    bool sold;
  }

  mapping(uint256 => MarketItem) private idToMarketItem;

  event MarketItemCreated (
    uint indexed itemId,
    address indexed nftContract,
    uint256 indexed tokenId,
    address seller,
    address owner,
    uint256 price,
    address quoteTokenContract,
    bool sold
  );

  event CreateMarketSale (
    address indexed nftContract,
    address indexed buyer,
    uint256 indexed itemId
  );

  event CancelMarketSale(
    address indexed nftContract,
    address indexed owner,
    uint256 indexed itemId
  );

  function createMarketItemByBNB(
    address nftContract,
    uint256 tokenId,
    uint256 price
  ) public nonReentrant
  {
    require(price > 0, "Price must be at least 1 wei");

    _itemIds.increment();
    uint256 itemId = _itemIds.current();
  
    idToMarketItem[itemId] =  MarketItem(
      itemId,
      nftContract,
      tokenId,
      msg.sender,
      address(0), 
      price,
      address(0),
      false
    );

    IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

    emit MarketItemCreated(
      itemId,
      nftContract,
      tokenId,
      msg.sender,
      address(0),
      price,
      address(0),
      false
    );
  }

  /* Places an item for sale on the marketplace */
  function createMarketItem(
    address nftContract,
    address quoteTokenContract,
    uint256 tokenId,
    uint256 price
  ) public onlyQuoteToken(quoteTokenContract) nonReentrant {
    require(price > 0, "Price must be at least 1 wei");

    _itemIds.increment();
    uint256 itemId = _itemIds.current();
  
    idToMarketItem[itemId] =  MarketItem(
      itemId,
      nftContract,
      tokenId,
      msg.sender,
      address(0),
      price,
      quoteTokenContract,
      false
    );

    IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

    emit MarketItemCreated(
      itemId,
      nftContract,
      tokenId,
      msg.sender,
      address(0),
      price,
      quoteTokenContract,
      false
    );
  }

  function getQuoteTokenAddress(uint256 itemId) public view returns (address) {
      return idToMarketItem[itemId].quoteTokenContract;
  }

  function getPrice(uint256 itemId) public view returns (uint) {
      return idToMarketItem[itemId].price;
  }

  /* Creates the sale of a marketplace item */
  function createMarketSale(
    uint256 itemId
  ) public payable nonReentrant {
    uint price = idToMarketItem[itemId].price;
    uint tokenId = idToMarketItem[itemId].tokenId;
    address quoteTokenContract = idToMarketItem[itemId].quoteTokenContract;
    address nftContract = idToMarketItem[itemId].nftContract;

    if (quoteTokenContract == address(0)) {
        require(msg.value == price, "Please submit the asking price in order to complete the purchase");
        payable(idToMarketItem[itemId].seller).transfer(msg.value);
    } else {
        IERC20(quoteTokenContract).safeTransferFrom(msg.sender, idToMarketItem[itemId].seller, price);
    }

    IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);
    idToMarketItem[itemId].owner = payable(msg.sender);
    idToMarketItem[itemId].sold = true;
    _itemsSold.increment();

    emit CreateMarketSale(
      nftContract,
      msg.sender,
      itemId
    );
  }

  /* Cancels the sale of a marketplace item */
  function cancelMarketSale(
    uint256 itemId
  ) public nonReentrant {
    require(idToMarketItem[itemId].seller == msg.sender &&
            idToMarketItem[itemId].owner == address(0), "Invalid seller");
    uint tokenId = idToMarketItem[itemId].tokenId;
    address nftContract = idToMarketItem[itemId].nftContract;
    IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);
    idToMarketItem[itemId].seller = address(0);
    idToMarketItem[itemId].owner = msg.sender;
    _itemsCanceled.increment();
    
    emit CancelMarketSale(
      nftContract,
      msg.sender,
      itemId
    );
  }

  /* Returns all unsold & uncancelled market items */
  function fetchUnsoldItems() public view returns (MarketItem[] memory) {
    uint itemCount = _itemIds.current();
    uint unsoldItemCount = _itemIds.current() - _itemsSold.current() - _itemsCanceled.current();
    uint currentIndex = 0;

    MarketItem[] memory items = new MarketItem[](unsoldItemCount);
    for (uint i = 0; i < itemCount; i++) {
      if (idToMarketItem[i + 1].owner == address(0) && 
          idToMarketItem[i + 1].seller != address(0)) {
        uint currentId = i + 1;
        MarketItem storage currentItem = idToMarketItem[currentId];
        items[currentIndex] = currentItem;
        currentIndex += 1;
      }
    }
    return items;
  }

  /* Returns all sold market items */
  function fetchSoldItems() public view returns (MarketItem[] memory) {
    uint itemCount = _itemIds.current();
    uint unsoldItemCount = _itemsSold.current();
    uint currentIndex = 0;

    MarketItem[] memory items = new MarketItem[](unsoldItemCount);
    for (uint i = 0; i < itemCount; i++) {
      if (idToMarketItem[i + 1].sold == true) {
        uint currentId = i + 1;
        MarketItem storage currentItem = idToMarketItem[currentId];
        items[currentIndex] = currentItem;
        currentIndex += 1;
      }
    }
    return items;
  }

  /* Returns only items that a user's unsold */
  function fetchOnesUnsold(address _owner) public view returns (MarketItem[] memory) {
    uint totalItemCount = _itemIds.current();
    uint itemCount = 0;
    uint currentIndex = 0;

    for (uint i = 0; i < totalItemCount; i++) {
      if (idToMarketItem[i + 1].seller == _owner &&
          idToMarketItem[i + 1].owner == address(0)) {
        itemCount += 1;
      }
    }

    MarketItem[] memory items = new MarketItem[](itemCount);
    for (uint i = 0; i < totalItemCount; i++) {
      if (
        idToMarketItem[i + 1].seller == _owner &&
        idToMarketItem[i + 1].owner == address(0)
      ) 
      {
        uint currentId = i + 1;
        MarketItem storage currentItem = idToMarketItem[currentId];
        items[currentIndex] = currentItem;
        currentIndex += 1;
      }
    }
    return items;
  }

 /* Returns only items that a user's sold */
  function fetchOnesSold(address _owner) public view returns (MarketItem[] memory) {
    uint totalItemCount = _itemIds.current();
    uint itemCount = 0;
    uint currentIndex = 0;

    for (uint i = 0; i < totalItemCount; i++) {
      if (idToMarketItem[i + 1].seller == _owner &&
        idToMarketItem[i + 1].owner != address(0)) {
        itemCount += 1;
      }
    }

    MarketItem[] memory items = new MarketItem[](itemCount);
    for (uint i = 0; i < totalItemCount; i++) {
      if (
        idToMarketItem[i + 1].seller == _owner &&
        idToMarketItem[i + 1].owner != address(0)
      ) 
      {
        uint currentId = i + 1;
        MarketItem storage currentItem = idToMarketItem[currentId];
        items[currentIndex] = currentItem;
        currentIndex += 1;
      }
    }
    return items;
  }

  /* Returns only items that a user has purchased */
  function fetchTradeHistory(address _owner) public view returns (MarketItem[] memory) {
    uint totalItemCount = _itemIds.current();
    uint itemCount = 0;
    uint currentIndex = 0;

    for (uint i = 0; i < totalItemCount; i++) {
      if (idToMarketItem[i + 1].seller != address(0) &&
          idToMarketItem[i + 1].owner == _owner) {
        itemCount += 1;
      }
    }

    MarketItem[] memory items = new MarketItem[](itemCount);
    for (uint i = 0; i < totalItemCount; i++) {
      if (idToMarketItem[i + 1].seller != address(0) &&
          idToMarketItem[i + 1].owner == _owner) {
        uint currentId = i + 1;
        MarketItem storage currentItem = idToMarketItem[currentId];
        items[currentIndex] = currentItem;
        currentIndex += 1;
      }
    }
    return items;
  }

  /* Returns only items a user has cancel */
  function fetchItemsCancel() public view returns (MarketItem[] memory) {
    uint totalItemCount = _itemIds.current();
    uint itemCount = 0;
    uint currentIndex = 0;

    for (uint i = 0; i < totalItemCount; i++) {
      if (idToMarketItem[i + 1].seller == address(0) &&
          idToMarketItem[i + 1].owner == msg.sender) {
        itemCount += 1;
      }
    }

    MarketItem[] memory items = new MarketItem[](itemCount);
    for (uint i = 0; i < totalItemCount; i++) {
      if (idToMarketItem[i + 1].seller == address(0) &&
          idToMarketItem[i + 1].owner == msg.sender) {
        uint currentId = i + 1;
        MarketItem storage currentItem = idToMarketItem[currentId];
        items[currentIndex] = currentItem;
        currentIndex += 1;
      }
    }
    return items;
  }

  function getMarketItem(uint itemId) public view returns (MarketItem memory){
    return idToMarketItem[itemId];
  } 

  function withdrawNFT(address nftContract, address to_, uint tokenId_) public onlyOwner {
    IERC721(nftContract).transferFrom(address(this), to_, tokenId_);
  }
}
